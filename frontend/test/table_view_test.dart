import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:green3neo/table_view.dart';

void main() {
  testWidgets("Verify common properties and behavior of table view popups",
      (tester) async {
    // FIXME Verify all SupportedTypes
    final cellValue = createDefaultValue<UnsupportedVariant>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableViewUnsupportedCellPopup(
            initialValue: cellValue,
            isNullable: false,
            onCellValueSubmitted: (submittedValue) {},
          ),
        ),
      ),
    );

    // FIXME Verify changing text
    // FIXME Verify nullable property
    // FIXME Verify onCellValueSubmitted property

    expect(find.text(cellValue.value.toString()), findsOneWidget);
    expect(find.closeButton(), findsOneWidget);
    expect(find.text("Save"), findsOneWidget);
  });

  testWidgets("Verify behavior on (un-)setting value to null on nullable field",
      (tester) async {
    // FIXME Verify all SupportedTypes
    final initialValue = createDefaultValue<UnsupportedVariant>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableViewUnsupportedCellPopup(
            initialValue: initialValue,
            isNullable: true,
            onCellValueSubmitted: (submittedValue) {},
          ),
        ),
      ),
    );

    final popupFinder = find.byType(TableViewUnsupportedCellPopup);
    expect(popupFinder, findsOneWidget);

    verifyCellValue(UnsupportedVariant? expectedValue) {
      final TableViewUnsupportedCellPopup popup = tester.widget(popupFinder);
      expect(popup.initialValue, expectedValue);
      // FIXME Verify editability
    }

    final nullableCheckBoxFinder = find.byType(Checkbox);
    expect(nullableCheckBoxFinder, findsOneWidget);

    verifyCheckboxState(bool isChecked) {
      final Checkbox checkBox = tester.widget(nullableCheckBoxFinder);
      expect(checkBox.value, isChecked);
      expect(checkBox.tristate, isFalse);
      // FIXME Verify editability
    }

    verifyCellValue(initialValue);
    verifyCheckboxState(true);

    // Disable checkbox
    await tester.tap(nullableCheckBoxFinder);
    await tester.pumpAndSettle();
    verifyCellValue(initialValue);
    verifyCheckboxState(false);

    // Re-enable checkbox
    await tester.tap(nullableCheckBoxFinder);
    await tester.pumpAndSettle();
    verifyCellValue(initialValue);
    verifyCheckboxState(true);
  });

  testWidgets("Set null to non-nullable widget", (tester) async {
    // FIXME Implement
  });
}
