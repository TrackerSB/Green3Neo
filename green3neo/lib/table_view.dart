import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';
import 'reflectable.dart';

part 'table_view.freezed.dart';

typedef CellValueHandler = void Function(SupportedType?);
typedef CellSubmitHandler = VoidCallback;
typedef CellPopupGenerator<CellType extends SupportedType?> = Widget Function(
    CellType, CellValueHandler, CellSubmitHandler);
typedef DataCellGenerator<DataObject> = DataCell Function(DataObject);

@Freezed()
sealed class SupportedType with _$SupportedType {
  const SupportedType._();

  const factory SupportedType.int(int value) = IntVariant;
  const factory SupportedType.string(String value) = StringVariant;
  const factory SupportedType.bool(bool value) = BoolVariant;
  const factory SupportedType.unsupported(dynamic value) = UnsupportedVariant;

  Widget generateCellPopup<DataObject extends Object,
          CellType extends SupportedType>(CellType initialValue,
      void Function(CellType) onValueChange, CellSubmitHandler onValueSubmit) {
    return initialValue.when(
      int: (value) => generateIntPopup(
          value, onValueChange as void Function(IntVariant), onValueSubmit),
      string: (value) => generateStringPopup(
          value, onValueChange as void Function(StringVariant), onValueSubmit),
      bool: (value) => generateBoolPopup(
          value, onValueChange as void Function(BoolVariant), onValueSubmit),
      unsupported: (value) => generateUnsupportedPopup(value,
          onValueChange as void Function(UnsupportedVariant), onValueSubmit),
    );
  }
}

Widget generateIntPopup<DataObject extends Object>(int initialValue,
    void Function(IntVariant) onValueChange, CellSubmitHandler onValueSubmit) {
  return TextFormField(
    keyboardType:
        const TextInputType.numberWithOptions(decimal: false, signed: false),
    initialValue: initialValue.toString(),
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (newValue) => onValueChange(IntVariant(int.parse(newValue))),
    onFieldSubmitted: (newValue) => onValueSubmit(),
  );
}

Widget generateStringPopup<DataObject extends Object>(
    String initialValue,
    void Function(StringVariant) onValueChange,
    CellSubmitHandler onValueSubmit) {
  return TextFormField(
    initialValue: initialValue,
    onChanged: (newValue) => onValueChange(StringVariant(newValue)),
    onFieldSubmitted: (newValue) => onValueSubmit(),
  );
}

Widget generateBoolPopup<DataObject extends Object>(bool initialValue,
    void Function(BoolVariant) onValueChange, CellSubmitHandler onValueSubmit) {
  bool currentValue = initialValue;

  return StatefulBuilder(
    builder: (BuildContext context, StateSetter setState) => Checkbox(
      value: currentValue,
      onChanged: (newValue) {
        onValueChange(BoolVariant(newValue == true));
        setState(() => currentValue = !currentValue);
      },
    ),
  );
}

Widget generateUnsupportedPopup<DataObject extends Object>(
    dynamic initialValue,
    void Function(UnsupportedVariant) onValueChange,
    CellSubmitHandler onValueSubmit) {
  return Text(initialValue.toString());
}

DataCellGenerator<DataObject> _wrapIntoCellGenerator<DataObject extends Object>(
    BuildContext context,
    CellPopupGenerator<SupportedType?> popupGenerator,
    DataColumnInfo<DataObject, SupportedType> info) {
  return (DataObject object) {
    SupportedType? initialCellValue = info.getter(object);
    SupportedType? currentCellValue = initialCellValue;
    // TODO Reflect data cell changes in data objects

    StateSetter setCellState = (setter) {
      // WARN Setter is executed without actually updating cell state
      setter();
    };

    onValueChange(newCellValue) {
      setCellState(() => currentCellValue = newCellValue);
    }

    onValueSubmit() {
      initialCellValue = currentCellValue;
      Navigator.pop(context);
    }

    return DataCell(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          setCellState = setState;

          dynamic cellValue = currentCellValue?.value;
          if (cellValue == null) {
            return const Text("null");
          }

          return Text(cellValue.toString());
        },
      ),
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
                    child: popupGenerator(
                        currentCellValue, onValueChange, onValueSubmit),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        // FIXME Save button does not actually save
                        onPressed: onValueSubmit,
                        child: const Text("Save"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onValueChange(initialCellValue);
                          onValueSubmit();
                        },
                        child: const Text("Cancel"),
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

CellPopupGenerator<SupportedType?>
    _wrapIntoNullPopupGenerator<DataObject extends Object>(
        CellPopupGenerator<SupportedType> popupGenerator,
        DataColumnInfo<DataObject, SupportedType> info) {
  return (SupportedType? currentValue, CellValueHandler onValueChange,
      CellSubmitHandler onValueSubmit) {
    StateSetter setCellState = (setter) {
      // WARN Setter is executed without actually updating cell state
      setter();
    };

    onChanged(isChecked) {
      setCellState(() {
        if (isChecked) {
          currentValue = info.supportedType.when(
            int: (value) => const SupportedType.int(0),
            string: (value) => const SupportedType.string(""),
            bool: (value) => const SupportedType.bool(false),
            unsupported: SupportedType.unsupported,
          );
        } else {
          currentValue = null;
        }
        onValueChange(currentValue);
      });
    }

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        setCellState = setState;

        return Row(
          children: [
            Checkbox(
              value: currentValue != null,
              onChanged: onChanged,
            ),
            Expanded(
                child: (currentValue == null)
                    ? const Text("Value is currently null")
                    : popupGenerator(
                        currentValue!, onValueChange, onValueSubmit)),
          ],
        );
      },
    );
  };
}

DataCellGenerator<DataObject> _createCellGenerator<DataObject extends Object>(
    BuildContext context, DataColumnInfo<DataObject, SupportedType> info) {
  final isNullableType = info.typeMirror.isNullable;

  popupGenerator(SupportedType? initialValue, CellValueHandler onValueChange,
      CellSubmitHandler onValueSubmit) {
    // ignore: null_check_on_nullable_type_parameter
    return info.supportedType
        .generateCellPopup(initialValue!, onValueChange, onValueSubmit);
  }

  CellPopupGenerator<SupportedType?> nullablePopupGenerator;
  if (isNullableType) {
    nullablePopupGenerator = _wrapIntoNullPopupGenerator(popupGenerator, info);
  } else {
    nullablePopupGenerator = popupGenerator;
  }

  return _wrapIntoCellGenerator(context, nullablePopupGenerator, info);
}

List<DataCellGenerator<DataObject>>
    _createCellGenerators<DataObject extends Object>(BuildContext context,
        Map<String, DataColumnInfo<DataObject, SupportedType>> columnInfo) {
  return columnInfo
      .map(
        (name, info) {
          DataCellGenerator<DataObject> generator = () {
            return info.supportedType.when(
              int: (value) => _createCellGenerator(context, info),
              bool: (value) => _createCellGenerator(context, info),
              string: (value) => _createCellGenerator(context, info),
              unsupported: (value) => _createCellGenerator(context, info),
            );
          }();
          return MapEntry(name, generator);
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
            label: Text(name),
          ),
        );
      })
      .values
      .toList();
}

class TableView<DataObject extends Object> extends StatelessWidget {
  const TableView({super.key});

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
            return MapEntry(name, info.typeMirror);
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
  final List<DataCellGenerator<DataObject>> _cellGenerators;

  TableViewSource(this._content, this._cellGenerators);

  @override
  DataRow? getRow(int index) {
    final object = _content[index];
    final List<DataCell> cells = [];

    for (var generator in _cellGenerators) {
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

class DataColumnInfo<DataObject extends Object,
    CellType extends SupportedType> {
  final SupportedType supportedType;
  final TypeMirror typeMirror;
  final CellType? Function(DataObject) getter;
  final void Function(DataObject, CellType?)? setter;

  DataColumnInfo(
    this.supportedType,
    this.typeMirror,
    this.getter,
    this.setter,
  );
}

class TableViewContent<DataObject extends Object> extends ChangeNotifier {
  final Map<String, DataColumnInfo<DataObject, SupportedType>> _columnInfo = {};
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
          dynamic constructor;
          SupportedType supportedType;
          switch (declarationMirror.type.reflectedType) {
            case String:
              constructor = SupportedType.string;
              supportedType = const StringVariant("");
              break;
            case bool:
              constructor = SupportedType.bool;
              supportedType = const BoolVariant(false);
              break;
            case int:
              constructor = SupportedType.int;
              supportedType = const IntVariant(0);
              break;
            default:
              constructor = SupportedType.unsupported;
              supportedType = const UnsupportedVariant(null);
              break;
          }
          _columnInfo[name] = DataColumnInfo<DataObject, SupportedType>(
            supportedType,
            declarationMirror.type,
            (DataObject object) {
              var value = reflectableMarker
                  .reflect(object)
                  .invokeGetter(declarationMirror.simpleName);
              if (value == null) {
                return null;
              }

              var supportedTypeValue = constructor(value);
              return supportedTypeValue;
            },
            declarationMirror.isFinal
                ? null
                : (DataObject object, Object? newValue) {
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
