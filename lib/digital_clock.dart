import 'dart:async';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:spritewidget/spritewidget.dart';

import './sprites_widget_logic/sprite_widget_root.dart';

class DigitalClock extends StatefulWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  _DigitalClockState createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  Timer _timer;
  SpriteWidgetRoot _rootWidget;

  @override
  void initState() {
    super.initState();
    _rootWidget = SpriteWidgetRoot(model: widget.model);
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  @override
  void didUpdateWidget(DigitalClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    super.dispose();
  }

  void _updateModel() {
    _rootWidget.updateModel(widget.model);
  }

  void _updateTime() {
    final dateTime = DateTime.now();
    _rootWidget.setTime(dateTime);
    _timer = Timer(
      Duration(minutes: 1) -
          Duration(seconds: dateTime.second) -
          Duration(milliseconds: dateTime.millisecond),
      _updateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    _rootWidget.updateTheme(Theme.of(context).brightness);
    return ClipRect(
      child: Stack(
        children: <Widget>[
          Container(
            width: double.infinity,
            height: double.infinity,
            //child: Image.asset(
            //  Theme.of(context).brightness == Brightness.dark
            //      ? "assets/dark_wall.png"
            //      : "assets/light_wall.png",
            //  fit: BoxFit.cover,
            //),
          ),
          SpriteWidget(
            _rootWidget,
          ),
        ],
      ),
    );
  }
}
