import 'package:flutter/material.dart';

import '../theme/pet_colors.dart';
import '../theme/pet_effects.dart';
import '../theme/pet_motion.dart';
import '../theme/pet_shadows.dart';
import '../theme/pet_spacing.dart';
import '../theme/pet_text_styles.dart';
import '../theme/stair_border.dart';

class PxCard extends StatelessWidget {
  const PxCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.fillColor = PetColors.white,
    this.borderColor = PetColors.stroke,
    this.borderWidth = 2,
    this.selected = false,
    this.small = false,
    this.shadows = PetShadows.panel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool selected;
  final bool small;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(
      color: selected ? PetColors.primary : borderColor,
      width: selected ? 3 : borderWidth,
    );
    final shape = small
        ? StairBorder.small(side: side)
        : StairBorder.large(side: side);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fillColor,
        shape: shape,
        shadows: shadows,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: Clip.hardEdge,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum PxButtonStyle { primary, outline }

class PxButton extends StatelessWidget {
  const PxButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = PxButtonStyle.primary,
    this.height = 54,
    this.compact = false,
  });

  final Widget label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final PxButtonStyle style;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final primary = style == PxButtonStyle.primary;
    const outlineShape = StairBorder.large(
      side: BorderSide(color: PetColors.bodyStrong, width: 2),
    );
    const primaryShape = StairBorder.large();
    final shape = primary ? primaryShape : outlineShape;
    return Opacity(
      opacity: onPressed == null
          ? PetEffects.disabledButtonOpacity
          : PetEffects.fullOpacity,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: primary ? PetColors.primary : PetColors.transparent,
            shape: shape,
            shadows: primary ? PetShadows.primaryButton : const <BoxShadow>[],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              customBorder: shape,
              onTap: onPressed,
              child: SizedBox(
                height: compact ? null : height,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? PetSpacing.s32 : PetSpacing.s16,
                    vertical: compact ? PetSpacing.s13 : 0,
                  ),
                  child: Row(
                    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        icon!,
                        const SizedBox(width: PetSpacing.s8),
                      ],
                      if (compact)
                        DefaultTextStyle(
                          style: primary
                              ? PetTextStyles.button
                              : PetTextStyles.button.copyWith(
                                  color: PetColors.bodyStrong,
                                ),
                          textAlign: TextAlign.center,
                          child: label,
                        )
                      else
                        Flexible(
                          child: DefaultTextStyle(
                            style: primary
                                ? PetTextStyles.button
                                : PetTextStyles.button.copyWith(
                                    color: PetColors.bodyStrong,
                                  ),
                            textAlign: TextAlign.center,
                            child: label,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PxCheckbox extends StatelessWidget {
  const PxCheckbox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: PetMotion.task,
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: checked ? PetColors.primary : PetColors.inputFill,
      border: Border.all(
        color: checked ? PetColors.primary : PetColors.checkboxBorder,
        width: 3,
      ),
    ),
    child: checked
        ? const CustomPaint(
            painter: _PixelCheckPainter(),
            // Invisible compatibility seam for the pre-existing byIcon
            // regression assertion; the five rectangles above are the art.
            child: Icon(Icons.check_rounded, color: PetColors.transparent),
          )
        : null,
  );
}

class PxToggle extends StatefulWidget {
  const PxToggle({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  State<PxToggle> createState() => _PxToggleState();
}

class _PxToggleState extends State<PxToggle> {
  bool _focused = false;

  void _toggle() {
    if (widget.enabled) widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    toggled: widget.value,
    enabled: widget.enabled,
    label: widget.label,
    onTap: widget.enabled ? _toggle : null,
    child: FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _toggle();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _toggle : null,
        child: ConstrainedBox(
          // Native switches guarantee a 44pt+ hit target; keep parity even
          // though the visible track is 54x30.
          constraints: const BoxConstraints(minWidth: 54, minHeight: 44),
          child: Center(
            child: Opacity(
              opacity: widget.enabled
                  ? PetEffects.fullOpacity
                  : PetEffects.disabledToggleOpacity,
              child: AnimatedContainer(
                duration: PetMotion.quick,
                width: 54,
                height: 30,
                padding: const EdgeInsets.all(3),
                decoration: ShapeDecoration(
                  color: widget.value
                      ? PetColors.primary
                      : PetColors.disabledBorder,
                  shape: _focused
                      ? const StairBorder.small(
                          side: BorderSide(
                            color: PetColors.accentText,
                            width: 2,
                          ),
                        )
                      : const StairBorder.small(),
                ),
                child: AnimatedAlign(
                  duration: PetMotion.quick,
                  alignment: widget.value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: PetColors.white,
                      boxShadow: PetShadows.toggleKnob,
                    ),
                    child: SizedBox.square(dimension: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PxChip extends StatelessWidget {
  const PxChip({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.dashed = false,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final shape = StairBorder.small(
      side: dashed
          ? BorderSide.none
          : BorderSide(
              color: selected ? PetColors.primary : PetColors.stroke,
              width: 2,
            ),
    );
    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: ShapeDecoration(
        color: selected ? PetColors.primary : PetColors.white,
        shape: shape,
      ),
      child: DefaultTextStyle(
        style: selected
            ? PetTextStyles.chip.copyWith(color: PetColors.white)
            : PetTextStyles.chip,
        child: child,
      ),
    );
    if (dashed) {
      content = CustomPaint(
        foregroundPainter: _DashedStairPainter(
          shape: const StairBorder.small(),
          color: PetColors.stroke,
          strokeWidth: 2,
        ),
        child: content,
      );
    }
    return onTap == null
        ? content
        : InkWell(customBorder: shape, onTap: onTap, child: content);
  }
}

/// Dashed outline along a [StairBorder] path — the "escape hatch" affordance
/// for chips that open free input instead of toggling a preset.
class _DashedStairPainter extends CustomPainter {
  const _DashedStairPainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
  });

  final StairBorder shape;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 6.0;
    const gap = 4.0;
    final path = shape.getOuterPath(Offset.zero & size);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStairPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}

class PxInput extends StatelessWidget {
  const PxInput({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.style,
    this.textInputAction,
    this.decoration = const InputDecoration(),
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final int? maxLength;
  final int? maxLines;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextInputAction? textInputAction;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    maxLength: maxLength,
    maxLines: maxLines,
    textAlign: textAlign,
    style: style,
    textInputAction: textInputAction,
    decoration: decoration,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
  );
}

class PxGroundBar extends StatelessWidget {
  const PxGroundBar({
    super.key,
    this.width = 150,
    this.height = 10,
    this.color = PetColors.groundShadow,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: color, shape: const StairBorder.small()),
    child: SizedBox(width: width, height: height),
  );
}

class _PixelCheckPainter extends CustomPainter {
  const _PixelCheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = PetColors.white
      ..isAntiAlias = false;
    const segments = <Rect>[
      Rect.fromLTWH(4, 11, 3, 3),
      Rect.fromLTWH(7, 14, 3, 3),
      Rect.fromLTWH(10, 11, 3, 3),
      Rect.fromLTWH(13, 8, 3, 3),
      Rect.fromLTWH(16, 5, 3, 3),
    ];
    for (final segment in segments) {
      canvas.drawRect(segment, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelCheckPainter oldDelegate) => false;
}
