import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';
import 'reflectable.dart';

part 'table_view.freezed.dart';

typedef CellValueHandler<CellType extends SupportedType?> = void Function(
    CellType);
typedef CellSubmitHandler = VoidCallback;
typedef CellPopupGenerator<CellType extends SupportedType?> = Widget Function(
    CellType, CellValueHandler<CellType>, CellSubmitHandler);
typedef ObjectValueGetter<DataObject, CellType extends SupportedType?>
    = CellType? Function(DataObject);
typedef ObjectValueSetter<DataObject, CellType extends SupportedType?> = void
    Function(DataObject, CellType?);
typedef DataCellGenerator<DataObject> = DataCell Function(DataObject);

@Freezed()
sealed class SupportedType with _$SupportedType {
  const SupportedType._();

  const factory SupportedType.int(int value) = IntVariant;
  const factory SupportedType.string(String value) = StringVariant;
  const factory SupportedType.bool(bool value) = BoolVariant;
  const factory SupportedType.unsupported(dynamic value) = UnsupportedVariant;

  Widget generateCellPopup<CellType extends SupportedType>(
      CellType initialValue,
      void Function(CellType) onValueChange,
      CellSubmitHandler onValueSubmit) {
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

class DataColumnInfo<DataObject extends Object,
    CellType extends SupportedType> {
  final SupportedType supportedType;
  final TypeMirror typeMirror;
  final ObjectValueGetter<DataObject, CellType> objectGetter;
  final ObjectValueSetter<DataObject, CellType>? objectSetter;
  final DataCellGenerator<DataObject> cellGenerator;

  DataColumnInfo(
    this.supportedType,
    this.typeMirror,
    this.objectGetter,
    this.objectSetter,
    this.cellGenerator,
  );
}

Widget generateIntPopup(int initialValue,
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

Widget generateStringPopup(
    String initialValue,
    void Function(StringVariant) onValueChange,
    CellSubmitHandler onValueSubmit) {
  return TextFormField(
    initialValue: initialValue,
    onChanged: (newValue) => onValueChange(StringVariant(newValue)),
    onFieldSubmitted: (newValue) => onValueSubmit(),
  );
}

Widget generateBoolPopup(bool initialValue,
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

Widget generateUnsupportedPopup(
    dynamic initialValue,
    void Function(UnsupportedVariant) onValueChange,
    CellSubmitHandler onValueSubmit) {
  return Text(initialValue.toString());
}

DataCell _wrapIntoCellGenerator<CellType extends SupportedType?>(
    BuildContext context,
    CellPopupGenerator<CellType> popupGenerator,
    CellType initialCellValue,
    CellValueHandler<CellType> objectSetter) {
  CellType currentCellValue = initialCellValue;

  StateSetter setCellState = (cellSetter) {
    /* WARN Setter is executed without actually updating cell state if not set
     * by cell
     */
    cellSetter();
  };

  onValueChange(newCellValue) {
    setCellState(() => currentCellValue = newCellValue);
  }

  onValueSubmit() {
    initialCellValue = currentCellValue;
    objectSetter(currentCellValue);
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
}

CellPopupGenerator<CellType?>
    _wrapIntoNullPopupGenerator<CellType extends SupportedType>(
        CellPopupGenerator<CellType> popupGenerator, CellType supportedType) {
  return (CellType? currentValue, CellValueHandler<CellType?> onValueChange,
      CellSubmitHandler onValueSubmit) {
    StateSetter setCellState = (setter) {
      // WARN Setter is executed without actually updating cell state
      setter();
    };

    onChanged(isChecked) {
      setCellState(() {
        if (isChecked) {
          currentValue = supportedType.when(
            int: (value) => const SupportedType.int(0) as CellType,
            string: (value) => const SupportedType.string("") as CellType,
            bool: (value) => const SupportedType.bool(false) as CellType,
            unsupported: (value) =>
                const SupportedType.unsupported(null) as CellType,
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

DataCellGenerator<DataObject> _createCellGenerator<DataObject extends Object,
        CellType extends SupportedType>(
    BuildContext context,
    CellType supportedType,
    bool isNullableType,
    ObjectValueGetter<DataObject, CellType> objectGetter,
    ObjectValueSetter<DataObject, CellType> objectSetter) {
  popupGenerator(
      CellType initialValue,
      CellValueHandler<CellType> onValueChange,
      CellSubmitHandler onValueSubmit) {
    return supportedType.generateCellPopup<CellType>(
        initialValue, onValueChange, onValueSubmit);
  }

  CellPopupGenerator<CellType?> nullablePopupGenerator;
  if (isNullableType) {
    nullablePopupGenerator =
        _wrapIntoNullPopupGenerator(popupGenerator, supportedType);
  } else {
    nonNullPopupGenerator(
        CellType? initialValue,
        CellValueHandler<CellType?> onValueChange,
        CellSubmitHandler onValueSubmit) {
      assert(initialValue != null);
      return popupGenerator(initialValue!, onValueChange, onValueSubmit);
    }

    nullablePopupGenerator = nonNullPopupGenerator;
  }

  return (DataObject object) {
    void setCellValue(CellType? newCellValue) {
      objectSetter(object, newCellValue);
    }

    return _wrapIntoCellGenerator<CellType?>(
        context, nullablePopupGenerator, objectGetter(object), setCellValue);
  };
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
    final tableViewSource = context.watch<TableViewSource<DataObject>>();

    if (tableViewSource._columnInfo.isEmpty) {
      return const Text("No data");
    }

    return PaginatedDataTable(
      columns: _createColumns(
        tableViewSource._columnInfo.map(
          (name, info) {
            return MapEntry(name, info.typeMirror);
          },
        ),
      ),
      source: tableViewSource,
      rowsPerPage: 20,
      showFirstLastButtons: true,
      showCheckboxColumn: true, // FIXME Has it any effect?
    );
  }
}

class TableViewSource<DataObject extends Object> extends DataTableSource {
  final List<DataObject> _content = [];
  final Map<String, DataColumnInfo<DataObject, SupportedType>> _columnInfo = {};
  final Map<DataObject, DataObject> _dataChanges = {};

  TableViewSource(BuildContext context) {
    if (!reflectableMarker.canReflectType(DataObject)) {
      print(
          "Cannot generate table view for type '$DataObject' since it's not reflectable.");
      return;
    }

    var classMirror = reflectableMarker.reflectType(DataObject) as ClassMirror;
    Map<String, DeclarationMirror> classDeclarations = classMirror.declarations;

    classDeclarations.forEach(
      (name, declarationMirror) {
        if (declarationMirror is! VariableMirror) {
          return;
        }

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

        CellType? getObjectValue<CellType extends SupportedType>(
            DataObject object) {
          var value = reflectableMarker
              .reflect(object)
              .invokeGetter(declarationMirror.simpleName);
          if (value == null) {
            return null;
          }

          return constructor(value);
        }

        void setObjectValue<CellType extends SupportedType>(
            DataObject object, CellType? newValue) {
          // FIXME Is the setter result required for anything?
          print("Set ${newValue?.value}");
          final setterResult = reflectableMarker
              .reflect(object)
              .invokeSetter(declarationMirror.simpleName, newValue?.value);
        }

        final bool isNullableType = declarationMirror.type.isNullable;

        _columnInfo[name] = DataColumnInfo<DataObject, SupportedType>(
          supportedType,
          declarationMirror.type,
          getObjectValue,
          declarationMirror.isFinal ? null : setObjectValue,
          supportedType.when(
            int: (value) => _createCellGenerator(context, supportedType,
                isNullableType, getObjectValue, setObjectValue),
            bool: (value) => _createCellGenerator(context, supportedType,
                isNullableType, getObjectValue, setObjectValue),
            string: (value) => _createCellGenerator(context, supportedType,
                isNullableType, getObjectValue, setObjectValue),
            unsupported: (value) => _createCellGenerator(context, supportedType,
                isNullableType, getObjectValue, setObjectValue),
          ),
        );
      },
    );
  }

  @override
  DataRow? getRow(int index) {
    final object = _content[index];
    final List<DataCell> cells = [];

    _columnInfo.forEach((columnName, info) {
      cells.add(info.cellGenerator(object));
    });

    return DataRow(cells: cells);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _content.length;

  @override
  int get selectedRowCount => 0;

  void setData(List<DataObject> data) {
    _content.clear();
    _content.addAll(data);
    notifyListeners();
  }

  Map<DataObject, DataObject> getChanges() {
    return _dataChanges;
  }
}
