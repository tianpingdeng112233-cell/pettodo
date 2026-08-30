import 'package:flutter/material.dart';

import '../theme/pet_colors.dart';
import '../theme/pet_motion.dart';
import '../theme/stair_border.dart';

class BondProgressBar extends StatelessWidget {
  const BondProgressBar({super.key, required this.value, this.highlightStart})
    : assert(value >= 0 && value <= 1),
      assert(highlightStart == null || highlightStart >= 0),
      assert(highlightStart == null || highlightStart <= value);

  final double value;
  final double? highlightStart;

  // Deliberately NOT a progress-bar semantics role: that role requires a
  // numeric value, and the bond bar never announces numbers (no forecast).
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bond progress',
    child: SizedBox(
      height: 10,
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: StairBorder.small()),
        child: ColoredBox(
          color: PetColors.inactive,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: PetMotion.task,
                  widthFactor: value,
                  heightFactor: 1,
                  child: const ColoredBox(color: PetColors.primary),
                ),
              ),
              if (highlightStart case final start?)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: value == 0 ? 0 : (value - start) / value,
                        heightFactor: 1,
                        child: const ColoredBox(color: PetColors.ballHighlight),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
