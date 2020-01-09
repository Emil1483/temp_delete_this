import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

import './delaunay.dart';

class Point {
  static const double speed = 0.4;
  static const double padding = 150;

  final Size size;
  Vector2 pos;
  Vector2 vel;

  Point(this.size) {
    math.Random r = math.Random();
    pos = Vector2(
      r.nextDouble() * (size.width + padding * 2) - padding,
      r.nextDouble() * (size.height + padding * 2) - padding,
    );
    final double angle = r.nextDouble() * math.pi * 2;
    vel = Vector2(math.cos(angle), math.sin(angle));
  }

  void edges() {
    if (pos.x > size.width + padding) pos.x = -padding;
    if (pos.x < -padding) pos.x = size.width + padding;
    if (pos.y > size.height + padding) pos.y = -padding;
    if (pos.y < -padding) pos.y = size.height + padding;
  }

  void update() {
    pos.add(vel * speed);
    edges();
  }

  void paint(Canvas canvas) {
    canvas.drawCircle(
      Offset(pos.x, pos.y),
      1.3,
      Paint()..color = Color(0xFFFFFFFF),
    );
  }
}

class Wallpaper {
  static const int totalPoints = 15;

  final Size size;

  final List<Point> points = [];

  Brightness theme;

  Wallpaper(this.size) {
    for (int i = 0; i < totalPoints; i++) {
      points.add(Point(size));
    }
  }

  void updateTheme(Brightness brightness) {
    theme = brightness;
  }

  List<Color> getShaderColors() {
    if (theme == Brightness.dark) {
      return [Color(0xFF29323D), Color(0xFF111111)];
    } else {
      return [Color(0xFF73D863), Color(0xFF5DAD4F)];
    }
  }

  void update() {
    for (Point p in points) {
      p.update();
    }
  }

  void paint(Canvas canvas) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: getShaderColors(),
          transform: GradientRotation(math.pi / 2),
        ).createShader(rect),
    );

    for (Point p in points) {
      p.paint(canvas);
    }

    final List<int> result = triangulate(
      points.map((Point p) => [p.pos.x, p.pos.y]).toList(),
    );
    for (int i = 0; i < result.length; i += 3) {
      final Point p1 = points[result[i].round()];
      final Point p2 = points[result[i + 1].round()];
      final Point p3 = points[result[i + 2].round()];

      canvas.drawPath(
        Path()
          ..moveTo(p1.pos.x, p1.pos.y)
          ..lineTo(p2.pos.x, p2.pos.y)
          ..lineTo(p3.pos.x, p3.pos.y),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Color(0xFFFFFFFF),
      );
    }
  }
}
