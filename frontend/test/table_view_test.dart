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

  testWidgets("Ignore saving already set value", (tester) async {
    final initialValue = createDefaultValue<StringVariant>();

    int numSubmitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableViewStringCellPopup(
            initialValue: initialValue,
            isNullable: true,
            onCellValueSubmitted: (submittedValue) {
              numSubmitted++;
            },
          ),
        ),
      ),
    );

    final popupFinder = find.byType(TableViewStringCellPopup);
    expect(popupFinder, findsOneWidget);

    final TableViewStringCellPopup popup = tester.widget(popupFinder);
    expect(popup.initialValue, initialValue);

    final TableViewStringCellPopupState popupState = tester.state(popupFinder);
    expect(popupState.widget, popup);
    expect(popupState.currentValue, initialValue);

    // Save the non-change
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();
    expect(popupState.currentValue, initialValue);

    // Verify popup closed
    expect(find.byType(TableViewStringCellPopup), findsNothing);

    // Verify no change was submitted
    expect(numSubmitted, 0);
  });

  testWidgets("Cancelling a change does not result in a change to commit",
      (tester) async {
    final initialValue = createDefaultValue<StringVariant>();

    int numSubmitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableViewStringCellPopup(
            initialValue: initialValue,
            isNullable: true,
            onCellValueSubmitted: (submittedValue) {
              numSubmitted++;
            },
          ),
        ),
      ),
    );

    final popupFinder = find.byType(TableViewStringCellPopup);
    expect(popupFinder, findsOneWidget);

    final TableViewStringCellPopup popup = tester.widget(popupFinder);
    expect(popup.initialValue, initialValue);

    final TableViewStringCellPopupState popupState = tester.state(popupFinder);
    expect(popupState.widget, popup);
    expect(popupState.currentValue, initialValue);

    // Change popup content
    final StringVariant newValue = StringVariant("New Value");
    assert(initialValue != newValue);
    popupState.setInternalValue(newValue);
    expect(popupState.currentValue, newValue);

    // Cancel the change
    await tester.tap(find.closeButton());
    await tester.pumpAndSettle();
    expect(popupState.currentValue, initialValue);

    // Verify popup closed
    expect(find.byType(TableViewStringCellPopup), findsNothing);

    // Verify no change was submitted
    expect(numSubmitted, 0);
  });
}
