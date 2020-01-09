import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

class Boid {
  static const double observeRadius = 16;
  static const double observeRadiusSq = observeRadius * observeRadius;

  static const double speed = 1.6;

  static const double alignmentForce = 0.18;
  static const double cohesionForce = 0.14;
  static const double separationForce = 0.16;
  static const double locateForce = 0.22;

  static const double padding = 2;

  static const double closeThreshMax = 100;
  static const double closeThreshMin = 50;
  static const double comingMult = 0.06;

  static const double shakeReduction = 0.05;
  static const double shakeMagnitude = 8;

  double far = 0.0;
  double disableFar = 0.0;

  Size canvasSize;
  Vector2 pos;
  Vector2 vel;
  Vector2 acc;

  Vector2 target;

  double colorConst;

  Boid(Size size, Vector2 t) {
    canvasSize = size;

    target = Vector2.copy(t);

    pos = Vector2.copy(t);

    vel = Vector2.zero();
    acc = Vector2.zero();

    colorConst = math.Random().nextDouble() * 2 - 1;
  }

  bool isStill() {
    if (pos.distanceToSquared(target) > 1) return false;
    if (vel.length2 > 1) return false;
    return true;
  }

  void shakeVel() {
    disableFar = 1;

    math.Random r = math.Random();
    vel = Vector2(
      r.nextDouble() * shakeMagnitude - shakeMagnitude / 2,
      r.nextDouble() * shakeMagnitude - shakeMagnitude / 2,
    );
  }

  void steer({
    @required Vector2 Function() getDesired,
    @required double maxForce,
  }) {
    Vector2 desired = getDesired();
    desired.normalize();
    desired.scale(speed);
    Vector2 steering = desired - vel;
    if (steering.length > maxForce) {
      steering.normalize();
      steering.scale(maxForce);
    }
    applyForce(steering);
  }

  void edges() {
    if (pos.x > canvasSize.width + padding) pos.x = -padding;
    if (pos.x < -padding) pos.x = canvasSize.width + padding;
    if (pos.y > canvasSize.height + padding) pos.y = -padding;
    if (pos.y < -padding) pos.y = canvasSize.height + padding;
  }

  void alignment(List<Boid> boids) {
    steer(
      maxForce: alignmentForce * far,
      getDesired: () {
        Vector2 desired = Vector2.zero();
        int total = 0;
        for (Boid other in boids) {
          if (other == this) continue;
          desired.add(other.vel);
          total++;
        }
        if (total == 0) return Vector2.copy(vel);
        return desired;
      },
    );
  }

  void cohesion(List<Boid> boids) {
    steer(
      maxForce: cohesionForce * far,
      getDesired: () {
        Vector2 desired = Vector2.zero();
        int total = 0;
        for (Boid other in boids) {
          if (other == this) continue;
          desired.add(other.pos);
          total++;
        }
        if (total == 0) return Vector2.copy(vel);
        desired.scale(1 / total);
        desired.sub(pos);
        return desired;
      },
    );
  }

  void spearation(List<Boid> boids) {
    steer(
      maxForce: separationForce * far,
      getDesired: () {
        Vector2 desired = Vector2.zero();
        int total = 0;
        for (Boid other in boids) {
          if (other == this) continue;
          final dist = pos.distanceTo(other.pos);
          desired.add((pos - other.pos) / dist);
          total++;
        }
        if (total == 0) return Vector2.copy(vel);

        return desired;
      },
    );
  }

  void locate() {
    steer(
      maxForce: locateForce,
      getDesired: () => target - pos,
    );
  }

  void setTarget(Vector2 t) {
    target.setFrom(t);
  }

  void flock(List<Boid> boids) {
    alignment(boids);
    cohesion(boids);
    spearation(boids);
    locate();
  }

  void applyForce(Vector2 force) {
    acc.add(force);
  }

  void update() {
    disableFar = (disableFar - shakeReduction).clamp(0.0, 1.0);

    far = ((pos.distanceToSquared(target) - closeThreshMin) /
            (closeThreshMax - closeThreshMin))
        .clamp(0.0, 1.0);
    if (far < 1) {
      final double close = 1 - far;
      Vector2 diff = target - pos;
      diff.scale(comingMult * close * (1 - disableFar));
      pos.add(diff);
    }

    vel.add(acc);
    vel.scale((far + disableFar).clamp(0.0, 1.0));
    pos.add(vel);
    edges();

    colorConst += vel.length2 / 50;
    if (colorConst > 1) colorConst = -1;

    acc.setZero();
  }

  void paint(Canvas canvas) {
    canvas.drawCircle(
      Offset(pos.x, pos.y),
      3,
      Paint()..color = isStill() ? Color(0xFFFF00FF) :  Color(0xFFFFFFFF),
    );
  }
}
