import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pair/pair.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';
import 'reflectable.dart';

class TableView<DataObject extends Object> extends StatelessWidget {
  const TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final tableViewState = context.watch<TableViewState<DataObject>>();

    if (tableViewState._columns.isEmpty) {
      return const Text("No data");
    }

    return PaginatedDataTable(
      columns: tableViewState._columns.map((e) => e.key).toList(),
      source: TableViewSource(
        context,
        tableViewState._content,
        tableViewState._columns.map((e) => e.value).toList(),
      ),
    );
  }
}

class TableViewSource<DataObject extends Object> extends DataTableSource {
  final BuildContext _context;
  final List<DataObject> _content;
  final List<dynamic Function(DataObject)> _columnRetrievers;

  TableViewSource(this._context, this._content, this._columnRetrievers);

  DataCell _generateEditPopup(String initialValue, Widget content) {
    return DataCell(
      Text(initialValue),
      onTap: () {
        showGeneralDialog(
          context: _context,
          pageBuilder: (context, animation, secondaryAnimation) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: content,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(_context),
                        child: Text("Save"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(_context),
                        child: Text("Cancel"),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  DataCell _generateStringDataCell(String initialValue) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    return _generateEditPopup(
      initialValue,
      TextFormField(
        initialValue: initialValue,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }

  DataCell _generateIntDataCell(int initialValue) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    return _generateEditPopup(
        initialValue.toString(),
        TextFormField(
          keyboardType: const TextInputType.numberWithOptions(
              decimal: false, signed: false),
          initialValue: initialValue.toString(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onFieldSubmitted: onFieldSubmitted,
        ));
  }

  DataCell _generateFixedStringDataCell(String value) {
    return DataCell(Text(value));
  }

  DataCell _generateDataCell(
      dynamic Function(DataObject) retriever, DataObject object) {
    final dynamic initialValue = retriever(object);

    switch (initialValue.runtimeType) {
      case String:
        return _generateStringDataCell(initialValue as String);
      case int:
        return _generateIntDataCell(initialValue as int);
      default:
        return _generateFixedStringDataCell(initialValue.toString());
    }
  }

  @override
  DataRow? getRow(int index) {
    final object = _content[index];
    final List<DataCell> cells = [];

    for (var retriever in _columnRetrievers) {
      cells.add(_generateDataCell(retriever, object));
    }

    return DataRow(cells: cells);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _content.length;

  @override
  int get selectedRowCount => 0;
}

class TableViewState<DataObject extends Object> extends ChangeNotifier {
  final List<Pair<DataColumn, dynamic Function(DataObject)>> _columns = [];
  final List<DataObject> _content = [];
  final Map<DataObject, DataObject> _dataChanges = {};

  TableViewState() {
    if (!reflectableMarker.canReflectType(DataObject)) {
      print(
          "Cannot generate table view for type '$DataObject' since it's not reflectable.");
      return;
    }

    var classMirror = reflectableMarker.reflectType(DataObject) as ClassMirror;
    Map<String, DeclarationMirror> classDeclarations = classMirror.declarations;

    classDeclarations.forEach((name, declarationMirror) {
      if (declarationMirror is VariableMirror) {
        VariableMirror variableMirror = declarationMirror;
        _columns.add(
          Pair(
            DataColumn(label: Text(name)),
            (member) {
              return reflectableMarker
                  .reflect(member)
                  .invokeGetter(variableMirror.simpleName);
            },
          ),
        );
      }
    });
  }

  void setData(List<DataObject> data) {
    _content.clear();
    _content.addAll(data);
    notifyListeners();
  }

  Map<DataObject, DataObject> getChanges() {
    return _dataChanges;
  }
}
