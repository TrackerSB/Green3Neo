import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:green3neo/reflectable.dart';
import 'package:provider/provider.dart';
import 'package:reflectable/mirrors.dart';

part 'table_view.freezed.dart';

typedef CellValueHandler<CellType extends SupportedType?> = void Function(
    CellType?);
typedef ObjectValueGetter<DataObject, CellType extends SupportedType?>
    = CellType? Function(DataObject);
typedef ObjectValueSetter<DataObject, CellType extends SupportedType?> = void
    Function(DataObject, CellType?);
typedef ObjectChangeHandler<DataObject> = void Function(
    DataObject, String, SupportedType?, SupportedType?);
typedef DataCellGenerator<DataObject> = DataCell Function(DataObject);

@Freezed()
sealed class SupportedType with _$SupportedType {
  const SupportedType._();

  const factory SupportedType.int(int value) = IntVariant;
  const factory SupportedType.string(String value) = StringVariant;
  const factory SupportedType.bool(bool value) = BoolVariant;
  const factory SupportedType.unsupported(dynamic value) = UnsupportedVariant;
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
  return switch (createDefaultValue<CellType>()) {
    IntVariant(value: final int _) => TableViewIntCellPopup(
        initialValue: initialValue as IntVariant?,
        isNullable: isNullableType,
        onCellValueSubmitted:
            onCellValueSubmitted as CellValueHandler<IntVariant?>),
    StringVariant(value: final String _) => TableViewStringCellPopup(
        initialValue: initialValue as StringVariant?,
        isNullable: isNullableType,
        onCellValueSubmitted:
            onCellValueSubmitted as CellValueHandler<StringVariant?>),
    BoolVariant(value: final bool _) => TableViewBoolCellPopup(
        initialValue: initialValue as BoolVariant?,
        isNullable: isNullableType,
        onCellValueSubmitted:
            onCellValueSubmitted as CellValueHandler<BoolVariant?>),
    UnsupportedVariant(value: final dynamic _) => TableViewUnsupportedCellPopup(
        initialValue: initialValue as UnsupportedVariant?,
        isNullable: isNullableType,
        onCellValueSubmitted:
            onCellValueSubmitted as CellValueHandler<UnsupportedVariant?>),
  };
}

DataCellGenerator<DataObject> _createDataCellGeneratorForColumn<
        DataObject extends Object, CellType extends SupportedType>(
    BuildContext context,
    VariableMirror variableMirror,
    ObjectChangeHandler<DataObject>? onObjectValueChange) {
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

  DataCell createDataCellFromObject(DataObject object) {
    final currentCellValue = ValueNotifier<CellType?>(getObjectValue(object));

    final bool isNullableType = variableMirror.type.isNullable;
    final bool isFinal = variableMirror.isFinal;

    void onCellValueSubmitted(CellType? newCellValue) {
      final CellType? previousCellValue = currentCellValue.value;
      currentCellValue.value = newCellValue;
      // FIXME Is the setter result required for anything?
      final setterResult = reflectableMarker
          .reflect(object)
          .invokeSetter(variableMirror.simpleName, newCellValue?.value);
      onObjectValueChange!(
          object, variableMirror.simpleName, previousCellValue, newCellValue);
    }

    return DataCell(
      TableViewCell<CellType>(cellValueState: currentCellValue),
      onTap: isFinal || (onObjectValueChange == null)
          ? null
          : () {
              showGeneralDialog(
                context: context,
                pageBuilder: (context, animation, secondaryAnimation) {
                  return Dialog(
                      child: _createCellPopup<CellType>(currentCellValue.value,
                          isNullableType, onCellValueSubmitted));
                },
              );
            },
    );
  }

  return createDataCellFromObject;
}

Map<String, DataCellGenerator<DataObject>>
    _createColumnGenerators<DataObject extends Object>(BuildContext context,
        ObjectChangeHandler<DataObject>? onObjectValueChange) {
  if (!reflectableMarker.canReflectType(DataObject)) {
    // FIXME Provide either logging or error handling
    print(
        "Cannot generate table view for type '$DataObject' since it's not reflectable.");
    return <String, DataCellGenerator<DataObject>>{};
  }

  Map<String, DataCellGenerator<DataObject>> columnInfos = {};

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
              _createDataCellGeneratorForColumn<DataObject, StringVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
        case bool:
          columnInfos[columnName] =
              _createDataCellGeneratorForColumn<DataObject, BoolVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
        case int:
          columnInfos[columnName] =
              _createDataCellGeneratorForColumn<DataObject, IntVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
        default:
          columnInfos[columnName] =
              _createDataCellGeneratorForColumn<DataObject, UnsupportedVariant>(
                  context, declarationMirror, onObjectValueChange);
          break;
      }
    },
  );
  return columnInfos;
}

class TableViewCell<CellType extends SupportedType> extends StatefulWidget {
  final ValueNotifier<CellType?> cellValueState;

  const TableViewCell({super.key, required this.cellValueState});

  @override
  TableViewCellState<CellType> createState() => TableViewCellState<CellType>();
}

class TableViewCellState<CellType extends SupportedType>
    extends State<TableViewCell<CellType>> {
  dynamic cellValue;

  void updateCellValue() {
    setState(() => cellValue = widget.cellValueState.value?.value);
  }

  void observeWidget(covariant TableViewCell<CellType>? oldWidget,
      covariant TableViewCell<CellType> newWidget) {
    if (oldWidget != null) {
      oldWidget.cellValueState.removeListener(updateCellValue);
    }

    newWidget.cellValueState.addListener(updateCellValue);
    updateCellValue();
  }

  @override
  void initState() {
    super.initState();
    observeWidget(null, widget);
  }

  @override
  void didUpdateWidget(covariant TableViewCell<CellType> oldWidget) {
    super.didUpdateWidget(oldWidget);
    observeWidget(oldWidget, widget);
  }

  @override
  Widget build(BuildContext context) {
    if (cellValue == null) {
      return const Text("null");
    }

    return Text(cellValue.toString());
  }
}

abstract class TableViewCellPopup<CellType extends SupportedType>
    extends WatchingWidget {
  final CellType? initialValue;
  final currentValue = ValueNotifier<CellType?>(null);
  final bool isNullable;
  final CellValueHandler<CellType?> onCellValueSubmitted;

  TableViewCellPopup(
      {super.key,
      required this.initialValue,
      required this.isNullable,
      required this.onCellValueSubmitted}) {
    currentValue.value = initialValue;
  }

  void back(BuildContext context) {
    Navigator.pop(context);
  }

  void submitInternalValue(BuildContext context) {
    if (initialValue != currentValue.value) {
      onCellValueSubmitted(currentValue.value);
    }
    back(context);
  }

  void setInternalNullState(bool? isNullChecked) {
    CellType? newValue;
    if (isNullChecked == null || isNullChecked) {
      newValue = createDefaultValue<CellType>();
    } else {
      newValue = null;
    }
    currentValue.value = newValue;
  }

  @override
  Widget build(BuildContext context) {
    final Widget actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: () => submitInternalValue(context),
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
        CloseButton(
          onPressed: () {
            currentValue.value = initialValue;
            back(context);
          },
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

    // WARN Non-null popup content must only be created if value is not null
    Widget createNonNullPopupContent() => Padding(
          padding: const EdgeInsets.all(10),
          child: buildPopup(context),
        );

    final valueIsNotNull = currentValue.map((value) => value != null);

    if (isNullable) {
      return StatefulBuilder(builder:
          (BuildContext context, void Function(void Function()) setState) {
        return Row(
          children: [
            Checkbox(
              value: valueIsNotNull.value,
              onChanged: (newValue) =>
                  setState(() => setInternalNullState(newValue)),
              tristate: false,
            ),
            Expanded(
                child: createPopupContent(valueIsNotNull.value
                    ? createNonNullPopupContent()
                    : Text(AppLocalizations.of(context).unexpectedNullValue))),
          ],
        );
      });
    }

    return createPopupContent(createNonNullPopupContent());
  }

  Widget buildPopup(BuildContext context) {
    return const Placeholder();
  }
}

class TableViewUnsupportedCellPopup
    extends TableViewCellPopup<UnsupportedVariant> {
  TableViewUnsupportedCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  Widget buildPopup(BuildContext context) {
    return Text(currentValue.value.toString());
  }
}

class TableViewIntCellPopup extends TableViewCellPopup<IntVariant> {
  TableViewIntCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  Widget buildPopup(BuildContext context) {
    return TextFormField(
      keyboardType:
          const TextInputType.numberWithOptions(decimal: false, signed: false),
      initialValue: currentValue.value?.value.toString(),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (newValue) =>
          currentValue.value = IntVariant(int.parse(newValue)),
      onFieldSubmitted: (newValue) => submitInternalValue(context),
    );
  }
}

class TableViewStringCellPopup extends TableViewCellPopup<StringVariant> {
  TableViewStringCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  Widget buildPopup(BuildContext context) {
    return TextFormField(
      initialValue: currentValue.value?.value,
      onChanged: (newValue) => currentValue.value = StringVariant(newValue),
      onFieldSubmitted: (newValue) => submitInternalValue(context),
    );
  }
}

class TableViewBoolCellPopup extends TableViewCellPopup<BoolVariant> {
  TableViewBoolCellPopup(
      {super.key,
      required super.initialValue,
      required super.isNullable,
      required super.onCellValueSubmitted});

  @override
  Widget buildPopup(BuildContext context) {
    return StatefulBuilder(builder:
        (BuildContext context, void Function(void Function()) setState) {
      return Checkbox(
        value: currentValue.value?.value,
        onChanged: (newValue) {
          setState(() {
            currentValue.value = BoolVariant(newValue == true);
          });
        },
      );
    });
  }
}

class TableView<DataObject extends Object> extends StatelessWidget {
  const TableView({super.key});

  @override
  Widget build(BuildContext context) {
    final tableViewSource = context.watch<TableViewSource<DataObject>>();

    if (tableViewSource._generators.isEmpty) {
      return Text(AppLocalizations.of(context).noDataAvailable);
    }

    final List<DataColumn> dataColumns = tableViewSource._generators
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
  final content = ListNotifier<DataObject>(data: []);
  final Map<String, DataCellGenerator<DataObject>> _generators = {};

  TableViewSource();

  void initialize(
      BuildContext context, ObjectChangeHandler<DataObject>? onCellChange) {
    _generators
        .addAll(_createColumnGenerators<DataObject>(context, onCellChange));

    content.addListener(() {
      notifyListeners();
    });
  }

  @override
  DataRow? getRow(int rowIndex) {
    if ((rowIndex > content.length) || (rowIndex < 0)) {
      return null;
    }

    final DataObject object = content[rowIndex];
    final List<DataCell> cells = [];

    for (final generator in _generators.values) {
      cells.add(generator(object));
    }

    return DataRow(cells: cells);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => content.length;

  @override
  int get selectedRowCount => 0;
}
