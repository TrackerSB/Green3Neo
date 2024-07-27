import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';
import 'reflectable.dart';

class TableView<DataObject extends Object> extends StatelessWidget {
  const TableView({super.key});

  DataCell Function(DataObject) _wrapIntoCellGenerator(
      BuildContext context,
      Widget Function(DataObject) widgetGenerator,
      DataColumnInfo<DataObject> info) {
    return (object) {
      final dynamic initialValue = info.getter(object);
      return DataCell(
        Text(initialValue.toString()),
        onTap: () {
          showGeneralDialog(
            context: context,
            pageBuilder: (context, animation, secondaryAnimation) {
              return Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: widgetGenerator(object),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Save"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
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
    };
  }

  Widget Function(DataObject) _wrapIntoNullWidgetGenerator(
      Widget Function(DataObject) cellGenerator,
      DataColumnInfo<DataObject> info) {
    onChanged(isChecked) {
      // TODO Implement
    }

    return (object) {
      final dynamic isNull = (info.getter(object) == null);
      return Row(
        children: [
          Checkbox(value: isNull, onChanged: onChanged),
          Expanded(
            child: cellGenerator(object),
          ),
        ],
      );
    };
  }

  Widget Function(DataObject) _createStringWidgetGenerator(
      DataColumnInfo<DataObject> info) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    return (object) {
      final dynamic currentValue = info.getter(object);

      return TextFormField(
        initialValue: currentValue,
        onFieldSubmitted: onFieldSubmitted,
      );
    };
  }

  Widget Function(DataObject) _createIntWidgetGenerator(
      DataColumnInfo<DataObject> info) {
    onFieldSubmitted(newCellValue) {
      // TODO Implement
    }

    return (object) {
      final dynamic currentValue = info.getter(object);

      return TextFormField(
        keyboardType: const TextInputType.numberWithOptions(
            decimal: false, signed: false),
        initialValue: currentValue.toString(),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onFieldSubmitted: onFieldSubmitted,
      );
    };
  }

  Widget Function(DataObject) _createBoolWidgetGenerator(
      DataColumnInfo<DataObject> info) {
    onChanged(newCellValue) {
      // TODO Implement
    }

    return (object) {
      final dynamic currentValue = info.getter(object);

      return Checkbox(
        value: currentValue,
        onChanged: onChanged,
      );
    };
  }

  Widget Function(DataObject) _createFixedStringWidgetGenerator(
      DataColumnInfo<DataObject> info) {
    return (object) {
      final dynamic initialValue = info.getter(object);

      return Text(initialValue.toString());
    };
  }

  DataCell Function(DataObject) _createCellGenerator(
      BuildContext context, DataColumnInfo<DataObject> info) {
    final isNullableType = info.type.isNullable;

    Widget Function(DataObject) widgetGenerator = (() {
      switch (info.type.reflectedType) {
        case String:
          return _createStringWidgetGenerator(info);
        case int:
          return _createIntWidgetGenerator(info);
        case bool:
          return _createBoolWidgetGenerator(info);
        default:
          return _createFixedStringWidgetGenerator(info);
      }
    })();

    if (isNullableType) {
      widgetGenerator = _wrapIntoNullWidgetGenerator(widgetGenerator, info);
    }

    return _wrapIntoCellGenerator(context, widgetGenerator, info);
  }

  List<DataCell Function(DataObject)> _createCellGenerators(
      BuildContext context,
      Map<String, DataColumnInfo<DataObject>> columnInfo) {
    return columnInfo
        .map(
          (name, info) {
            return MapEntry(
              name,
              _createCellGenerator(context, info),
            );
          },
        )
        .values
        .toList();
  }

  List<DataColumn> _createColumns(Map<String, TypeMirror> columnInfo) {
    return columnInfo
        .map<String, DataColumn>((name, type) {
          return MapEntry(
            name,
            DataColumn(
              label: Text(type.simpleName),
            ),
          );
        })
        .values
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tableViewContent = context.watch<TableViewContent<DataObject>>();

    if (tableViewContent._columnInfo.isEmpty) {
      return const Text("No data");
    }

    return PaginatedDataTable(
      columns: _createColumns(
        tableViewContent._columnInfo.map(
          (name, info) {
            return MapEntry(name, info.type);
          },
        ),
      ),
      source: TableViewSource(
        // FIXME Should this be a copy avoiding direct access?
        tableViewContent._content,
        _createCellGenerators(context, tableViewContent._columnInfo),
      ),
      rowsPerPage: 20,
      showFirstLastButtons: true,
      showCheckboxColumn: true, // FIXME Has it any effect?
    );
  }
}

class TableViewSource<DataObject extends Object> extends DataTableSource {
  final List<DataObject> _content;
  final List<DataCell Function(DataObject)> _cellGenerator;

  TableViewSource(this._content, this._cellGenerator);

  @override
  DataRow? getRow(int index) {
    final object = _content[index];
    final List<DataCell> cells = [];

    for (var generator in _cellGenerator) {
      cells.add(generator(object));
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
  final void Function(DataObject, dynamic) setter;

  DataColumnInfo(
    this.type,
    this.getter,
    this.setter,
  );
}

class TableViewContent<DataObject extends Object> extends ChangeNotifier {
  final Map<String, DataColumnInfo<DataObject>> _columnInfo = {};
  final List<DataObject> _content = [];
  final Map<DataObject, DataObject> _dataChanges = {};

  TableViewContent() {
    if (!reflectableMarker.canReflectType(DataObject)) {
      print(
          "Cannot generate table view for type '$DataObject' since it's not reflectable.");
      return;
    }

    var classMirror = reflectableMarker.reflectType(DataObject) as ClassMirror;
    Map<String, DeclarationMirror> classDeclarations = classMirror.declarations;

    classDeclarations.forEach(
      (name, declarationMirror) {
        if (declarationMirror is VariableMirror) {
          _columnInfo[name] = DataColumnInfo(
            declarationMirror.type,
            (object) {
              return reflectableMarker
                  .reflect(object)
                  .invokeGetter(declarationMirror.simpleName);
            },
            (object, newValue) {
              // FIXME Is the setter result required for anything?
              final setterResult = reflectableMarker
                  .reflect(object)
                  .invokeSetter(declarationMirror.simpleName, newValue);
            },
          );
        }
      },
    );
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
