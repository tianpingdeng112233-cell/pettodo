import 'package:flutter/material.dart';

import '../theme/pet_colors.dart';
import '../theme/pet_spacing.dart';
import 'pixel_icon.dart';

/// Canonical rendering of the treat currency: bone icon + amount.
///
/// Screen readers still hear "N treats"; the word is only dropped visually.
class TreatCount extends StatelessWidget {
  const TreatCount(
    this.text, {
    super.key,
    this.style,
    this.iconSize = 16,
    this.iconColor,
  });

  final String text;
  final TextStyle? style;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      label: '$text treats',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PxIcon(
              PxIconData.treat,
              size: iconSize,
              color: iconColor ?? effectiveStyle.color ?? PetColors.bodyStrong,
            ),
            const SizedBox(width: PetSpacing.s4),
            Text(text, style: style),
          ],
        ),
      ),
    );
  }
}
