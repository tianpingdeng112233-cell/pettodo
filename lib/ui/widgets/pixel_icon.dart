import 'package:flutter/material.dart';

import '../theme/pet_colors.dart';

enum PxIconData {
  sliders,
  sparkle,
  bone,
  heart,
  paw,
  plus,
  minus,
  chevronRight,
  back,
  edit,
  photo,
  camera,
  clock,
  package,
  share,
  close,
  sun,
  bolt,
}

class PxIcon extends StatelessWidget {
  const PxIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color = PetColors.bodyStrong,
    this.secondaryColor,
  });

  final PxIconData icon;
  final double size;
  final Color color;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _PxIconPainter(
      icon,
      color,
      secondaryColor ?? color.withValues(alpha: 0.72),
    ),
  );
}

class _PxIconPainter extends CustomPainter {
  const _PxIconPainter(this.icon, this.color, this.secondaryColor);

  final PxIconData icon;
  final Color color;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final primary = Paint()
      ..color = color
      ..isAntiAlias = false;
    final secondary = Paint()
      ..color = secondaryColor
      ..isAntiAlias = false;
    void rect(double x, double y, double width, double height, [Paint? paint]) {
      canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint ?? primary);
    }

    switch (icon) {
      case PxIconData.sliders:
        rect(1, 4, 22, 3, secondary);
        rect(14, 2, 5, 7);
        rect(1, 11, 22, 3, secondary);
        rect(5, 9, 5, 7);
        rect(1, 18, 22, 3, secondary);
        rect(11, 16, 5, 7);
      case PxIconData.sparkle:
        rect(9, 1, 6, 4);
        rect(5, 5, 14, 5);
        rect(9, 10, 6, 5);
        rect(17, 16, 4, 4, secondary);
        rect(2, 17, 3, 3, secondary);
      case PxIconData.bone:
        rect(0, 3, 5, 6);
        rect(0, 15, 5, 6);
        rect(19, 3, 5, 6);
        rect(19, 15, 5, 6);
        rect(3, 8, 18, 8);
      case PxIconData.heart:
        rect(3, 3, 6, 3);
        rect(15, 3, 6, 3);
        rect(1, 6, 3, 8);
        rect(9, 5, 6, 3);
        rect(21, 6, 2, 8);
        rect(4, 14, 3, 3);
        rect(17, 14, 3, 3);
        rect(7, 17, 3, 3);
        rect(14, 17, 3, 3);
        rect(10, 20, 4, 3);
      case PxIconData.paw:
        rect(2, 1, 5, 6);
        rect(9, 0, 6, 6);
        rect(17, 1, 5, 6);
        rect(5, 10, 14, 10);
        rect(8, 7, 8, 4);
        rect(8, 20, 8, 2);
      case PxIconData.plus:
        rect(9, 1, 6, 22);
        rect(1, 9, 22, 6);
      case PxIconData.minus:
        rect(2, 9, 20, 6);
      case PxIconData.chevronRight:
        rect(5, 3, 5, 4);
        rect(9, 6, 5, 4);
        rect(13, 10, 5, 4);
        rect(9, 14, 5, 4);
        rect(5, 18, 5, 4);
      case PxIconData.back:
        rect(1, 10, 20, 5);
        rect(4, 6, 5, 4);
        rect(8, 2, 5, 4);
        rect(4, 15, 5, 4);
        rect(8, 19, 5, 4);
      case PxIconData.edit:
        rect(4, 17, 4, 4);
        rect(7, 14, 4, 4);
        rect(10, 11, 4, 4);
        rect(13, 8, 4, 4);
        rect(16, 5, 4, 4);
        rect(18, 3, 3, 3);
        rect(3, 20, 8, 2, secondary);
      case PxIconData.photo:
        rect(2, 3, 20, 3);
        rect(2, 6, 3, 15);
        rect(19, 6, 3, 15);
        rect(5, 18, 14, 3);
        rect(7, 8, 4, 4, secondary);
        rect(6, 15, 4, 3, secondary);
        rect(10, 12, 4, 6, secondary);
        rect(14, 10, 4, 8, secondary);
      case PxIconData.camera:
        rect(2, 6, 20, 15);
        rect(7, 3, 10, 3);
        rect(9, 9, 6, 3, secondary);
        rect(7, 12, 10, 6, secondary);
        rect(9, 18, 6, 2, secondary);
      case PxIconData.clock:
        rect(7, 2, 10, 3);
        rect(4, 5, 16, 3);
        rect(2, 8, 20, 9);
        rect(4, 17, 16, 3);
        rect(7, 20, 10, 2);
        rect(11, 6, 3, 7, Paint()..color = PetColors.white);
        rect(13, 12, 5, 3, Paint()..color = PetColors.white);
      case PxIconData.package:
        rect(2, 3, 20, 5);
        rect(2, 8, 3, 13);
        rect(19, 8, 3, 13);
        rect(5, 18, 14, 3);
        rect(9, 11, 6, 4);
      case PxIconData.share:
        rect(10, 2, 4, 12);
        rect(6, 5, 4, 4);
        rect(14, 5, 4, 4);
        rect(3, 12, 4, 9, secondary);
        rect(17, 12, 4, 9, secondary);
        rect(6, 18, 12, 3, secondary);
      case PxIconData.close:
        rect(4, 4, 5, 5);
        rect(15, 4, 5, 5);
        rect(8, 8, 8, 8);
        rect(4, 15, 5, 5);
        rect(15, 15, 5, 5);
      case PxIconData.sun:
        rect(9, 1, 6, 4);
        rect(9, 19, 6, 4);
        rect(1, 9, 4, 6);
        rect(19, 9, 4, 6);
        rect(7, 7, 10, 10);
      case PxIconData.bolt:
        rect(12, 1, 6, 8);
        rect(8, 7, 8, 7);
        rect(5, 12, 7, 4);
        rect(8, 14, 6, 9);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PxIconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor;
}
