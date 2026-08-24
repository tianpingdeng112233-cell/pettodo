import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'pet_colors.dart';
import 'pet_spacing.dart';

class PixelBackground extends StatelessWidget {
  const PixelBackground({
    super.key,
    required this.child,
    this.showHalo = false,
  });

  final Widget child;
  final bool showHalo;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      const DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.screenGradient),
      ),
      const ExcludeSemantics(child: CustomPaint(painter: _DitherPainter())),
      if (showHalo)
        Positioned(
          top: PetSpacing.sunTop,
          left: (MediaQuery.sizeOf(context).width - PetSpacing.sunSize) / 2,
          child: const ExcludeSemantics(child: PixelSunHalo()),
        ),
      child,
    ],
  );
}

class PixelSunHalo extends StatelessWidget {
  const PixelSunHalo({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: <Color>[
          Color.fromRGBO(255, 214, 150, 0.55),
          Color.fromRGBO(255, 214, 150, 0.55),
          Color.fromRGBO(255, 214, 150, 0.38),
          Color.fromRGBO(255, 214, 150, 0.38),
          Color.fromRGBO(255, 214, 150, 0.22),
          Color.fromRGBO(255, 214, 150, 0.22),
          Color.fromRGBO(255, 214, 150, 0.10),
          Color.fromRGBO(255, 214, 150, 0.10),
          PetColors.transparent,
          PetColors.transparent,
        ],
        stops: <double>[0, 0.25, 0.25, 0.45, 0.45, 0.65, 0.65, 0.85, 0.85, 1],
      ),
    ),
    child: SizedBox.square(dimension: PetSpacing.sunSize),
  );
}

class _DitherPainter extends CustomPainter {
  const _DitherPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(185, 107, 46, 0.035)
      ..isAntiAlias = false;
    for (double y = 0; y < size.height; y += 8) {
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawRect(Rect.fromLTWH(x, y, 4, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 4, y + 4, 4, 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DitherPainter oldDelegate) => false;
}
