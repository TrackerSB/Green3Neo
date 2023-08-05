import 'package:flutter/material.dart';
import 'ffi.dart';

class TableView extends StatefulWidget {
  const TableView({super.key});

  @override
  State<StatefulWidget> createState() => TableViewState();
}

class TableViewState extends State<TableView> {
  var columnNames = ["spalte1", "spalte2"];

  @override
  Widget build(BuildContext context) {
    List<DataColumn> columns = [];
    for (String columnName in columnNames) {
      columns.add(DataColumn(label: Text(columnName)));
    }
    const List<DataRow> rows = [];

    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final foo = await backendApi.getMe();
            setState(() {
              columnNames.add(foo.toString());
            });
          },
          child: const Text("Add column"),
        ),
        DataTable(columns: columns, rows: rows),
      ],
    );
  }
}
