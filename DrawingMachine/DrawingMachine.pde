/**
 * DrawingMachine - A CNC-like drawing machine visualization
 *
 * This sketch simulates a trammel drive mechanism with 3 rotating motors
 * and planks that generate mandala-like patterns at their intersection point.
 *
 * Controls:
 * - 'c' or 'C': Clear canvas
 * - 's' or 'S': Save current frame
 */

// Motor positions (arranged in a triangle)
PVector[] motorPositions;

// Current angles for each motor (plank rotation)
float[] angles;

// Angular speeds for each motor (different speeds create interesting patterns)
float[] speeds;

// Motor orbit angles (position around center)
float[] orbitAngles;

// Angular speeds for orbit rotation
float[] orbitSpeeds;

// Plank length (distance from motor to intersection point)
float plankLength;

// Previous intersection point for drawing trails
PVector prevPoint;

// Trail history for visualization
ArrayList<PVector> trail;

// Maximum trail length
int maxTrailLength = 2000;

// Motor sizes (different diameters for each motor)
float[] motorSizes;

// Plank width
float plankWidth = 15;

// Orbit radius (distance from center)
float orbitRadius = 250;

void settings() {
  size(800, 800);
}

void setup() {
  frameRate(60);
  background(10);

  // Initialize motor positions array
  motorPositions = new PVector[3];

  // Initialize angles and random speeds for each motor (plank rotation)
  angles = new float[3];
  speeds = new float[3];

  // Initialize orbit angles and speeds (motor position around center)
  orbitAngles = new float[3];
  orbitSpeeds = new float[3];

  for (int i = 0; i < 3; i++) {
    // Plank rotation
    speeds[i] = random(-0.05, 0.05);
    angles[i] = random(TWO_PI);

    // Orbit rotation (slower)
    orbitSpeeds[i] = random(-0.005, 0.005);
    orbitAngles[i] = TWO_PI * i / 3 - PI / 2; // Start in triangle formation
  }

  // Initialize motor sizes (different diameters)
  motorSizes = new float[3];
  motorSizes[0] = 12;
  motorSizes[1] = 18;
  motorSizes[2] = 15;

  // Plank length (distance from motor to approximate center)
  plankLength = 300;

  // Initialize previous point and trail
  prevPoint = null;
  trail = new ArrayList<PVector>();

  // Set color mode
  colorMode(HSB, 360, 100, 100, 100);
}

void draw() {
  // Update motor positions (orbit around center)
  updateMotorPositions();

  // Draw motor center points with different sizes
  fill(255);
  noStroke();
  for (int i = 0; i < 3; i++) {
    ellipse(motorPositions[i].x, motorPositions[i].y, motorSizes[i], motorSizes[i]);
  }

  // Calculate current intersection point
  PVector currentPoint = calculateIntersectionPoint();

  if (currentPoint != null) {
    // Draw line from previous point to current point
    if (prevPoint != null) {
      // Color based on position and time
      float hue = (frameCount * 0.5 + dist(0, 0, currentPoint.x - width/2, currentPoint.y - height/2)) % 360;
      stroke(hue, 70, 90, 60);
      strokeWeight(2);
      line(prevPoint.x, prevPoint.y, currentPoint.x, currentPoint.y);

      // Add to trail
      trail.add(currentPoint.copy());
      if (trail.size() > maxTrailLength) {
        trail.remove(0);
      }
    }
    prevPoint = currentPoint.copy();
  }

  // No visual elements drawn - only the intersection trail

  // Update plank angles
  for (int i = 0; i < 3; i++) {
    angles[i] += speeds[i];
    orbitAngles[i] += orbitSpeeds[i];
  }
}

/**
 * Update motor positions based on orbit angles.
 */
void updateMotorPositions() {
  PVector center = new PVector(width/2, height/2);
  for (int i = 0; i < 3; i++) {
    motorPositions[i] = new PVector(
      center.x + cos(orbitAngles[i]) * orbitRadius,
      center.y + sin(orbitAngles[i]) * orbitRadius
    );
  }
}

/**
 * Calculate the intersection point of the three planks.
 * Each plank rotates around its motor and points toward the center.
 * The intersection is the centroid of the triangle formed by endpoints.
 */
PVector calculateIntersectionPoint() {
  PVector[] endpoints = new PVector[3];
  PVector center = new PVector(width/2, height/2);

  // Calculate endpoint of each plank
  for (int i = 0; i < 3; i++) {
    // Calculate angle from motor to center, then add rotation angle
    float angleToCenter = atan2(center.y - motorPositions[i].y, center.x - motorPositions[i].x);
    float plankAngle = angleToCenter + angles[i];

    endpoints[i] = new PVector(
      motorPositions[i].x + cos(plankAngle) * plankLength,
      motorPositions[i].y + sin(plankAngle) * plankLength
    );
  }

  // Calculate centroid of the triangle formed by endpoints
  float centerX = (endpoints[0].x + endpoints[1].x + endpoints[2].x) / 3;
  float centerY = (endpoints[0].y + endpoints[1].y + endpoints[2].y) / 3;

  return new PVector(centerX, centerY);
}


void keyPressed() {
  if (key == 'c' || key == 'C') {
    background(10);
    trail.clear();
    prevPoint = null;
  }
  if (key == 's' || key == 'S') {
    saveFrame("drawing-machine-####.png");
  }
}
