import 'package:flutter/material.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
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

    // Copy list for improved thread safety
    final List<ChangeRecord> records = _changeRecords.toList();
    _changeRecords.clear();
    changeMember(changes: records).then(
      (succeededUpdateIndices) {
        succeededUpdateIndices.sort();
        for (final BigInt index in succeededUpdateIndices.reversed) {
          records.removeAt(index.toInt());
        }

        // Add records that failed to update back to the list
        _changeRecords.addAll(records);
      },
    );
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

  Widget _visualizeChanges(List<ChangeRecord> changeRecords) {
    return Table(
      children: [
        const TableRow(
          children: [
            // FIXME Localize texts
            Text("Membership ID"),
            Text("Column"),
            Text("Previous Value"),
            Text("New Value"),
          ],
        ),
        for (final record in changeRecords)
          TableRow(
            children: [
              Text(record.membershipid.toString()),
              Text(record.column),
              Text(record.previousValue ?? "null"),
              Text(record.newValue ?? "null"),
            ],
          ),
      ],
    );
  }

  void _showPersistChangesDialog() {
    // Merge changes of same membershipid and column removing identity records
    List<ChangeRecord> mergedChangeRecords = [];
    for (final record in _changeRecords) {
      final int existingRecordIndex = mergedChangeRecords.indexWhere((r) =>
          r.membershipid == record.membershipid && r.column == record.column);
      if (existingRecordIndex < 0) {
        mergedChangeRecords.add(record);
      } else {
        final existingRecord = mergedChangeRecords[existingRecordIndex];
        if (existingRecord.previousValue == record.newValue) {
          // Remove identity record
          mergedChangeRecords.removeAt(existingRecordIndex);
        } else {
          // Update existing record with new value
          // FIXME Assert previous value of existing record and new record are the same
          mergedChangeRecords[existingRecordIndex] = ChangeRecord(
            membershipid: existingRecord.membershipid,
            column: existingRecord.column,
            previousValue: existingRecord.previousValue,
            newValue: record.newValue,
          );
        }
      }
    }

    if (mergedChangeRecords.isEmpty) {
      // FIXME Provide warning
      return;
    }

    // Show changes
    showGeneralDialog(
      context: context,
      // FIXME Localize texts
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        child: Column(
          children: [
            _visualizeChanges(mergedChangeRecords),
            Row(
              children: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    _commitDataChanges();
                    Navigator.of(context).pop();
                  },
                  child: const Text("Commit"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void onCellChange(Member member, String setterName,
      SupportedType? previousCellValue, SupportedType? newCellValue) {
    var internalPreviousValue = previousCellValue?.value;
    var internalNewValue = newCellValue?.value;
    setState(() => _changeRecords.add(ChangeRecord(
        membershipid: member.membershipid,
        column: setterName,
        previousValue: (internalPreviousValue != null)
            ? internalPreviousValue.toString()
            : null,
        newValue:
            (internalNewValue != null) ? internalNewValue.toString() : null)));
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
              // FIXME Ask for overriding made changes
              onPressed: _receiveDataFromDB,
              child: const Text("Update data"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_changeRecords.isNotEmpty) {
                  _showPersistChangesDialog();
                }
              },
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
