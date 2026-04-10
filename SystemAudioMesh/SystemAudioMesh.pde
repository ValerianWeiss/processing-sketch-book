import javax.sound.sampled.*;
import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;
import ddf.minim.analysis.FFT;
import processing.event.MouseEvent;

/*
 * SystemAudioMesh10s.pde
 *
 * Java-mode Processing sketch that visualizes a rolling 10-second window
 * of audio as a square wireframe mesh.
 *
 * Notes:
 * - "System audio" capture depends on the OS audio routing setup.
 * - On macOS, route output through a loopback device (for example BlackHole)
 *   and make that the active recording source for this sketch.
 */

// Canvas
final int CANVAS_W = 1920;
final int CANVAS_H = 1080;

// Mesh settings (square mesh)
final int GRID = 256;                     // GRID x GRID vertices (reduced for performance)
final float WINDOW_SECONDS = 10.0;
final float MESH_SIZE = 1600;            // larger world-space square (same vertex count)
final float HEIGHT_SCALE = 320;          // vertical displacement scale

// Audio capture settings
final float TARGET_SAMPLE_RATE = 48000f;
final int AUDIO_READ_FRAMES = 2048;
final int FFT_SIZE = 1024;
final float FFT_GAIN = 10.0f;
final float MIN_NORM = 0.02f;            // floor for adaptive normalization
final float MUSIC_MIN_HZ = 30.0f;
final float MUSIC_MAX_HZ = 16000.0f;
final float PROFILE_SMOOTH = 0.28f;

// Circular mesh history: columns are time, rows are profile samples
float[][] meshValues = new float[GRID][GRID];
int writeColumn = 0;

// Rotation state
float rotX = radians(58);
float rotY = 0;
float cameraDistance = 1820;
float cameraFov = PI / 2.95;

// Audio runtime state
TargetDataLine inputLine;
Thread audioThread;
volatile boolean running = false;
final Object audioLock = new Object();
float[] latestChunk = new float[0];
float[] fftInput = new float[FFT_SIZE];
float[] smoothedProfile = new float[GRID];
float[] bandAutoNorm = new float[GRID];
FFT spectrum;

long lastColumnWriteMs = 0;
float adaptiveNorm = 0.3f;

void settings() {
  size(CANVAS_W, CANVAS_H, P3D);
  smooth(8);
}

void setup() {
  frameRate(60);

  clearMesh();
  setupAudioCapture();

  spectrum = new FFT(FFT_SIZE, TARGET_SAMPLE_RATE);
  lastColumnWriteMs = millis();
}

void draw() {
  background(8, 11, 16);
  advanceMeshFromAudio();

  perspective(cameraFov, width / float(height), 1, 9000);
  camera(width * 0.5, height * 0.5, cameraDistance,
    width * 0.5, height * 0.5, 0,
    0, 1, 0);

  pushMatrix();
  translate(width * 0.5, height * 0.51, 0);
  rotateX(rotX);
  rotateY(rotY);
  scale(viewFitScale());

  // Frequency spans one edge of the square; newest time slice is the front edge.
  translate(-MESH_SIZE * 0.5, 0, -MESH_SIZE * 0.5);

  drawSquareWireMesh();
  popMatrix();

  drawHud();
}

void drawSquareWireMesh() {
  strokeWeight(1.25);
  noFill();

  // Draw rows by frequency; time advances from back (old) to front (new).
  for (int r = 0; r < GRID; r++) {
    beginShape();
    for (int c = 0; c < GRID; c++) {
      int col = historyColumnToIndex(c);
      float x = map(r, 0, GRID - 1, 0, MESH_SIZE);
      float z = map(c, 0, GRID - 1, 0, MESH_SIZE);
      float y = -meshValues[col][r] * HEIGHT_SCALE;

      float hueT = meshValues[col][r];
      stroke(lerpColor(color(40, 170, 255, 145), color(255, 135, 60, 210), hueT));
      vertex(x, y, z);
    }
    endShape();
  }

  // Draw columns by time to complete the wire mesh.
  for (int c = 0; c < GRID; c++) {
    int col = historyColumnToIndex(c);
    beginShape();
    for (int r = 0; r < GRID; r++) {
      float x = map(r, 0, GRID - 1, 0, MESH_SIZE);
      float z = map(c, 0, GRID - 1, 0, MESH_SIZE);
      float y = -meshValues[col][r] * HEIGHT_SCALE;
      stroke(30, 145, 230, 82);
      vertex(x, y, z);
    }
    endShape();
  }
}

void drawHud() {
  fill(225, 235, 255, 210);
  textSize(14);
  textAlign(LEFT, TOP);
  text("System Audio Mesh (10s history)", 8, 6);
  text("Left-drag to rotate", 8, 24);
  text("Oldest at back, latest at front edge", 8, 42);
}

void advanceMeshFromAudio() {
  float msPerColumn = (WINDOW_SECONDS * 1000.0) / float(GRID);
  long now = millis();

  while (now - lastColumnWriteMs >= msPerColumn) {
    float[] profile = buildProfileFromLatestChunk();

    for (int r = 0; r < GRID; r++) {
      meshValues[writeColumn][r] = profile[r];
    }

    writeColumn = (writeColumn + 1) % GRID;
    lastColumnWriteMs += int(msPerColumn);
  }
}

float[] buildProfileFromLatestChunk() {
  float[] profile = new float[GRID];
  float[] chunkCopy;

  synchronized (audioLock) {
    chunkCopy = latestChunk;
  }

  if (chunkCopy == null || chunkCopy.length < 32 || spectrum == null) {
    return profile;
  }

  // Copy the latest samples into fixed FFT input (use most recent window).
  int sourceStart = max(0, chunkCopy.length - FFT_SIZE);
  int copyLen = min(chunkCopy.length, FFT_SIZE);
  int padLen = FFT_SIZE - copyLen;

  for (int i = 0; i < padLen; i++) {
    fftInput[i] = 0;
  }
  arrayCopy(chunkCopy, sourceStart, fftInput, padLen, copyLen);

  spectrum.forward(fftInput);

  float peak = 0;
  for (int i = 1; i < spectrum.specSize(); i++) {
    float v = spectrum.getBand(i);
    if (v > peak) peak = v;
  }

  // Smooth adaptive normalization tuned for musical dynamics.
  adaptiveNorm = lerp(adaptiveNorm, max(peak * 0.62, MIN_NORM), 0.16);

  int specMax = max(4, spectrum.specSize() - 1);
  float nyquist = TARGET_SAMPLE_RATE * 0.5;
  float minHz = max(20.0, MUSIC_MIN_HZ);
  float maxHz = min(MUSIC_MAX_HZ, nyquist - 20.0);
  float binHz = TARGET_SAMPLE_RATE / float(FFT_SIZE);

  // Map logarithmic music bands along one edge (frequency axis).
  for (int r = 0; r < GRID; r++) {
    float t0 = r / float(GRID - 1);
    float t1 = min(1.0, (r + 1) / float(GRID - 1));

    float f0 = minHz * pow(maxHz / minHz, t0);
    float f1 = minHz * pow(maxHz / minHz, t1);

    int startBand = constrain(int(f0 / binHz), 1, specMax - 1);
    int endBand = constrain(int(ceil(f1 / binHz)), startBand + 1, specMax);
    if (endBand <= startBand) endBand = min(startBand + 1, specMax);

    float sum = 0;
    int count = 0;
    float peakBand = 0;
    for (int b = startBand; b < endBand; b++) {
      float hz = b * binHz;
      float weight = musicWeightForHz(hz);
      float energy = spectrum.getBand(b) * weight;
      sum += energy;
      count++;
      if (energy > peakBand) peakBand = energy;
    }

    float meanEnergy = (count > 0) ? (sum / count) : 0;
    float bandEnergy = meanEnergy * 0.75 + peakBand * 0.25;

    // Per-frequency adaptive norm prevents persistent "always max" bands.
    bandAutoNorm[r] = lerp(bandAutoNorm[r], max(bandEnergy, MIN_NORM), 0.06);
    float localNorm = max(adaptiveNorm * 0.38, bandAutoNorm[r] * 1.20);
    float raw = (bandEnergy * FFT_GAIN) / max(localNorm, MIN_NORM);

    // Soft compression keeps values in range without hard clipping artifacts.
    float compressed = raw / (1.0 + raw);
    float normalized = constrain(compressed * 1.06, 0, 1);

    smoothedProfile[r] = lerp(smoothedProfile[r], normalized, PROFILE_SMOOTH);
    profile[r] = pow(smoothedProfile[r], 0.76);
  }

  return profile;
}

float musicWeightForHz(float hz) {
  if (hz < 55) return 0.70;
  if (hz < 110) return 1.30;
  if (hz < 240) return 1.25;
  if (hz < 2000) return 1.00;
  if (hz < 6000) return 0.88;
  return 0.78;
}

float viewFitScale() {
  float halfXY = (MESH_SIZE * 0.5) * 1.4143;  // square half-diagonal for any yaw angle
  float visualHalfH = max(MESH_SIZE * 0.75, HEIGHT_SCALE * 1.12);

  float fitW = (width * 0.495) / halfXY;
  float fitH = (height * 0.485) / visualHalfH;
  return min(fitW, fitH);
}

int historyColumnToIndex(int visualColumn) {
  // visualColumn=0 should be oldest, visualColumn=GRID-1 should be newest.
  return (writeColumn + visualColumn) % GRID;
}

void clearMesh() {
  for (int c = 0; c < GRID; c++) {
    for (int r = 0; r < GRID; r++) {
      meshValues[c][r] = 0;
    }
    smoothedProfile[c] = 0;
    bandAutoNorm[c] = MIN_NORM;
  }
}

void mouseDragged() {
  if (mouseButton == LEFT) {
    rotY += (mouseX - pmouseX) * 0.01;
    rotX += (mouseY - pmouseY) * 0.01;

    // Free orbital rotation without hard-stop clamps.
    float twoPi = TWO_PI;
    rotX = (rotX % twoPi + twoPi) % twoPi;
    rotY = (rotY % twoPi + twoPi) % twoPi;
  }
}

void mouseWheel(MouseEvent event) {
  float delta = event.getCount();

  // Scroll up gets closer, scroll down moves away.
  cameraDistance += delta * 70.0;
  cameraDistance = constrain(cameraDistance, 700, 3600);

  // Couple FOV lightly to distance for better perspective feel.
  float t = map(cameraDistance, 700, 3600, 0, 1);
  cameraFov = lerp(PI / 3.7, PI / 2.45, t);
}

void stop() {
  shutdownAudioCapture();
  super.stop();
}

void setupAudioCapture() {
  AudioFormat format = new AudioFormat(TARGET_SAMPLE_RATE, 16, 2, true, false);
  Mixer.Info[] infos = AudioSystem.getMixerInfo();

  println("[Audio] Available mixers:");
  for (int i = 0; i < infos.length; i++) {
    println("  [" + i + "] " + infos[i].getName() + " | " + infos[i].getDescription());
  }

  TargetDataLine chosenLine = tryOpenPreferredLoopbackMixer(infos, format);

  if (chosenLine == null) {
    try {
      TargetDataLine fallbackLine = AudioSystem.getTargetDataLine(format);
      int bufferBytes = AUDIO_READ_FRAMES * format.getFrameSize();
      openLineCompat(fallbackLine, format, bufferBytes);
      chosenLine = fallbackLine;
      println("[Audio] Using default input mixer");
    } catch (Exception e) {
      chosenLine = null;
      println("[Audio] Failed to open default input: " + e.getMessage());
    }
  }

  if (chosenLine == null) {
    println("[Audio] No input line could be opened. Mesh will stay flat.");
    return;
  }

  inputLine = chosenLine;
  try {
    inputLine.start();
  } catch (Exception e) {
    println("[Audio] Failed to start input line: " + e.getMessage());
    inputLine = null;
    return;
  }

  running = true;
  audioThread = new Thread(new Runnable() {
    public void run() {
      readAudioLoop();
    }
  }, "audio-capture-thread");
  audioThread.start();

  println("[Audio] Capture started: " + inputLine.getFormat());
}

TargetDataLine tryOpenPreferredLoopbackMixer(Mixer.Info[] infos, AudioFormat format) {
  String[] preferredNames = {
    "blackhole",
    "loopback",
    "stereo mix",
    "vb-audio",
    "monitor"
  };

  for (String key : preferredNames) {
    for (Mixer.Info info : infos) {
      String name = info.getName().toLowerCase();
      String desc = info.getDescription().toLowerCase();
      if (!name.contains(key) && !desc.contains(key)) {
        continue;
      }

      try {
        Mixer mixer = AudioSystem.getMixer(info);
        DataLine.Info lineInfo = new DataLine.Info(TargetDataLine.class, format);
        if (!mixer.isLineSupported(lineInfo)) {
          continue;
        }

        TargetDataLine line = (TargetDataLine) mixer.getLine(lineInfo);
        int bufferBytes = AUDIO_READ_FRAMES * format.getFrameSize();
        openLineCompat(line, format, bufferBytes);
        println("[Audio] Using loopback-like mixer: " + info.getName());
        return line;
      } catch (Exception ignored) {
      }
    }
  }

  return null;
}

void openLineCompat(TargetDataLine line, AudioFormat format, int bufferBytes) throws Exception {
  // Processing PDE currently has a parser issue with direct .open(...) calls.
  try {
    Method bufferedOpen = TargetDataLine.class.getMethod("open", AudioFormat.class, int.class);
    bufferedOpen.invoke(line, format, bufferBytes);
    return;
  } catch (InvocationTargetException ex) {
    Throwable cause = ex.getCause();
    if (!(cause instanceof IllegalArgumentException) && !(cause instanceof LineUnavailableException)) {
      throw ex;
    }
  }

  Method simpleOpen = TargetDataLine.class.getMethod("open", AudioFormat.class);
  simpleOpen.invoke(line, format);
}

void readAudioLoop() {
  if (inputLine == null) {
    return;
  }

  int frameSize = inputLine.getFormat().getFrameSize();
  byte[] byteBuffer = new byte[AUDIO_READ_FRAMES * frameSize];

  while (running) {
    int read = inputLine.read(byteBuffer, 0, byteBuffer.length);
    if (read <= 0) {
      continue;
    }

    float[] mono = bytesToMonoFloat(byteBuffer, read);
    synchronized (audioLock) {
      latestChunk = mono;
    }
  }
}

float[] bytesToMonoFloat(byte[] data, int byteCount) {
  int channels = max(1, inputLine.getFormat().getChannels());
  int frameSize = inputLine.getFormat().getFrameSize();
  int frames = byteCount / frameSize;

  float[] out = new float[frames];
  int idx = 0;

  for (int f = 0; f < frames; f++) {
    float sum = 0;
    for (int ch = 0; ch < channels; ch++) {
      int lo = data[idx++] & 0xff;
      int hi = data[idx++];
      short s = (short) ((hi << 8) | lo);
      sum += s / 32768.0f;
    }
    out[f] = sum / channels;
  }

  return out;
}

void shutdownAudioCapture() {
  running = false;

  if (audioThread != null) {
    try {
      audioThread.join(250);
    } catch (InterruptedException ignored) {
    }
  }

  if (inputLine != null) {
    try {
      inputLine.stop();
      inputLine.close();
    } catch (Exception ignored) {
    }
  }
}
