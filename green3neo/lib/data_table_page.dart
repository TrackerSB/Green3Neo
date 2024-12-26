import 'package:flutter/material.dart';
import 'package:green3neo/backend/api/member.dart';
import 'package:green3neo/backend/models.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

class DataTablePageState extends State<DataTablePage> {
  TableViewSource<Member>? _tableViewSource;
  final List<ChangeRecord> _changeRecords = [];

  DataTablePageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    getAllMembers().then(
      (members) {
        // FIXME Warn about state not being initialized yet
        if (members == null) {
          setState(() {
            // FIXME Provide error message
            _tableViewSource?.data = List.empty();
          });
        } else {
          setState(() {
            _tableViewSource?.data = members;
          });
        }
      },
    );
  }

  void _commitDataChanges() {
    if (_tableViewSource == null) {
      print("Cannot commit changes without table state");
      return;
    }

    changeMember(changes: _changeRecords);
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
    var internalValue = newCellValue?.value;
    setState(() => _changeRecords.add(ChangeRecord(
        membershipid: member.membershipid,
        column: setterName,
        value: (internalValue != null) ? internalValue.toString() : null)));
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
