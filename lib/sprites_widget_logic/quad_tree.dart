import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

class Point {
  final Vector2 pos;
  final Object data;

  Point({
    @required this.pos,
    @required this.data,
  });

  @override
  String toString() {
    return pos.toString();
  }
}

class QuadTree {
  static const int maxPoints = 10;

  List<Point> points = [];

  final Vector2 pos;
  final double w;
  final double h;

  bool divided = false;

  QuadTree northWest;
  QuadTree northEast;
  QuadTree southWest;
  QuadTree southEast;

  QuadTree({
    @required this.pos,
    @required this.w,
    @required this.h,
  });

  @override
  String toString() {
    String children = divided
        ? ", northWest: $northWest, northEast: $northEast, southWest: $southWest, southEast: $southEast"
        : "";
    return "w: $w, h: $h, pos: $pos points: $points $children";
  }

  bool containsPoint(Vector2 point) {
    double right = pos.x + w / 2;
    double left = pos.x - w / 2;
    double top = pos.y - h / 2;
    double bottom = pos.y + h / 2;
    if (point.x > right) return false;
    if (point.x < left) return false;
    if (point.y > bottom) return false;
    if (point.y < top) return false;
    return true;
  }

  bool intersectsRectangle(Vector2 center, double width, double height) {
    double right = pos.x + w / 2;
    double left = pos.x - w / 2;
    double top = pos.y - h / 2;
    double bottom = pos.y + h / 2;
    if (center.x + width / 2 < left) return false;
    if (center.x - width / 2 > right) return false;
    if (center.y + height / 2 < top) return false;
    if (center.y - height / 2 > bottom) return false;
    return true;
  }

  List<Point> circleQuery(
    Vector2 center,
    double radius,
  ) {
    List<Point> found = query(center, radius * 2, radius * 2);
    final double radiusSq = radius * radius;
    for (int i = found.length - 1; i >= 0; i--) {
      Point p = found[i];
      if (p.pos.distanceToSquared(center) > radiusSq) found.remove(p);
    }
    return found;
  }

  List<Point> query(
    Vector2 center,
    double width,
    double height,
  ) {
    if (!intersectsRectangle(center, width, height)) return [];
    List<Point> found = [];
    found.addAll(points);

    if (!divided) return found;
    found.addAll(northWest.query(center, width, height));
    found.addAll(northEast.query(center, width, height));
    found.addAll(southWest.query(center, width, height));
    found.addAll(southEast.query(center, width, height));

    return found;
  }

  bool insert(Point point) {
    if (!containsPoint(point.pos)) return false;

    if (points.length < maxPoints) {
      points.add(point);
      return true;
    }
    if (!divided) subdivide();

    if (northWest.insert(point)) return true;
    if (northEast.insert(point)) return true;
    if (southWest.insert(point)) return true;
    if (southEast.insert(point)) return true;

    throw FlutterError("no child can contain pos ${point.pos}");
  }

  void subdivide() {
    northWest = QuadTree(
      pos: Vector2(pos.x - w / 4, pos.y - h / 4),
      w: w / 2,
      h: h / 2,
    );
    northEast = QuadTree(
      pos: Vector2(pos.x + w / 4, pos.y - h / 4),
      w: w / 2,
      h: h / 2,
    );
    southWest = QuadTree(
      pos: Vector2(pos.x - w / 4, pos.y + h / 4),
      w: w / 2,
      h: h / 2,
    );
    southEast = QuadTree(
      pos: Vector2(pos.x + w / 4, pos.y + h / 4),
      w: w / 2,
      h: h / 2,
    );

    divided = true;
  }

  void paint(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(pos.x, pos.y),
        height: h,
        width: w,
      ),
      Paint()
        ..color = Color(0xFF000000)
        ..style = PaintingStyle.stroke,
    );
    if (!divided) return;
    northWest.paint(canvas);
    northEast.paint(canvas);
    southWest.paint(canvas);
    southEast.paint(canvas);
  }
}
