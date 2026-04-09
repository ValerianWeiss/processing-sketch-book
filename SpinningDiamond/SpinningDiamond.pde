float rotationY = 0.0;
float orbitYaw = PI * 0.25;
float orbitPitch = -0.2;
float orbitRadius = 520.0;

final float ORBIT_SENSITIVITY = 0.01;
final float MIN_PITCH = -1.4;
final float MAX_PITCH = 1.4;

void setup() {
  size(720, 720, P3D);
  noStroke();
}

void draw() {
  background(0);

  float targetX = width * 0.5;
  float targetY = height * 0.5;
  float targetZ = 0.0;

  float cameraX = targetX + cos(orbitPitch) * sin(orbitYaw) * orbitRadius;
  float cameraY = targetY + sin(orbitPitch) * orbitRadius;
  float cameraZ = targetZ + cos(orbitPitch) * cos(orbitYaw) * orbitRadius;
  camera(cameraX, cameraY, cameraZ, targetX, targetY, targetZ, 0, 1, 0);

  lights();
  directionalLight(200, 200, 200, -0.5, 0.8, -1.0);
  specular(255, 255, 255);
  shininess(80.0);

  pushMatrix();
  translate(width * 0.5, height * 0.5, 0);
  rotateY(rotationY);
  drawOctahedron(160);
  popMatrix();

  rotationY += 0.02;
}

void mouseDragged() {
  if (mouseButton != LEFT) {
    return;
  }

  orbitYaw += (mouseX - pmouseX) * ORBIT_SENSITIVITY;
  orbitPitch -= (mouseY - pmouseY) * ORBIT_SENSITIVITY;
  orbitPitch = constrain(orbitPitch, MIN_PITCH, MAX_PITCH);
}

void drawOctahedron(float radius) {
  beginShape(TRIANGLES);

  // Top pyramid
  vertex(0, -radius, 0);
  vertex(-radius, 0, 0);
  vertex(0, 0, radius);

  vertex(0, -radius, 0);
  vertex(0, 0, radius);
  vertex(radius, 0, 0);

  vertex(0, -radius, 0);
  vertex(radius, 0, 0);
  vertex(0, 0, -radius);

  vertex(0, -radius, 0);
  vertex(0, 0, -radius);
  vertex(-radius, 0, 0);

  // Bottom pyramid
  vertex(0, radius, 0);
  vertex(0, 0, radius);
  vertex(-radius, 0, 0);

  vertex(0, radius, 0);
  vertex(radius, 0, 0);
  vertex(0, 0, radius);

  vertex(0, radius, 0);
  vertex(0, 0, -radius);
  vertex(radius, 0, 0);

  vertex(0, radius, 0);
  vertex(-radius, 0, 0);
  vertex(0, 0, -radius);

  endShape();
}
