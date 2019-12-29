// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

enum _Element {
  background,
  text,
  shadow,
}

final _lightTheme = {
  _Element.background: Color(0xffffdf9c),
  _Element.text: Color(0xFFFFEBC1),
  _Element.shadow: Color(0xFF282827),
};

final _darkTheme = {
  _Element.background: Colors.black,
  _Element.text: Colors.white,
  _Element.shadow: Color(0xFF174EA6),
};

/// A basic digital clock.
///
/// You can do better than this!
class DigitalClock extends StatefulWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  _DigitalClockState createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock>
    with TickerProviderStateMixin {
  DateTime _dateTime = DateTime.now();
  DateTime _oldDateTime;
  Timer _timer;
  List<double> _arrowsIndex = [-2, -1, 0, 1, 2, 3];
  final List<Color> _arrowColors = [
    Color(0xff686868),
    Color(0xffF2D2A2),
    Color(0xffC6A681),
    Color(0xff686868),
    Color(0xffF2D2A2),
    Color(0xffC6A681)
  ];
  int _transitionColor = 2;

  AnimationController _timeClipAnimationController;
  Animation<double> _timeClipAnimation;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();

    _timeClipAnimationController =
        AnimationController(duration: Duration(milliseconds: 500), vsync: this);
    _timeClipAnimationController.addStatusListener((status) {
      if(status == AnimationStatus.completed) {
        setState(() {
          _transitionColor++;
          if (_transitionColor >= _arrowColors.length) _transitionColor = 0;
        });
      }
    });

    _timeClipAnimation =
        Tween(begin: 1.0, end: 0.0).animate(_timeClipAnimationController)
          ..addListener(() {
            setState(() {});
          });
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
    setState(() {
      // Cause the clock to rebuild when the model changes.
    });
  }

  void _updateTime() {
    setState(() {
      _oldDateTime = _dateTime;
      _dateTime = DateTime.now();
      // Update once per minute.
      _timer = Timer(
        Duration(minutes: 1) -
            Duration(seconds: _dateTime.second) -
            Duration(milliseconds: _dateTime.millisecond),
        _updateTime,
      );

      _cycleArrows();

      _timeClipAnimationController?.reset();
      _timeClipAnimationController?.forward();
    });
  }

  _cycleArrows() {
    _arrowsIndex.insert(0, _arrowsIndex.last);
    _arrowsIndex.removeLast();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.light
        ? _lightTheme
        : _darkTheme;
    final hourOld = DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh')
        .format(_oldDateTime);
    final minuteOld = DateFormat('mm').format(_oldDateTime);
    final hour =
        DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
    final minute = DateFormat('mm').format(_dateTime);
    final fontSize = MediaQuery.of(context).size.width / 2.8;
    final offset = fontSize / 4;
    final minuteOffset = fontSize / 4;
    final defaultStyle = GoogleFonts.abhayaLibre().copyWith(
      color: colors[_Element.text],
      fontSize: fontSize,
      shadows: [
        Shadow(
          blurRadius: 0,
          color: colors[_Element.shadow],
          offset: Offset(10, 0),
        ),
      ],
    );
    final Size arrowSize = Size(MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height / 1.5);
    final Size screenSize = MediaQuery.of(context).size;

    return Container(
        color: colors[_Element.background],
        child: Stack(
          children: <Widget>[
            // create one Arrow per defined color and give a different offset
            ..._arrowColors
                .asMap()
                .entries
                .map((MapEntry entry) => Arrow(
                      arrowSize: arrowSize,
                      color: entry.value,
                      verticalOffset: _arrowsIndex[entry.key],
                    ))
                .toList(),
            Center(
              child: DefaultTextStyle(
                style: defaultStyle,
                child: ClipPath(
                  clipper: OldTimeClipper(
                      arrowSize, screenSize, _timeClipAnimation.value),
                  child: Stack(
                    children: <Widget>[
                      Positioned(left: offset, top: 0, child: Text(hourOld)),
                      Positioned(
                          right: offset,
                          bottom: offset - minuteOffset,
                          child: Text(minuteOld)),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: DefaultTextStyle(
                style: defaultStyle,
                child: ClipPath(
                  clipper: NewTimeClipper(
                      arrowSize, screenSize, _timeClipAnimation.value),
                  child: Stack(
                    children: <Widget>[
                      Positioned(left: offset, top: 0, child: Text(hour)),
                      Positioned(
                          right: offset, bottom: offset - minuteOffset, child: Text(minute)),
                    ],
                  ),
                ),
              ),
            ),
            Arrow(
              arrowSize: arrowSize,
              color: _arrowColors[_transitionColor],
              verticalOffset: (_timeClipAnimation.value * 5) - 2.5,
            )
          ],
        ),
    );
  }
}

class Arrow extends StatefulWidget {
  Arrow({
    Key key,
    @required this.arrowSize,
    @required this.color,
    @required this.verticalOffset,
  }) : super(key: key);

  final Size arrowSize;
  final Color color;
  final double verticalOffset;

  @override
  _ArrowState createState() => _ArrowState();
}

class _ArrowState extends State<Arrow> with TickerProviderStateMixin {
  AnimationController controller;
  Animation<double> animation;

  @override
  void initState() {
    controller =
        AnimationController(duration: Duration(milliseconds: 500), vsync: this);
    // dummy animation that won't be used, this is the first position of the arrow
    animation = Tween(
            begin: widget.verticalOffset.toDouble(),
            end: widget.verticalOffset.toDouble())
        .animate(controller);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset:
          Offset(0, MediaQuery.of(context).size.height / 3 * animation.value),
      child: CustomPaint(
        size: widget.arrowSize,
        painter: ArrowPainter(widget.color),
      ),
    );
  }

  // this is triggered whenever the index was modified
  @override
  void didUpdateWidget(Arrow oldWidget) {
    double oldIndex = oldWidget.verticalOffset.toDouble();
    double newIndex = widget.verticalOffset.toDouble();
    // animate the arrow only if the index property changed
    if (oldIndex != newIndex) {
      controller.dispose();
      // don't to animate in the direction down, move instantly up
      bool goingUp = newIndex < oldIndex;
      controller = AnimationController(
          duration: Duration(milliseconds: goingUp ? 250 : 0), vsync: this);
      // create an Tween Animation that will translate the arrow to the vertical position defined by the index
      animation = Tween(begin: oldIndex, end: newIndex).animate(controller)
        ..addListener(() {
          setState(() {});
        });
      // start the animation immediately
      controller.forward();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class ArrowPainter extends CustomPainter {
  Color color;

  ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path()
      ..moveTo(0, size.height / 2.0)
      ..lineTo(size.width / 2.0, 0)
      ..lineTo(size.width, size.height / 2.0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2.0, size.height / 2.0)
      ..lineTo(0, size.height);

    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class OldTimeClipper extends CustomClipper<Path> {
  final Size arrowSize;
  final Size screenSize;
  final double offset;

  OldTimeClipper(this.arrowSize, this.screenSize, this.offset);

  @override
  Path getClip(Size size) {
    double heightOffset = (offset - 1) * screenSize.height;

    return Path()
      ..moveTo(0, heightOffset)
      ..lineTo(arrowSize.width, heightOffset)
      ..lineTo(arrowSize.width, screenSize.height + heightOffset)
      ..lineTo(arrowSize.width / 2.0,
          screenSize.height - arrowSize.height / 2.0 + heightOffset)
      ..lineTo(0, screenSize.height + heightOffset);
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) {
    return true;
  }
}

class NewTimeClipper extends CustomClipper<Path> {
  final Size arrowSize;
  final Size screenSize;
  final double offset;

  NewTimeClipper(this.arrowSize, this.screenSize, this.offset);

  @override
  Path getClip(Size size) {
    double heightOffset = offset * screenSize.height;

    return Path()
      ..moveTo(0, heightOffset)
      ..lineTo(arrowSize.width / 2.0, -arrowSize.height / 2.0 + heightOffset)
      ..lineTo(arrowSize.width, heightOffset)
      ..lineTo(arrowSize.width, screenSize.height + heightOffset)
      ..lineTo(0, screenSize.height + heightOffset);
  }

  @override
  bool shouldReclip(CustomClipper oldClipper) {
    return true;
  }
}
