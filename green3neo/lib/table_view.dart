import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:green3neo/data_table_page.dart';
import 'package:provider/provider.dart';
import 'ffi.dart';

class TableView<DataObject> extends StatelessWidget {
  const TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final tableViewState = context.watch<TableViewState<DataObject>>();

    if (tableViewState._columns.isEmpty) {
      return const Text("No data");
    }

    return DataTable(
      columns: tableViewState._columns,
      rows: tableViewState._rows,
    );
  }
}

class TableViewState<DataObject> extends ChangeNotifier {
  final List<DataColumn> _columns = [];
  final List<dynamic Function(DataObject)> _columnRetrievers = [];
  final List<DataRow> _rows = [];
  final Map<DataObject, DataObject> _dataChanges = {};

  TableViewState(Future<MemberConnection> connection) {
    connection.then((c) {
      c.getColumnNames().then((columnNames) {
        for (final columnName in columnNames) {
          _columns.add(DataColumn(label: Text(columnName)));
          _columnRetrievers.add((member) async {
            return await c.getValueOf(
                member: member as Member, columnName: columnName);
          });
        }
      });
    });
  }

  TextFormField _generateStringDataCell(String initialValue) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    return TextFormField(
      initialValue: initialValue,
      onFieldSubmitted: onFieldSubmitted,
    );
  }

  TextFormField _generateIntDataCell(int initialValue) {
    return TextFormField(
      keyboardType:
          TextInputType.numberWithOptions(decimal: false, signed: false),
      initialValue: initialValue.toString(),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  Text _generateFixedStringDataCell(String value) {
    return Text(value);
  }

  Future<DataCell> _generateDataCell(
      dynamic Function(DataObject) retriever, DataObject object) async {
    final dynamic initialValue = await retriever(object);

    Widget cellContent;
    switch (initialValue.runtimeType) {
      case String:
        cellContent = _generateStringDataCell(initialValue as String);
        break;
      case int:
        cellContent = _generateIntDataCell(initialValue as int);
        break;
      default:
        cellContent = _generateFixedStringDataCell(initialValue.toString());
        break;
    }

    return DataCell(cellContent);
  }

  void setData(List<DataObject> data) async {
    _rows.clear();

    if (_columns.isNotEmpty) {
      for (final object in data) {
        final List<DataCell> cells = [];

        for (final retriever in _columnRetrievers) {
          cells.add(await _generateDataCell(retriever, object));
        }

        _rows.add(DataRow(cells: cells));
      }
    }

    notifyListeners();
  }

  Map<DataObject, DataObject> getChanges() {
    return _dataChanges;
  }
}
