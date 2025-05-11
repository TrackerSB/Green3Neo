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
        home: TableViewUnsupportedCellPopup(
          initialValue: cellValue,
          isNullable: false,
          onCellValueSubmitted: (submittedValue) {},
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
}
