final int LINE_COUNT = 3;
final float LINE_LENGTH = 2000.0;
final float MIN_SPEED = 0.005;
final float MAX_SPEED = 0.02;

RotatingLine[] rotatingLines = new RotatingLine[LINE_COUNT];
PVector previousPoint;

void setup() {
  size(720, 720);
  background(0);
  stroke(255, 220, 120, 140);
  strokeWeight(1.5);
  smooth(8);

  float centerX = width * 0.5;
  float centerY = height * 0.5;
  float orbitRadius = min(width, height) * 0.2;

  for (int i = 0; i < LINE_COUNT; i++) {
    float startAngle = random(TWO_PI);
    float speed = randomSignedSpeed();
    float directionOffset = random(TWO_PI);
    float directionMultiplier = random(1.1, 2.2);
    rotatingLines[i] = new RotatingLine(centerX, centerY, orbitRadius, startAngle, speed, directionOffset, directionMultiplier);
  }
}

void draw() {
  for (int i = 0; i < LINE_COUNT; i++) {
    rotatingLines[i].advance();
  }

  PVector[] intersections = new PVector[3];
  intersections[0] = lineIntersection(rotatingLines[0], rotatingLines[1]);
  intersections[1] = lineIntersection(rotatingLines[0], rotatingLines[2]);
  intersections[2] = lineIntersection(rotatingLines[1], rotatingLines[2]);

  PVector activePoint = averagePoint(intersections);
  if (activePoint == null) {
    return;
  }

  if (previousPoint != null) {
    line(previousPoint.x, previousPoint.y, activePoint.x, activePoint.y);
  }

  previousPoint = activePoint.copy();
}

float randomSignedSpeed() {
  float speed = random(MIN_SPEED, MAX_SPEED);
  return random(1) > 0.5 ? speed : -speed;
}

PVector averagePoint(PVector[] points) {
  PVector sum = new PVector();
  int count = 0;

  for (int i = 0; i < points.length; i++) {
    if (points[i] == null) {
      continue;
    }

    sum.add(points[i]);
    count++;
  }

  if (count == 0) {
    return null;
  }

  return sum.div((float) count);
}

PVector lineIntersection(RotatingLine a, RotatingLine b) {
  PVector p1 = a.startPoint();
  PVector p2 = a.endPoint();
  PVector q1 = b.startPoint();
  PVector q2 = b.endPoint();

  float denominator = (p1.x - p2.x) * (q1.y - q2.y) - (p1.y - p2.y) * (q1.x - q2.x);
  if (abs(denominator) < 0.0001) {
    return null;
  }

  float pCross = p1.x * p2.y - p1.y * p2.x;
  float qCross = q1.x * q2.y - q1.y * q2.x;

  float x = (pCross * (q1.x - q2.x) - (p1.x - p2.x) * qCross) / denominator;
  float y = (pCross * (q1.y - q2.y) - (p1.y - p2.y) * qCross) / denominator;
  return new PVector(x, y);
}

class RotatingLine {
  PVector center;
  float orbitRadius;
  float orbitAngle;
  float orbitSpeed;
  float directionOffset;
  float directionMultiplier;

  RotatingLine(float centerX, float centerY, float orbitRadiusValue, float startAngle, float speed, float offset, float multiplier) {
    center = new PVector(centerX, centerY);
    orbitRadius = orbitRadiusValue;
    orbitAngle = startAngle;
    orbitSpeed = speed;
    directionOffset = offset;
    directionMultiplier = multiplier;
  }

  void advance() {
    orbitAngle += orbitSpeed;
  }

  PVector pivot() {
    float x = center.x + cos(orbitAngle) * orbitRadius;
    float y = center.y + sin(orbitAngle) * orbitRadius;
    return new PVector(x, y);
  }

  PVector direction() {
    float angle = orbitAngle * directionMultiplier + directionOffset;
    return new PVector(cos(angle), sin(angle));
  }

  PVector startPoint() {
    PVector pivotPoint = pivot();
    PVector dir = direction();
    return new PVector(pivotPoint.x - dir.x * LINE_LENGTH, pivotPoint.y - dir.y * LINE_LENGTH);
  }

  PVector endPoint() {
    PVector pivotPoint = pivot();
    PVector dir = direction();
    return new PVector(pivotPoint.x + dir.x * LINE_LENGTH, pivotPoint.y + dir.y * LINE_LENGTH);
  }
}
