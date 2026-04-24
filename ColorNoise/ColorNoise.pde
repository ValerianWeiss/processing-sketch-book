final float NOISE_SCALE = 1.0;
final float TIME_SPEED = 0.012;
final float HUE_SPREAD = 360.0;

float timeOffset = 0.0;

void setup() {
  size(1024, 1024, P2D);
  colorMode(HSB, 360, 100, 100, 100);
  noSmooth();
}

void draw() {
  loadPixels();

  float t = timeOffset;
  for (int y = 0; y < height; y++) {
    int rowStart = y * width;
    float ny = (y / float(height - 1)) * NOISE_SCALE;

    for (int x = 0; x < width; x++) {
      float nx = (x / float(width - 1)) * NOISE_SCALE;

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
