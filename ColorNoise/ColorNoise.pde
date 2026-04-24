final int CELL_SIZE = 5;
final float NOISE_SCALE = 1.0;
final float TIME_SPEED = 0.012;
final float HUE_SPREAD = 360.0;

float timeOffset = 0.0;

void setup() {
  size(1024, 1024, P2D);
  colorMode(HSB, 360, 100, 100, 100);
  noSmooth();
  noStroke();
}

void draw() {
  int cols = (width + CELL_SIZE - 1) / CELL_SIZE;
  int rows = (height + CELL_SIZE - 1) / CELL_SIZE;
  float t = timeOffset;
  for (int row = 0; row < rows; row++) {
    float ny = (row / float(max(1, rows - 1))) * NOISE_SCALE;
    int y = row * CELL_SIZE;
    int h = min(CELL_SIZE, height - y);

    for (int col = 0; col < cols; col++) {
      float nx = (col / float(max(1, cols - 1))) * NOISE_SCALE;
      int x = col * CELL_SIZE;
      int w = min(CELL_SIZE, width - x);

      float hueNoise = noise(nx, ny, t);
      float satNoise = noise(nx + 73.1, ny + 19.7, t + 11.3);
      float briNoise = noise(nx + 151.2, ny + 44.9, t + 23.8);

      float hue = hueNoise * HUE_SPREAD;
      float saturation = 55 + satNoise * 45;
      float brightness = 35 + briNoise * 65;

      fill(hue, saturation, brightness, 100);
      rect(x, y, w, h);
    }
  }

  timeOffset += TIME_SPEED;
}
