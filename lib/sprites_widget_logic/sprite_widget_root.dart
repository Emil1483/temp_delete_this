import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_clock_helper/model.dart';
import 'package:spritewidget/spritewidget.dart';
import 'package:vector_math/vector_math.dart';

import './boid.dart';
import './quad_tree.dart';
import './delaunay.dart';
import './effects.dart';
import './wallpaper.dart' show Wallpaper;

class SpriteWidgetRoot extends NodeWithSize {
  static const int boidsPerChar = 115;
  static const double shakeMag = 20;
  static const double shakeMult = 0.8;

  static const double hueSpeed = 5;

  DateTime dateTime = DateTime.now();
  ClockModel clockModel;

  List<Boid> boids = List<Boid>();

  QuadTree qTree;

  List<List<Vector2>> numbers = [];

  Effects effects;

  double shake = 0;

  double hueOff = 0;
  double hueOffTarget = 0;

  Wallpaper wallpaper;

  List<int> savedDelaunay;

  SpriteWidgetRoot({ClockModel model}) : super(const Size(500, 300)) {
    effects = Effects(size, onThunder: () {
      shake = shakeMag;
      for (Boid boid in boids) {
        boid.shakeVel();
      }
    });
    wallpaper = Wallpaper(size);
    updateModel(model, animation: false);
  }

  bool allBoidsStill() {
    if (boids.length == 0) return false;
    for (Boid b in boids) {
      if (!b.isStill()) return false;
    }
    return true;
  }

  void updateTheme(Brightness brightness) {
    wallpaper.updateTheme(brightness);
  }

  Future<void> initNumbers() async {
    String jsonString = await rootBundle.loadString("assets/numbers.json");
    final List<dynamic> numbersData = json.decode(jsonString)["numbers"];
    for (int i = 0; i < 10; i++) {
      final List<dynamic> pointsData = numbersData[i]["points"];
      List<Vector2> number = pointsData
          .map((dynamic value) => Vector2(
                value["x"].toDouble(),
                value["y"].toDouble(),
              ))
          .toList();
      numbers.add(number);
    }
  }

  void updateBoids(int index, int number, {bool update = true}) async {
    final double padding = 25;
    final double width = size.width / 8;
    final double height = size.height * 0.55;
    final double between = 45;

    final List<Vector2> possible = numbers[number];
    possible.shuffle();
    for (int j = 0; j < boidsPerChar; j++) {
      double xOff = index * width +
          (index >= 2 ? size.width - width * 4 : 0) +
          (index >= 2 ? -padding : padding) +
          (index == 1 ? between : 0) +
          (index == 2 ? -between : 0);

      Vector2 pos = Vector2.copy(possible[j]);
      pos.x *= width;
      pos.y *= height;
      pos += Vector2(xOff, (size.height - height) / 2);

      if (update) {
        boids[index * boidsPerChar + j].setTarget(pos);
      } else {
        boids.add(Boid(size, pos));
      }
    }
  }

  int intAt(int number, int index) {
    String numString = (number < 10 ? "0" : "") + number.toString();
    return int.parse(numString.substring(index, index + 1));
  }

  void setTime(DateTime time) async {
    if (boids.length == 0) {
      await initNumbers();

      updateBoids(0, intAt(time.hour, 0), update: false);
      updateBoids(1, intAt(time.hour, 1), update: false);
      updateBoids(2, intAt(time.minute, 0), update: false);
      updateBoids(3, intAt(time.minute, 1), update: false);
      return;
    }

    updateBoids(3, intAt(time.minute, 1));

    if (intAt(time.minute, 0) != intAt(dateTime.minute, 0))
      updateBoids(2, intAt(time.minute, 0));

    if (intAt(time.hour, 1) != intAt(dateTime.hour, 1))
      updateBoids(1, intAt(time.hour, 1));

    if (intAt(time.hour, 0) != intAt(dateTime.hour, 0))
      updateBoids(0, intAt(time.hour, 0));

    dateTime = time;
  }

  void updateModel(ClockModel model, {bool animation = true}) {
    effects.addEffect(model.weatherCondition);

    clockModel = model;
    final double temperature = model.unit == TemperatureUnit.celsius
        ? model.temperature
        : fahrenheitToCelsius(model.temperature);
    if (temperature > 28) {
      hueOffTarget = -165;
    } else {
      hueOffTarget = 0;
    }
    if (!animation) hueOff = hueOffTarget;
  }

  double fahrenheitToCelsius(double f) {
    return (f - 32) / 1.8;
  }

  @override
  void update(_) {
    wallpaper.update();

    if ((hueOff - hueOffTarget).abs() > hueSpeed) {
      hueOff -= (hueOff - hueOffTarget).sign * hueSpeed;
    } else {
      hueOff = hueOffTarget;
    }

    shake *= shakeMult;

    effects.update();

    if (allBoidsStill()) {
      savedDelaunay ??= triangulate(
        boids.map((Boid b) => [b.pos.x, b.pos.y]).toList(),
      );
      return;
    } else {
      savedDelaunay = null;
    }

    qTree = QuadTree(
      pos: Vector2(size.width / 2, size.height / 2),
      w: size.width,
      h: size.height,
    );

    for (Boid boid in boids) {
      qTree.insert(
        Point(pos: boid.pos, data: boid),
      );
    }
    for (Boid boid in boids) {
      if (boid.isStill()) continue;
      List<Boid> others = queryBoids(boid.pos);
      boid.flock(others);
      boid.update();
    }
  }

  List<Boid> queryBoids(Vector2 pos) {
    if (qTree == null) return [];
    List<Point> data = qTree.circleQuery(pos, Boid.observeRadius);
    return data.map((Point p) => p.data as Boid).toList();
  }

  @override
  void paint(Canvas canvas) {
    wallpaper.paint(canvas);

    if (boids.length == 0) return;
    if (shake > 1) {
      math.Random r = math.Random();

      canvas.translate(
        r.nextDouble() * shake * 2 - shake,
        r.nextDouble() * shake * 2 - shake,
      );
    }

    effects.paint(canvas);

    final List<int> result = savedDelaunay ??
        triangulate(
          boids.map((Boid b) => [b.pos.x, b.pos.y]).toList(),
        );
    for (int i = 0; i < result.length; i += 3) {
      final Boid p1 = boids[result[i].round()];
      final Boid p2 = boids[result[i + 1].round()];
      final Boid p3 = boids[result[i + 2].round()];

      final double distThreshSq = 500;

      if (p1.pos.distanceToSquared(p2.pos) > distThreshSq) continue;
      if (p2.pos.distanceToSquared(p3.pos) > distThreshSq) continue;
      if (p1.pos.distanceToSquared(p3.pos) > distThreshSq) continue;

      double hue = p1.colorConst > 0
          ? 165 + p1.colorConst * 60
          : 225 + p1.colorConst * 60;

      hue += hueOff;

      canvas.drawPath(
          Path()
            ..moveTo(p1.pos.x, p1.pos.y)
            ..lineTo(p2.pos.x, p2.pos.y)
            ..lineTo(p3.pos.x, p3.pos.y),
          Paint()
            ..style = PaintingStyle.fill
            ..color = HSLColor.fromAHSL(1, hue, 1, 0.5).toColor());
    }
  }
}
