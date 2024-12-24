import 'package:flutter/material.dart';
import 'package:green3neo/backend/api/dummy.dart';
import 'package:green3neo/backend/models.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

// Map setter name to new value
typedef ChangeRecords = Map<String, SupportedType?>;

class DataTablePageState extends State<DataTablePage> {
  TableViewSource<Member>? _tableViewSource;
  final Map<Member, ChangeRecords> _changeRecords = {};

  DataTablePageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    getDummyMembers().then(
      (members) => setState(
        () {
          // FIXME Warn about state not being initialized yet
          if (members == null) {
            // FIXME Provide error message
            _tableViewSource?.setData(List.empty());
          } else {
            _tableViewSource?.setData(members);
          }
        },
      ),
    );
  }

  void _commitDataChanges() {
    if (_tableViewSource == null) {
      print("Cannot commit changes without table state");
      return;
    }

    print("Following changes are made ${_changeRecords.length}");
    // FIXME Why is dataChanges always empty?
    _changeRecords.forEach((object, changeRecords) {
      print("For object $object");
      changeRecords.forEach((setterName, newValue) {
        print("Set $setterName to ${newValue?.value}");
      });
    });
  }

  Widget _wrapInScrollable(Widget toWrap, Axis direction) {
    var scrollController = ScrollController();

    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: direction,
        child: toWrap,
      ),
    );
  }

  void onCellChange(
      Member member, String setterName, SupportedType? newCellValue) {
    _changeRecords.putIfAbsent(member, () => <String, SupportedType?>{});
    _changeRecords[member]![setterName] = newCellValue;
  }

  @override
  Widget build(BuildContext context) {
    _tableViewSource ??= TableViewSource<Member>(context, onCellChange);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _receiveDataFromDB,
              child: const Text("Update data"),
            ),
            ElevatedButton(
              onPressed: _commitDataChanges,
              child: const Text("Commit changes"),
            ),
          ],
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: true),
            child: _wrapInScrollable(
              _wrapInScrollable(
                SizedBox(
                  width: 2000, // FIXME Determine required width for table
                  child: ChangeNotifierProvider(
                    create: (_) => _tableViewSource,
                    child: const TableView<Member>(),
                  ),
                ),
                Axis.horizontal,
              ),
              Axis.vertical,
            ),
          ),
        ),
      ],
    );
  }
}
