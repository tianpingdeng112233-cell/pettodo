import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/ui/theme/stair_border.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 100, 60);

  test('large StairBorder path follows the 12 px two-step vertex sequence', () {
    const border = StairBorder.large();
    const expected = <Offset>[
      Offset(0, 12),
      Offset(4, 12),
      Offset(4, 4),
      Offset(12, 4),
      Offset(12, 0),
      Offset(88, 0),
      Offset(88, 4),
      Offset(96, 4),
      Offset(96, 12),
      Offset(100, 12),
      Offset(100, 48),
      Offset(96, 48),
      Offset(96, 56),
      Offset(88, 56),
      Offset(88, 60),
      Offset(12, 60),
      Offset(12, 56),
      Offset(4, 56),
      Offset(4, 48),
      Offset(0, 48),
    ];

    expect(_pathVertices(border.getOuterPath(rect), expected), expected);
  });

  test('small StairBorder path follows the 4 px one-step vertex sequence', () {
    const border = StairBorder.small();
    const expected = <Offset>[
      Offset(0, 4),
      Offset(4, 4),
      Offset(4, 0),
      Offset(96, 0),
      Offset(96, 4),
      Offset(100, 4),
      Offset(100, 56),
      Offset(96, 56),
      Offset(96, 60),
      Offset(4, 60),
      Offset(4, 56),
      Offset(0, 56),
    ];

    expect(_pathVertices(border.getOuterPath(rect), expected), expected);
  });
}

List<Offset> _pathVertices(Path path, List<Offset> expected) {
  final metric = path.computeMetrics().single;
  final result = <Offset>[];
  var distance = 0.0;
  for (var index = 0; index < expected.length; index++) {
    result.add(metric.getTangentForOffset(distance)!.position);
    final current = expected[index];
    final next = expected[(index + 1) % expected.length];
    distance += (next - current).distance;
  }
  return result;
}
