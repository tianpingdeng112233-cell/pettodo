import 'package:flutter/material.dart';

/// A crisp, axis-aligned pixel border.
///
/// [StairBorder.large] follows the Direction A `.pc` polygon: a 12 px corner
/// made from two 4 px steps. [StairBorder.small] follows `.ps`: one 4 px step.
class StairBorder extends OutlinedBorder {
  const StairBorder.large({super.side = BorderSide.none})
    : cornerExtent = 12,
      step = 4;

  const StairBorder.small({super.side = BorderSide.none})
    : cornerExtent = 4,
      step = 4;

  const StairBorder._({
    required this.cornerExtent,
    required this.step,
    required super.side,
  });

  final double cornerExtent;
  final double step;

  bool get isLarge => cornerExtent > step;

  /// Ordered clockwise to mirror the design artboard polygons exactly.
  List<Offset> outerVertices(Rect rect) {
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;
    if (!isLarge) {
      return <Offset>[
        Offset(left, top + step),
        Offset(left + step, top + step),
        Offset(left + step, top),
        Offset(right - step, top),
        Offset(right - step, top + step),
        Offset(right, top + step),
        Offset(right, bottom - step),
        Offset(right - step, bottom - step),
        Offset(right - step, bottom),
        Offset(left + step, bottom),
        Offset(left + step, bottom - step),
        Offset(left, bottom - step),
      ];
    }
    return <Offset>[
      Offset(left, top + cornerExtent),
      Offset(left + step, top + cornerExtent),
      Offset(left + step, top + step),
      Offset(left + cornerExtent, top + step),
      Offset(left + cornerExtent, top),
      Offset(right - cornerExtent, top),
      Offset(right - cornerExtent, top + step),
      Offset(right - step, top + step),
      Offset(right - step, top + cornerExtent),
      Offset(right, top + cornerExtent),
      Offset(right, bottom - cornerExtent),
      Offset(right - step, bottom - cornerExtent),
      Offset(right - step, bottom - step),
      Offset(right - cornerExtent, bottom - step),
      Offset(right - cornerExtent, bottom),
      Offset(left + cornerExtent, bottom),
      Offset(left + cornerExtent, bottom - step),
      Offset(left + step, bottom - step),
      Offset(left + step, bottom - cornerExtent),
      Offset(left, bottom - cornerExtent),
    ];
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final inset = side.strokeInset;
    return getOuterPath(rect.deflate(inset), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final vertices = outerVertices(rect);
    return Path()..addPolygon(vertices, true);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.strokeInset / 2)),
      Paint()
        ..color = side.color
        ..strokeWidth = side.width
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = false,
    );
  }

  @override
  ShapeBorder scale(double t) => StairBorder._(
    cornerExtent: cornerExtent * t,
    step: step * t,
    side: side.scale(t),
  );

  @override
  StairBorder copyWith({BorderSide? side}) => StairBorder._(
    cornerExtent: cornerExtent,
    step: step,
    side: side ?? this.side,
  );
}

/// Input-border adapter that delegates all geometry to [StairBorder.small].
class StairInputBorder extends InputBorder {
  const StairInputBorder({super.borderSide = BorderSide.none});

  @override
  bool get isOutline => true;

  StairBorder get _shape => StairBorder.small(side: borderSide);

  @override
  EdgeInsetsGeometry get dimensions => _shape.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) => _shape.paint(canvas, rect, textDirection: textDirection);

  @override
  StairInputBorder copyWith({BorderSide? borderSide}) =>
      StairInputBorder(borderSide: borderSide ?? this.borderSide);

  @override
  StairInputBorder scale(double t) =>
      StairInputBorder(borderSide: borderSide.scale(t));
}
