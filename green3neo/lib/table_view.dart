import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';
import 'reflectable.dart';

part 'table_view.freezed.dart';

@Freezed()
sealed class SupportedType with _$SupportedType {
  const SupportedType._();

  const factory SupportedType.int(int value) = IntVariant;
  const factory SupportedType.string(String value) = StringVariant;
  const factory SupportedType.bool(bool value) = BoolVariant;
  const factory SupportedType.unsupported(dynamic value) = UnsupportedVariant;

  Widget generateCellPopup<DataObject extends Object,
          CellType extends SupportedType>(DataObject object,
      CellType initialValue, void Function(CellType) setter) {
    return initialValue.when(
      int: (value) =>
          generateIntWidget(object, value, setter as void Function(IntVariant)),
      string: (value) => generateStringWidget(
          object, value, setter as void Function(StringVariant)),
      bool: (value) => generateBoolWidget(
          object, value, setter as void Function(BoolVariant)),
      unsupported: (value) => generateUnsupportedWidget(
          object, value, setter as void Function(UnsupportedVariant)),
    );
  }
}

Widget generateIntWidget<DataObject extends Object>(
    DataObject object, int initialValue, void Function(IntVariant) setter) {
  onFieldSubmitted(newCellValue) {
    // TODO Implement
  }

  return TextFormField(
    keyboardType:
        const TextInputType.numberWithOptions(decimal: false, signed: false),
    initialValue: initialValue.toString(),
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onFieldSubmitted: onFieldSubmitted,
  );
}

Widget generateStringWidget<DataObject extends Object>(DataObject object,
    String initialValue, void Function(StringVariant) setter) {
  onFieldSubmitted(newCellValue) {
    // TODO Implement
  }

  return TextFormField(
    initialValue: initialValue,
    onFieldSubmitted: onFieldSubmitted,
  );
}

Widget generateBoolWidget<DataObject extends Object>(
    DataObject object, bool initialValue, void Function(BoolVariant) setter) {
  return Checkbox(
    value: initialValue,
    onChanged: (bool? newCellValue) {
      print("Change to $newCellValue");
      setter(BoolVariant(newCellValue!));
    },
  );
}

Widget generateUnsupportedWidget<DataObject extends Object>(DataObject object,
    dynamic initialValue, void Function(UnsupportedVariant) setter) {
  return Text(initialValue.toString());
}

typedef CellSetter = void Function(SupportedType?);
typedef CellPopupGenerator<DataObject, CellType extends SupportedType?> = Widget
    Function(DataObject, CellType, CellSetter);
typedef DataCellGenerator<DataObject> = DataCell Function(DataObject);

class TableView<DataObject extends Object> extends StatelessWidget {
  const TableView({super.key});

  DataCellGenerator<DataObject> _wrapIntoCellGenerator(
      BuildContext context,
      CellPopupGenerator<DataObject, SupportedType?> popupGenerator,
      DataColumnInfo<DataObject, SupportedType> info) {
    return (DataObject object) {
      SupportedType? currentValue = info.getter(object);

      return DataCell(
        Text((currentValue == null) ? "null" : currentValue.value.toString()),
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
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter setState) {
                          return popupGenerator(
                              object,
                              currentValue,
                              (newCellValue) => setState(
                                    () => currentValue = newCellValue,
                                  ));
                        },
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Save"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
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

  CellPopupGenerator<DataObject, SupportedType?> _wrapIntoNullPopupGenerator(
      CellPopupGenerator<DataObject, SupportedType> popupGenerator,
      DataColumnInfo<DataObject, SupportedType> info) {
    onChanged(isChecked) {
      // TODO Implement
    }

    return (DataObject object, SupportedType? currentValue, CellSetter setter) {
      final bool isNull = (info.getter(object) == null);

      return Row(
        children: [
          Checkbox(value: isNull, onChanged: onChanged),
          Expanded(
            child: (currentValue == null)
                ? const Text("Value is currently null")
                : popupGenerator(object, currentValue, setter),
          ),
        ],
      );
    };
  }

  DataCellGenerator<DataObject> _createCellGenerator(
      BuildContext context, DataColumnInfo<DataObject, SupportedType> info) {
    final isNullableType = info.typeMirror.isNullable;

    CellPopupGenerator<DataObject, SupportedType?> nullablePopupGenerator;
    if (isNullableType) {
      nullablePopupGenerator = _wrapIntoNullPopupGenerator(
          info.supportedType.generateCellPopup, info);
    } else {
      nullablePopupGenerator =
          (DataObject object, SupportedType? initialValue, CellSetter setter) {
        // ignore: null_check_on_nullable_type_parameter
        return info.supportedType
            .generateCellPopup(object, initialValue!, setter);
      };
    }

    return _wrapIntoCellGenerator(context, nullablePopupGenerator, info);
  }

  List<DataCellGenerator<DataObject>> _createCellGenerators(
      BuildContext context,
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
