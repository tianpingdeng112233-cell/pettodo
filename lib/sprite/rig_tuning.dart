/// Every rig magic number lives here — layer-composition geometry constants
/// tuned by eye (motion parameters live in RigDriverParameters).
library;

/// Layer-composition geometry, all fractions of the head/part box size.
abstract final class RigComposeTuning {
  /// Feather radius as a fraction of the part box's short edge.
  static const double featherFraction = 0.018;

  /// Body-layer blur fraction for the head cutout edge.
  static const double cutoutFeatherFraction = 0.012;

  /// Horizontal overshoot of the head cutout beyond the head box.
  static const double headExpansionFraction = 0.05;

  /// Cutout overshoot above the head box top.
  static const double topExpansionFraction = 0.1;

  /// The chest strip kept under the chin: the middle notch stops this far
  /// above head.y1 so the moving head always covers the hole (proven rule:
  /// full-width erase to the chin line, narrow only at the neck).
  static const double neckOverlapFraction = 0.08;

  /// Half-width of the protected neck strip as a fraction of head width.
  static const double neckHalfWidthFraction = 0.23;

  /// Part-layer mask expansion fractions.
  static const double partHorizontalExpansion = 0.04;
  static const double partTopExpansion = 0.04;
  static const double partHeadTopExpansion = 0.1;
  static const double partBottomExpansion = 0.04;
  static const double partCornerRadiusFraction = 0.12;
  static const double detachedInflateFraction = 0.025;
  static const double detachedCornerRadiusFraction = 0.08;
}
