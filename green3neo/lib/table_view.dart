import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableView extends StatelessWidget {
  const TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final tableViewState = context.watch<TableViewState>();

    if (tableViewState.columns.isEmpty) {
      return const Text("No data");
    }

    return DataTable(
      columns: tableViewState.columns,
      rows: tableViewState.rows,
    );
  }
}

class TableViewState extends ChangeNotifier {
  final List<DataColumn> columns = [];
  final List<DataRow> rows = [];
  final Map<int, Map<int, String>> cellChanges = {};

  void setData(List<List<String>> data) {
    columns.clear();
    rows.clear();

    /* FIXME It is assumed every row has at least the number of entries the
     * first row has.
     */

    if (data.isNotEmpty) {
      for (final String columnName in data.first) {
        columns.add(DataColumn(label: Text(columnName)));
      }

      for (int rowIndex = 1; rowIndex < data.length; rowIndex++) {
        final List<String> rowData = data.elementAt(rowIndex);
        final List<DataCell> cells = [];
        for (int columnIndex = 0; columnIndex < columns.length; columnIndex++) {
          final String cellData = rowData.elementAt(columnIndex);
          cells.add(DataCell(
            TextFormField(
              initialValue: cellData,
              decoration: InputDecoration(
                  labelText: data.first.elementAtOrNull(columnIndex)),
              onFieldSubmitted: (newCellValue) {
                cellChanges.update(
                  rowIndex,
                  (columnChanges) {
                    columnChanges.update(
                      columnIndex,
                      (oldCellValue) => newCellValue,
                      ifAbsent: () => newCellValue,
                    );
                    return columnChanges;
                  },
                  ifAbsent: () =>
                      Map.fromIterables([columnIndex], [newCellValue]),
                );

                print("Cell changes:");
                for (final columnChanges in cellChanges.entries) {
                  print("Row ${columnChanges.key.toString()}");
                  for (final newCellValue in columnChanges.value.entries) {
                    print(
                        "Column ${newCellValue.key} --> ${newCellValue.value}");
                  }
                }
              },
            ),
          ));
        }
        rows.add(DataRow(cells: cells));
      }
    }

    notifyListeners();
  }
}
