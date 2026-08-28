import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettodo/ui/theme/pet_colors.dart';
import 'package:pettodo/ui/widgets/pixel_components.dart';

void main() {
  testWidgets('compact outline button keeps its label readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PxButton(
            compact: true,
            style: PxButtonStyle.outline,
            onPressed: () {},
            label: const Text('Remove'),
          ),
        ),
      ),
    );

    final label = tester.widget<RichText>(
      find.descendant(
        of: find.byType(PxButton),
        matching: find.byType(RichText),
      ),
    );
    expect(label.text.toPlainText(), 'Remove');
    expect(label.text.style?.color, PetColors.bodyStrong);
  });
}
