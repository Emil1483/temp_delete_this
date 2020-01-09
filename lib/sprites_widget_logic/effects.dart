import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:vector_math/vector_math.dart';

abstract class Particle {
  static const double padding = 100;

  Vector2 pos;
  final double z;
  final Size size;

  bool dead = false;
  bool dying = false;
  double aliveness = 1;

  Particle({
    @required this.size,
    @required this.z,
  }) {
    math.Random r = math.Random();
    pos = Vector2(
      r.nextDouble() * (size.width),
      r.nextDouble() * (size.height + padding * 2) - size.height - padding * 2,
    );
  }

  void update() {
    if (dying) aliveness -= 0.01;
    if (aliveness <= 0) dead = true;
  }

  void edges() {
    if (pos.y > size.height + padding) {
      if (dying) {
        dead = true;
      } else {
        reset();
      }
    }
  }

  void reset() {
    pos.y = -padding;
    pos.x = math.Random().nextDouble() * (size.width);
  }

  void paint(Canvas canvas);

  String toString() {
    return "pos: $pos";
  }
}

class Rain extends Particle {
  static const double rainLen = 1.5;
  static const double speed = 25;

  Rain({
    @required Size size,
    @required double z,
  }) : super(size: size, z: z);

  @override
  void update() {
    super.update();

    pos.y += speed / (z * z);
    super.edges();
  }

  @override
  void paint(Canvas canvas) {
    canvas.drawLine(
      Offset(pos.x, pos.y),
      Offset(
        pos.x,
        pos.y - speed * rainLen / (z * z),
      ),
      Paint()
        ..color = HSLColor.fromAHSL(1, -(z - 1) * 30 + 215, 1, 0.5).toColor()
        ..strokeWidth = 1.8 / (z * z),
    );
  }
}

class Snow extends Particle {
  final ui.Image image;
  final Rect src;

  double t = math.Random().nextDouble() * math.pi * 2;

  Snow({
    @required Size size,
    @required double z,
    @required this.image,
    @required this.src,
  }) : super(size: size, z: z);

  @override
  void update() {
    super.update();

    pos.y += 0.5 / (z * z);

    t += 0.025;
    pos.x += math.sin(t) / (2 * z * z);

    super.edges();
  }

  @override
  void paint(Canvas canvas) {
    final double size = 8 / (z * z);
    canvas.save();
    canvas.translate(pos.x, pos.y);
    canvas.rotate(math.sin(t));
    canvas.drawImageRect(
      image,
      src,
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      Paint()
        ..color = Color.fromRGBO(
            0, 0, 0, (aliveness * 1.5 / (z * z)).clamp(0.0, 1.0)),
    );
    canvas.restore();
  }
}

class Thunder {
  static const int lifeTime = 40;

  final ui.Image image;
  final Size size;

  int timer = lifeTime;
  double xOff;

  Thunder({
    @required this.image,
    @required this.size,
  }) {
    final double width = image.width * size.height / image.height;
    xOff = math.Random().nextDouble() * size.width - width / 2;
  }

  bool get dead => timer <= 0;

  void update() {
    timer -= 1;
  }

  void paint(Canvas canvas) {
    final double width = image.width.toDouble();
    final double height = image.height.toDouble();
    final double opacity = Curves.easeOutSine.transform(timer / lifeTime);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width, height),
      Rect.fromLTWH(xOff, 0, width * size.height / height, size.height),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }
}

class Effects {
  static const Duration updateDelay = Duration(milliseconds: 10);
  static const Duration thunderShakeDelay = Duration(milliseconds: 300);

  final List<Particle> particles = List<Particle>();
  final Size size;
  final Function onThunder;

  WeatherCondition weather;

  double thunderTimer;
  List<Thunder> thunders = List<Thunder>();

  Effects(this.size, {@required this.onThunder});

  void addEffect(WeatherCondition condition) {
    if (weather == condition) return;
    weather = condition;

    if (weather == WeatherCondition.snowy) {
      clearParticles();
      addSnow();
    } else if (weather == WeatherCondition.rainy) {
      clearParticles();
      addRain();
    } else if (thunder) {
      clearParticles();
      addThunder();
    } else {
      clearParticles();
    }
  }

  void clearParticles() {
    for (Particle particle in particles) {
      particle.dying = true;
    }
  }

  bool get thunder => weather == WeatherCondition.thunderstorm;

  void addSnow() async {
    ByteData imageBytes = await rootBundle.load("assets/snow.png");
    List<int> values = imageBytes.buffer.asUint8List();
    ui.Image image = await decodeImageFromList(values);
    math.Random r = math.Random();
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < i * i * 30; j++) {
        if (weather != WeatherCondition.snowy) return;
        particles.add(
          Snow(
            size: size,
            z: i * 0.35 + 0.65,
            image: image,
            src: Rect.fromLTWH(
              r.nextInt(3).toDouble() * 51,
              r.nextInt(3).toDouble() * 51,
              50,
              50,
            ),
          ),
        );
        await Future.delayed(updateDelay);
      }
    }
  }

  void addRain() async {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < i * i * 20; j++) {
        if (weather != WeatherCondition.rainy) return;
        particles.add(
          Rain(size: size, z: i * 0.35 + 0.65),
        );
        await Future.delayed(updateDelay);
      }
    }
  }

  void makeThunder() async {
    math.Random r = math.Random();

    thunderTimer = r.nextDouble() * 25 + 5;

    final int index = r.nextInt(3);
    ByteData imageBytes = await rootBundle.load("assets/lightning$index.png");
    List<int> values = imageBytes.buffer.asUint8List();
    ui.Image image = await decodeImageFromList(values);
    thunders.add(
      Thunder(
        image: image,
        size: size,
      ),
    );

    await Future.delayed(thunderShakeDelay);
    onThunder();
  }

  void addThunder() async {
    makeThunder();
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < i * i * 30; j++) {
        if (!thunder) return;
        particles.add(
          Rain(size: size, z: i * 0.35 + 0.65),
        );
        await Future.delayed(updateDelay);
      }
    }
  }

  void update() {
    if (thunder) {
      thunderTimer -= 0.05;
      if (thunderTimer <= 0) {
        makeThunder();
      }
    }

    for (int i = particles.length - 1; i >= 0; i--) {
      if (particles[i].dead) particles.removeAt(i);
    }
    for (Particle p in particles) {
      p.update();
    }

    for (int i = thunders.length - 1; i >= 0; i--) {
      if (thunders[i].dead) thunders.removeAt(i);
    }
    for (Thunder t in thunders) {
      t.update();
    }
  }

  void paint(Canvas canvas) {
    for (Particle p in particles) {
      p.paint(canvas);
    }
    for (Thunder t in thunders) {
      t.paint(canvas);
    }
  }
}
