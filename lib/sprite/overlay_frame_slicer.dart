import 'dart:convert';

const List<String> defaultOverlayStates = <String>['idle', 'jumping'];

class OverlayFrameSlice {
  const OverlayFrameSlice({
    required this.state,
    required this.frame,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String state;
  final int frame;
  final int left;
  final int top;
  final int width;
  final int height;

  String get resourceName => 'overlay_${_resourcePart(state)}_$frame.png';

  Map<String, Object> toJson() => <String, Object>{
    'state': state,
    'frame': frame,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'resource': resourceName,
  };

  static String _resourcePart(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp('^_+|_+\$'), '');
}

List<OverlayFrameSlice> buildOverlaySlicePlan(
  Map<String, Object?> metadata, {
  List<String> states = defaultOverlayStates,
}) {
  final atlas = metadata['atlas'];
  final rows = metadata['rows'];
  if (atlas is! Map<String, Object?> || rows is! List<Object?>) {
    throw const FormatException('Missing atlas or rows metadata.');
  }
  final columns = atlas['columns'];
  final rowCount = atlas['rows'];
  final cellWidth = atlas['cell_width'];
  final cellHeight = atlas['cell_height'];
  final imageWidth = atlas['width'];
  final imageHeight = atlas['height'];
  if (columns is! int ||
      rowCount is! int ||
      cellWidth is! int ||
      cellHeight is! int ||
      imageWidth is! int ||
      imageHeight is! int ||
      columns * cellWidth != imageWidth ||
      rowCount * cellHeight != imageHeight) {
    throw const FormatException('Atlas dimensions do not match its grid.');
  }

  final rowsByState = <String, Map<String, Object?>>{};
  for (final value in rows) {
    if (value is Map<String, Object?> && value['state'] is String) {
      rowsByState[value['state']! as String] = value;
    }
  }
  final plan = <OverlayFrameSlice>[];
  for (final state in states) {
    final row = rowsByState[state];
    if (row == null || row['row'] is! int || row['frames'] is! int) {
      throw FormatException('Missing sequence metadata for $state.');
    }
    final rowIndex = row['row']! as int;
    final frames = row['frames']! as int;
    if (rowIndex < 0 ||
        rowIndex >= rowCount ||
        frames < 1 ||
        frames > columns) {
      throw FormatException('Invalid sequence metadata for $state.');
    }
    for (var frame = 0; frame < frames; frame++) {
      plan.add(
        OverlayFrameSlice(
          state: state,
          frame: frame,
          left: frame * cellWidth,
          top: rowIndex * cellHeight,
          width: cellWidth,
          height: cellHeight,
        ),
      );
    }
  }
  return List<OverlayFrameSlice>.unmodifiable(plan);
}

String encodeOverlaySliceManifest(List<OverlayFrameSlice> plan) =>
    '${const JsonEncoder.withIndent('  ').convert(<String, Object>{'frames': plan.map((frame) => frame.toJson()).toList(growable: false)})}\n';
