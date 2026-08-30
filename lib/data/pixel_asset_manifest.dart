/// Shared descriptor and parsing for pixel-art asset manifests
/// (room furniture and food share one JSON entry shape).
class PixelAsset {
  const PixelAsset({
    required this.id,
    required this.assetPath,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.placeholderHex,
  });

  final String id;
  final String assetPath;
  final int pixelWidth;
  final int pixelHeight;
  final String placeholderHex;
}

Map<String, PixelAsset> parsePixelAssetSection(
  Map<String, Object?> json,
  String key,
) {
  final parsed = <String, PixelAsset>{};
  for (final raw in json[key]! as List<Object?>) {
    final item = raw! as Map<String, Object?>;
    final asset = PixelAsset(
      id: item['id']! as String,
      assetPath: item['asset']! as String,
      pixelWidth: item['pixel_width']! as int,
      pixelHeight: item['pixel_height']! as int,
      placeholderHex: item['placeholder']! as String,
    );
    parsed[asset.id] = asset;
  }
  return Map<String, PixelAsset>.unmodifiable(parsed);
}
