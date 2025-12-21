import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/l10n/app_localizations.dart';

void main() {
  testWidgets("Verify common properties and behavior of table view popups",
      (tester) async {
    // FIXME Verify all SupportedTypes
    final cellValue = createDefaultValue<StringVariant>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TableViewStringCellPopup(
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets("Accept changed value on save", (tester) async {
    final initialValue = createDefaultValue<StringVariant>();

    int numSubmitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    // Change popup content
    final StringVariant newValue = StringVariant("New Value");
    assert(initialValue != newValue);
    popup.currentValue.value = newValue;
    expect(popup.currentValue.value, newValue);

    // Save the change
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    // Verify popup closed
    expect(find.byType(TableViewStringCellPopup), findsNothing);

    // Verify change was submitted
    expect(numSubmitted, 1);
  });

  testWidgets("Ignore saving already set value", (tester) async {
    final initialValue = createDefaultValue<StringVariant>();

    int numSubmitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    expect(popup.currentValue.value, initialValue);

    // Save the non-change
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();
    expect(popup.currentValue.value, initialValue);

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    expect(popup.currentValue.value, initialValue);

    // Change popup content
    final StringVariant newValue = StringVariant("New Value");
    assert(initialValue != newValue);
    popup.currentValue.value = newValue;
    expect(popup.currentValue.value, newValue);

    // Cancel the change
    await tester.tap(find.closeButton());
    await tester.pumpAndSettle();
    expect(popup.currentValue.value, initialValue);

    // Verify popup closed
    expect(find.byType(TableViewStringCellPopup), findsNothing);

    // Verify no change was submitted
    expect(numSubmitted, 0);
  });
}
