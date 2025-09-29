import 'package:flutter/material.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';
import 'change_record_utility.dart';

class MemberManagementPage extends StatefulWidget {
  const MemberManagementPage({super.key});

  @override
  State<StatefulWidget> createState() => MemberManagementPageState();
}

class MemberManagementPageState extends State<MemberManagementPage> {
  TableViewSource<Member>? _tableViewSource;
  final List<ChangeRecord> _changeRecords = [];

  MemberManagementPageState() {
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

  static Widget _wrapInScrollable(Widget toWrap, Axis direction) {
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

  void _showPersistChangesDialog() {
    List<ChangeRecord> mergedChangeRecords = mergeChangeRecords(_changeRecords);

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
            visualizeChanges(mergedChangeRecords),
            Row(
              children: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    commitDataChanges(mergedChangeRecords);
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
