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

  void setData(List<List<String>> data) {
    columns.clear();
    rows.clear();

    if (data.isNotEmpty) {
      for (String columnName in data.first) {
        columns.add(DataColumn(label: Text(columnName)));
      }

      for (List<String> rowData in data.skip(1)) {
        final List<DataCell> cells = [];
        for (String cellData in rowData) {
          cells.add(DataCell(Text(cellData)));
        }
        rows.add(DataRow(cells: cells));
      }
    }

    notifyListeners();
  }
}
