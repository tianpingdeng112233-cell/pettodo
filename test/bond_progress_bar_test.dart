import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/ui/widgets/bond_progress_bar.dart';

void main() {
  testWidgets('bond progress semantics use a qualitative description', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BondProgressBar(value: 0.42))),
    );

    final semantics = tester.getSemantics(find.byType(BondProgressBar));
    expect(semantics.label, 'Bond progress');
    expect(semantics.value, isEmpty);
    semanticsHandle.dispose();
  });
}
