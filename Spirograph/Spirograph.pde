float R;                        // Outer radius
float r;                        // Inner rolling radius
float d;                        // Pen offset
final float tStep = 0.001;      // Resolution
float maxT;
final int pointsPerFrame = 240;

boolean useEpitrochoid;         // false -> hypotrochoid

// Optional nested rotations (amplitude, frequency, phase)
float[] termAmp = new float[2];
float[] termFreq = new float[2];
float[] termPhase = new float[2];

float t = 0.0;
PVector prevPoint;

void setup() {
  size(1024, 1024, P2D);
  randomizePattern();
  background(255);
  smooth(8);
  noFill();
  strokeWeight(0.85);
  strokeCap(ROUND);
  prevPoint = curvePointAt(0.0);
}

void draw() {
  translate(width * 0.5, height * 0.5);

  for (int i = 0; i < pointsPerFrame && t <= maxT; i++) {
    float nextT = t + tStep;
    PVector nextPoint = curvePointAt(nextT);

    stroke(0, 22);
    line(prevPoint.x, prevPoint.y, nextPoint.x, nextPoint.y);

    prevPoint = nextPoint;
    t = nextT;
  }

  if (t > maxT) {
    noLoop();
  }
}

PVector curvePointAt(float tt) {
  float x;
  float y;

  if (useEpitrochoid) {
    float sumR = R + r;
    float ratio = sumR / r;
    x = sumR * cos(tt) - d * cos(ratio * tt);
    y = sumR * sin(tt) - d * sin(ratio * tt);
  } else {
    float diffR = R - r;
    float ratio = diffR / r;
    x = diffR * cos(tt) + d * cos(ratio * tt);
    y = diffR * sin(tt) - d * sin(ratio * tt);
  }

  // Optional extra harmonics for woven/nested patterns.
  for (int i = 0; i < termAmp.length; i++) {
    float a = termAmp[i];
    float f = termFreq[i];
    float p = termPhase[i];
    x += a * cos(f * tt + p);
    y += a * sin(f * tt + p);
  }

  return new PVector(x, y);
}

void randomizePattern() {
  useEpitrochoid = random(1) > 0.5;

  R = random(170.0, 290.0);
  r = random(35.0, R * 0.42);
  d = random(r * 0.45, r * 2.4);
  maxT = TWO_PI * random(130.0, 260.0);

  for (int i = 0; i < termAmp.length; i++) {
    termAmp[i] = random(4.0, 22.0);
    termFreq[i] = random(2.0, 15.0);
    termPhase[i] = random(TWO_PI);
  }
}
