/// Every rig magic number lives here — layer-composition geometry constants
/// tuned by eye (motion parameters live in RigDriverParameters).
library;

/// Layer-composition geometry, all fractions of the head/part box size.
///
/// Every mask and cutout edge is HARD — MaskFilter feathering is banned here
/// because layer baking (Picture.toImage) runs on the device's rasterizer,
/// and Impeller does not apply MaskFilter.blur with BlendMode.clear/dstIn the
/// way the software Skia used by tests does (the head cutout silently no-ops
/// and the moving head ghosts over its baked-in twin). Seamlessness comes
/// from geometry instead: every part mask must strictly contain its body
/// cutout, which the reconstruction test enforces pixel-by-pixel.
abstract final class RigComposeTuning {
  /// Horizontal overshoot of the head cutout beyond the head box.
  static const double headExpansionFraction = 0.05;

  /// Horizontal overshoot of the head-layer mask; must exceed
  /// [headExpansionFraction] so the head always covers its cutout.
  static const double headMaskHorizontalExpansion = 0.08;

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
  static const double partHeadTopExpansion = 0.14;
  static const double partBottomExpansion = 0.04;
  static const double partCornerRadiusFraction = 0.05;
  static const double detachedInflateFraction = 0.025;
  static const double detachedCornerRadiusFraction = 0.08;
}
