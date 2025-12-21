import 'package:flutter/material.dart';
import 'package:green3neo/features/management_mode/member_view.dart';

import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/l10n/app_localizations.dart';

import 'change_record_utility.dart';

class MemberManagementPage extends WatchingWidget {
  final _tableViewSource = TableViewSource<Member>();
  final _changeRecords = ListNotifier<ChangeRecord>(data: []);
  final _lastMemberSourceUpdate = ValueNotifier<DateTime?>(null);

  // ignore: unused_element_parameter
  MemberManagementPage._create({super.key});

  void _receiveDataFromDB(MemberView memberView) {
    if (_changeRecords.isNotEmpty) {
      // FIXME Warn about unsaved changes
      return;
    }

    memberView.forceReloadDataFromDB().then((reloadSucceeded) {
      if (reloadSucceeded) {
        _lastMemberSourceUpdate.value = DateTime.now();
      }
    });
  }

  void _showPersistChangesDialog(BuildContext context) {
    List<ChangeRecord> mergedChangeRecords = mergeChangeRecords(_changeRecords);

    if (mergedChangeRecords.isEmpty) {
      // FIXME Provide warning
      return;
    }

    // Show changes
    showGeneralDialog(
      context: context,
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        child: Column(
          children: [
            visualizeChanges(context, mergedChangeRecords),
            Row(
              children: [
                TextButton(
                  onPressed: Navigator.of(context).pop,
                  child:
                      Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
                TextButton(
                  onPressed: () {
                    commitDataChanges(mergedChangeRecords);
                    Navigator.of(context).pop();
                  },
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onCellChange(Member member, String setterName,
      SupportedType? previousCellValue, SupportedType? newCellValue) {
    var internalPreviousValue = previousCellValue?.value;
    var internalNewValue = newCellValue?.value;
    _changeRecords.add(ChangeRecord(
        membershipid: member.membershipid,
        column: setterName,
        previousValue: (internalPreviousValue != null)
            ? internalPreviousValue.toString()
            : null,
        newValue:
            (internalNewValue != null) ? internalNewValue.toString() : null));
  }

  String _formatLastDate(DateTime? date, BuildContext context) {
    if (date == null) {
      return AppLocalizations.of(context).noDate;
    }

    return AppLocalizations.of(context).lastUpdate(date: date);
  }

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    _tableViewSource.initialize(context, _onCellChange);

    final MemberView memberView = getIt<MemberView>(param1: _tableViewSource);

    _receiveDataFromDB(memberView);

    final uncommittedChanges = watch(_changeRecords).isNotEmpty;
    final formattedLastDate = watch(_lastMemberSourceUpdate)
        .map((value) => _formatLastDate(value, context));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: uncommittedChanges
                  ? null
                  : () => _receiveDataFromDB(memberView),
              child: Text(AppLocalizations.of(context).updateData),
            ),
            ElevatedButton(
              onPressed: uncommittedChanges
                  ? () => _showPersistChangesDialog(context)
                  : null,
              child: Text(AppLocalizations.of(context).commitChanges),
            ),
            Text(formattedLastDate.value),
          ],
        ),
        memberView
      ],
    );
  }
}

class MemberManagementPageFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberManagementPage>(
        () => MemberManagementPage._create());
  }
}
