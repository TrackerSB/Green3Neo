import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      columns: tableViewState._columns.keys.toList(),
      source: TableViewSource(
        context,
        tableViewState._content,
        tableViewState._columns.values.toList(),
      ),
      rowsPerPage: 20,
      showFirstLastButtons: true,
      showCheckboxColumn: true, // FIXME Has it any effect?
    );
  }
}

class TableViewSource<DataObject extends Object> extends DataTableSource {
  final BuildContext _context;
  final List<DataObject> _content;
  final List<DataColumnInfo<DataObject>> _columnInfos;

  TableViewSource(this._context, this._content, this._columnInfos);

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

  DataCell _generateStringDataCell(String? initialValue, bool isNullableType) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    if (isNullableType) {
      return _generateFixedStringDataCell(initialValue.toString());
    }

    return _generateEditPopup(
      initialValue.toString(),
      TextFormField(
        initialValue: initialValue,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }

  DataCell _generateIntDataCell(int? initialValue, bool isNullableType) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    if (isNullableType) {
      return _generateFixedStringDataCell(initialValue.toString());
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

  DataCell _generateBoolDataCell(bool? initialValue, bool isNullableType) {
    onChanged(newCellValue) {
      // TODO Implement
    }

    if (isNullableType) {
      return _generateFixedStringDataCell(initialValue.toString());
    }

    return _generateEditPopup(
      initialValue.toString(),
      Checkbox(
        value: initialValue,
        onChanged: onChanged,
      ),
    );
  }

  DataCell _generateFixedStringDataCell(String? value) {
    return DataCell(Text(value.toString()));
  }

  DataCell _generateDataCell(
      DataColumnInfo<DataObject> info, DataObject object) {
    final dynamic initialValue = info.getter(object);

    final isNullableType = info.type.isNullable;
    assert(isNullableType || (initialValue != null));

    switch (info.type.reflectedType) {
      case String:
        return _generateStringDataCell(initialValue as String?, isNullableType);
      case int:
        return _generateIntDataCell(initialValue as int?, isNullableType);
      case bool:
        return _generateBoolDataCell(initialValue as bool?, isNullableType);
      default:
        return _generateFixedStringDataCell(initialValue.toString());
    }
  }

  @override
  DataRow? getRow(int index) {
    final object = _content[index];
    final List<DataCell> cells = [];

    for (var info in _columnInfos) {
      cells.add(_generateDataCell(info, object));
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

class DataColumnInfo<DataObject extends Object> {
  final TypeMirror type;
  final dynamic Function(DataObject) getter;

  DataColumnInfo(this.type, this.getter);
}

class TableViewState<DataObject extends Object> extends ChangeNotifier {
  final Map<DataColumn, DataColumnInfo<DataObject>> _columns = {};
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
        _columns[DataColumn(label: Text(name))] = DataColumnInfo<DataObject>(
          declarationMirror.type,
          (member) {
            return reflectableMarker
                .reflect(member)
                .invokeGetter(declarationMirror.simpleName);
          },
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
