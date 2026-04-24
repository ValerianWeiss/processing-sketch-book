final float R = 220.0;          // Outer radius
final float r = 63.0;           // Inner rolling radius
final float d = 142.0;          // Pen offset
final float tStep = 0.001;      // Resolution
final float maxT = TWO_PI * 190.0;
final int pointsPerFrame = 240;

final boolean useEpitrochoid = false;  // false -> hypotrochoid

// Optional nested rotations (amplitude, frequency, phase)
final float[] termAmp = {16.0, 9.0};
final float[] termFreq = {5.0, 11.0};
final float[] termPhase = {0.0, PI * 0.33};

float t = 0.0;
PVector prevPoint;

void setup() {
  size(1024, 1024, P2D);
  colorMode(HSB, 360, 255, 255, 255);
  background(8, 8, 12);
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

    float hue = 155.0 + 95.0 * sin(nextT * 0.23);
    float sat = 160.0 + 70.0 * sin(nextT * 0.11 + 1.2);
    float bri = 210.0 + 35.0 * sin(nextT * 0.07);
    stroke(hue, sat, bri, 40);
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
