final int CANVAS_SIZE = 1024;
final float NOISE_SCALE = 0.0065;
final float TIME_SPEED = 0.012;
final float HUE_SPREAD = 360.0;

float timeOffset = 0.0;

void settings() {
  size(CANVAS_SIZE, CANVAS_SIZE, P2D);
}

void setup() {
  colorMode(HSB, 360, 100, 100, 100);
  noSmooth();
}

void draw() {
  loadPixels();

  float t = timeOffset;
  for (int y = 0; y < height; y++) {
    int rowStart = y * width;
    float ny = y * NOISE_SCALE;

    for (int x = 0; x < width; x++) {
      float nx = x * NOISE_SCALE;

      float hueNoise = noise(nx, ny, t);
      float satNoise = noise(nx + 73.1, ny + 19.7, t + 11.3);
      float briNoise = noise(nx + 151.2, ny + 44.9, t + 23.8);

      float hue = hueNoise * HUE_SPREAD;
      float saturation = 55 + satNoise * 45;
      float brightness = 35 + briNoise * 65;

      pixels[rowStart + x] = color(hue, saturation, brightness, 100);
    }
  }

  updatePixels();
  timeOffset += TIME_SPEED;
}
