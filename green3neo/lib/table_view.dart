import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TableView extends StatelessWidget {
  const TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final tableViewState = context.watch<TableViewState>();

    if (tableViewState._columns.isEmpty) {
      return const Text("No data");
    }

    return DataTable(
      columns: tableViewState._columns,
      rows: tableViewState._rows,
    );
  }
}

class TableViewState extends ChangeNotifier {
  final List<DataColumn> _columns = [];
  final List<DataRow> _rows = [];
  final Map<int, Map<int, String>> _cellChanges = {};

  void setData(List<List<String>> data) {
    _columns.clear();
    _rows.clear();

    /* FIXME It is assumed every row has at least the number of entries the
     * first row has.
     */

    if (data.isNotEmpty) {
      for (final String columnName in data.first) {
        _columns.add(DataColumn(label: Text(columnName)));
      }

      for (int rowIndex = 1; rowIndex < data.length; rowIndex++) {
        final List<String> rowData = data.elementAt(rowIndex);
        final List<DataCell> cells = [];
        for (int columnIndex = 0;
            columnIndex < _columns.length;
            columnIndex++) {
          final String cellData = rowData.elementAt(columnIndex);
          cells.add(DataCell(
            TextFormField(
              initialValue: cellData,
              decoration: InputDecoration(
                  labelText: data.first.elementAtOrNull(columnIndex)),
              onFieldSubmitted: (newCellValue) {
                _cellChanges.update(
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
                for (final columnChanges in _cellChanges.entries) {
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
        _rows.add(DataRow(cells: cells));
      }
    }

    notifyListeners();
  }
}
