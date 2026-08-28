import 'dart:math' as math;
import 'dart:ui';

class FittedCanvasTransform {
  const FittedCanvasTransform({required this.scale, required this.offset});

  factory FittedCanvasTransform.contain({
    required Size canvasSize,
    required double contentWidth,
    required double contentHeight,
  }) {
    final scale = math.min(
      canvasSize.width / contentWidth,
      canvasSize.height / contentHeight,
    );
    return FittedCanvasTransform(
      scale: scale,
      offset: Offset(
        (canvasSize.width - contentWidth * scale) / 2,
        (canvasSize.height - contentHeight * scale) / 2,
      ),
    );
  }

  final double scale;
  final Offset offset;

  Offset mapPoint(Offset point) => offset + point * scale;

  Rect destinationRect(double contentWidth, double contentHeight) =>
      offset & Size(contentWidth * scale, contentHeight * scale);

  void applyTo(Canvas canvas) {
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
  }

  @override
  bool operator ==(Object other) =>
      other is FittedCanvasTransform &&
      scale == other.scale &&
      offset == other.offset;

  @override
  int get hashCode => Object.hash(scale, offset);
}
