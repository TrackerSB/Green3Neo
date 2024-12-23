import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';
import 'reflectable.dart';

part 'table_view.freezed.dart';

typedef CellValueHandler<CellType extends SupportedType?> = void Function(
    CellType?);
typedef ObjectValueGetter<DataObject, CellType extends SupportedType?>
    = CellType? Function(DataObject);
typedef ObjectValueSetter<DataObject, CellType extends SupportedType?> = void
    Function(DataObject, CellType?);
typedef ObjectChangeHandler<DataObject> = void Function(
    DataObject, String, SupportedType?);
typedef DataCellGenerator<DataObject> = DataCell Function(DataObject);

@Freezed()
sealed class SupportedType with _$SupportedType {
  const SupportedType._();

  const factory SupportedType.int(int value) = IntVariant;
  const factory SupportedType.string(String value) = StringVariant;
  const factory SupportedType.bool(bool value) = BoolVariant;
  const factory SupportedType.unsupported(dynamic value) = UnsupportedVariant;
}

DataCell _createDataCell<CellType extends SupportedType>(
    BuildContext context,
    CellValueState<CellType> cellState,
    Widget cell,
    Widget Function(CellType?) popupGenerator) {
  return DataCell(
    cell,
    onTap: () {
      showGeneralDialog(
        context: context,
        pageBuilder: (context, animation, secondaryAnimation) {
          return Dialog(child: popupGenerator(cellState.value));
        },
      );
    },
  );
}

CellType createDefaultValue<CellType extends SupportedType>() {
  if (CellType == IntVariant) {
    return const SupportedType.int(0) as CellType;
  }
  if (CellType == StringVariant) {
    return const SupportedType.string("") as CellType;
  }
  if (CellType == BoolVariant) {
    return const SupportedType.bool(false) as CellType;
  }
  if (CellType == UnsupportedVariant) {
    return const SupportedType.unsupported(null) as CellType;
  }

  // FIXME Throw exception or add warning
  return const SupportedType.unsupported(null) as CellType;
}

Widget _createCellPopup<CellType extends SupportedType>(CellType? initialValue,
    bool isNullableType, CellValueHandler<CellType?> onCellValueSubmitted) {
  return createDefaultValue<CellType>().when(
      int: (value) => TableViewIntCellPopup(
          initialValue: initialValue as IntVariant?,
          isNullable: isNullableType,
          onCellValueSubmitted:
              onCellValueSubmitted as CellValueHandler<IntVariant?>),
      string: (value) => TableViewStringCellPopup(
          initialValue: initialValue as StringVariant?,
          isNullable: isNullableType,
          onCellValueSubmitted:
              onCellValueSubmitted as CellValueHandler<StringVariant?>),
      bool: (value) => TableViewBoolCellPopup(
          initialValue: initialValue as BoolVariant?,
          isNullable: isNullableType,
          onCellValueSubmitted:
              onCellValueSubmitted as CellValueHandler<BoolVariant?>),
      unsupported: (value) => TableViewUnsupportedCellPopup(
          initialValue: initialValue as UnsupportedVariant?,
          isNullable: isNullableType,
          onCellValueSubmitted:
              onCellValueSubmitted as CellValueHandler<UnsupportedVariant?>));
}

class DataColumnInfo<DataObject extends Object,
    CellType extends SupportedType> {
  final TypeMirror typeMirror;
  final ObjectValueGetter<DataObject, CellType> objectGetter;
  final ObjectValueSetter<DataObject, CellType>? objectSetter;
  final DataCellGenerator<DataObject> dataCellGenerator;

  DataColumnInfo(
    this.typeMirror,
    this.objectGetter,
    this.objectSetter,
    this.dataCellGenerator,
  );
}

class CellValueState<CellType extends SupportedType> extends ChangeNotifier {
  CellType? _value;

  CellType? get value => _value;

  set value(newValue) {
    _value = newValue;
    notifyListeners();
  }
}

DataColumnInfo<DataObject, CellType> _generateDataColumnTypeInfo<
        DataObject extends Object, CellType extends SupportedType>(
    BuildContext context,
    VariableMirror variableMirror,
    ObjectChangeHandler<DataObject> onObjectValueChange) {
  dynamic constructor;
  switch (variableMirror.type.reflectedType) {
    case String:
      constructor = SupportedType.string;
      break;
    case bool:
      constructor = SupportedType.bool;
      break;
    case int:
      constructor = SupportedType.int;
      break;
    default:
      constructor = SupportedType.unsupported;
      break;
  }

  CellType? getObjectValue(DataObject object) {
    var value = reflectableMarker
        .reflect(object)
        .invokeGetter(variableMirror.simpleName);
    if (value == null) {
      return null;
    }

    return constructor(value);
  }

  void recordObjectValueChange(DataObject object, CellType? newValue) {
    // FIXME Is the setter result required for anything?
    final setterResult = reflectableMarker
        .reflect(object)
        .invokeSetter(variableMirror.simpleName, newValue?.value);
    onObjectValueChange(object, variableMirror.simpleName, newValue);
  }

  DataCell createDataCellFromObject(DataObject object) {
    final currentCellValue = CellValueState<CellType>();
    currentCellValue.value = getObjectValue(object);

    final bool isNullableType = variableMirror.type.isNullable;

    void onCellValueSubmitted(CellType? newCellValue) {
      currentCellValue.value = newCellValue;
    }

    return _createDataCell(
        context,
        currentCellValue,
        ChangeNotifierProvider(
          create: (_) => currentCellValue,
          child: TableViewCell<CellType>(),
        ),
        (CellType? initialValue) => _createCellPopup<CellType>(
            initialValue, isNullableType, onCellValueSubmitted));
  }

  return DataColumnInfo<DataObject, CellType>(
    variableMirror.type,
    getObjectValue,
    variableMirror.isFinal ? null : recordObjectValueChange,
    createDataCellFromObject,
  );
}

Map<String, DataColumnInfo<DataObject, SupportedType>>
    _generateDataColumnInfos<DataObject extends Object>(BuildContext context,
        ObjectChangeHandler<DataObject> onObjectValueChange) {
  if (!reflectableMarker.canReflectType(DataObject)) {
    // FIXME Provide either logging or error handling
    print(
        "Cannot generate table view for type '$DataObject' since it's not reflectable.");
    return <String, DataColumnInfo<DataObject, SupportedType>>{};
  }

  Map<String, DataColumnInfo<DataObject, SupportedType>> columnInfos = {};

  var classMirror = reflectableMarker.reflectType(DataObject) as ClassMirror;
  Map<String, DeclarationMirror> classDeclarations = classMirror.declarations;

  classDeclarations.forEach(
    (columnName, declarationMirror) {
      if (declarationMirror is! VariableMirror) {
        return;
      }

      switch (declarationMirror.type.reflectedType) {
        case String:
          columnInfos[columnName] =
              _generateDataColumnTypeInfo<DataObject, StringVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
        case bool:
          columnInfos[columnName] =
              _generateDataColumnTypeInfo<DataObject, BoolVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
        case int:
          columnInfos[columnName] =
              _generateDataColumnTypeInfo<DataObject, IntVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
        default:
          columnInfos[columnName] =
              _generateDataColumnTypeInfo<DataObject, UnsupportedVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
      }
    },
  );
  return columnInfos;
}

class TableViewCell<CellType extends SupportedType> extends StatelessWidget {
  const TableViewCell({super.key});

  @override
  Widget build(BuildContext context) {
    final currentCellValue = context.watch<CellValueState<CellType>>();

    dynamic cellValue = currentCellValue.value?.value;
    if (cellValue == null) {
      return const Text("null");
    }

    return Text(cellValue.toString());
  }
}

abstract class TableViewCellPopup<CellType extends SupportedType>
    extends StatefulWidget {
  final CellType? initialValue;
  final bool isNullable;
  final CellValueHandler<CellType?> onCellValueSubmitted;

  const TableViewCellPopup(
      {super.key,
      required this.initialValue,
      required this.isNullable,
      required this.onCellValueSubmitted});
}

abstract class TableViewCellPopupState<CellType extends SupportedType>
    extends State<TableViewCellPopup<CellType>> {
  CellType? _currentValue;

  TableViewCellPopupState();

  CellType get currentValue => _currentValue!;

  setInternalValue(CellType? newCellValue) {
    setState(() => _currentValue = newCellValue);
  }

  submitInternalValue() {
    widget.onCellValueSubmitted(_currentValue);
    Navigator.pop(context);
  }

  setInternalNullState(isChecked) {
    CellType? newValue;
    if (isChecked) {
      newValue = createDefaultValue<CellType>();
    } else {
      newValue = null;
    }
    setInternalValue(newValue);
  }

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final Widget actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: submitInternalValue,
          child: const Text("Save"),
        ),
        ElevatedButton(
          onPressed: () {
            setInternalValue(widget.initialValue);
            submitInternalValue();
          },
          child: const Text("Cancel"),
        ),
      ],
    );

    Widget createPopupContent(Widget content) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [content, actions],
      );
    }

    // FIXME Localize text
    const Widget nullPopupContent = Text("Value is currently null");

    // WARN Non-null popup content must only be created if value is not null
    Widget createNonNullPopupContent() => Padding(
      padding: const EdgeInsets.all(10),
      child: buildPopup(context),
    );

    if (widget.isNullable) {
      return Row(
        children: [
          Checkbox(
            value: _currentValue != null,
            onChanged: setInternalNullState,
          ),
          Expanded(
              child: createPopupContent((_currentValue == null)
                  ? nullPopupContent
                  : createNonNullPopupContent())),
        ],
      );
    }

    return createPopupContent(createNonNullPopupContent());
  }

  Widget buildPopup(BuildContext context) {
    return const Placeholder();
  }
}

class TableViewUnsupportedCellPopup
    extends TableViewCellPopup<UnsupportedVariant> {
  const TableViewUnsupportedCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  State<StatefulWidget> createState() => TableViewUnsupportedCellPopupState();
}

class TableViewUnsupportedCellPopupState
    extends TableViewCellPopupState<UnsupportedVariant> {
  TableViewUnsupportedCellPopupState();

  @override
  Widget buildPopup(BuildContext context) {
    return Text(currentValue.value.toString());
  }
}

class TableViewIntCellPopup extends TableViewCellPopup<IntVariant> {
  const TableViewIntCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  State<StatefulWidget> createState() => TableViewIntCellPopupState();
}

class TableViewIntCellPopupState extends TableViewCellPopupState<IntVariant> {
  TableViewIntCellPopupState();

  @override
  Widget buildPopup(BuildContext context) {
    return TextFormField(
      keyboardType:
          const TextInputType.numberWithOptions(decimal: false, signed: false),
      initialValue: currentValue.value.toString(),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (newValue) =>
          setInternalValue(IntVariant(int.parse(newValue))),
      onFieldSubmitted: (newValue) => submitInternalValue(),
    );
  }
}

class TableViewStringCellPopup extends TableViewCellPopup<StringVariant> {
  const TableViewStringCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  State<StatefulWidget> createState() => TableViewStringCellPopupState();
}

class TableViewStringCellPopupState
    extends TableViewCellPopupState<StringVariant> {
  TableViewStringCellPopupState();

  @override
  Widget buildPopup(BuildContext context) {
    return TextFormField(
      initialValue: currentValue.value,
      onChanged: (newValue) => setInternalValue(StringVariant(newValue)),
      onFieldSubmitted: (newValue) => submitInternalValue(),
    );
  }
}

class TableViewBoolCellPopup extends TableViewCellPopup<BoolVariant> {
  const TableViewBoolCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  State<StatefulWidget> createState() => TableViewBoolCellPopupState();
}

class TableViewBoolCellPopupState extends TableViewCellPopupState<BoolVariant> {
  TableViewBoolCellPopupState();

  @override
  Widget buildPopup(BuildContext context) {
    bool nonNullCurrentValue = currentValue.value;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => Checkbox(
        value: nonNullCurrentValue,
        onChanged: (newValue) {
          setInternalValue(BoolVariant(newValue == true));
          setState(() => nonNullCurrentValue = !nonNullCurrentValue);
        },
      ),
    );
  }
}

class TableView<DataObject extends Object> extends StatelessWidget {
  const TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final tableViewSource = context.watch<TableViewSource<DataObject>>();

    if (tableViewSource._columnInfo.isEmpty) {
      return const Text("No data");
    }

    List<DataColumn> dataColumns = tableViewSource._columnInfo
        .map<String, DataColumn>((columnName, columnInfo) {
          return MapEntry(
            columnName,
            DataColumn(
              label: Text(columnName),
            ),
          );
        })
        .values
        .toList();

    return PaginatedDataTable(
      columns: dataColumns,
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

  TableViewSource(
      BuildContext context, ObjectChangeHandler<DataObject> onCellChange) {
    _columnInfo
        .addAll(_generateDataColumnInfos<DataObject>(context, onCellChange));
  }

  @override
  DataRow? getRow(int index) {
    final object = _content[index];
    final List<DataCell> cells = [];

    _columnInfo.forEach((columnName, info) {
      cells.add(info.dataCellGenerator(object));
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
}
