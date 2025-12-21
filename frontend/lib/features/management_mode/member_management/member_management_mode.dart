import 'package:flutter/material.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/localizer.dart';

import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/l10n/app_localizations.dart';

import 'change_record_utility.dart';

class MemberManagementMode extends WatchingWidget {
  final _tableViewSource = TableViewSource<Member>();
  final _changeRecords = ListNotifier<ChangeRecord>(data: []);

  // ignore: unused_element_parameter
  MemberManagementMode._create({super.key});

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

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    _tableViewSource.initialize(context, _onCellChange);

    final MemberView memberView = getIt<MemberView>(param1: _tableViewSource);

    final uncommittedChanges = watch(_changeRecords).isNotEmpty;

    return Column(
      children: [
        ElevatedButton(
          onPressed: uncommittedChanges
              ? () => _showPersistChangesDialog(context)
              : null,
          child: Text(Localizer.instance.text((l) => l.commitChanges)),
        ),
        memberView
      ],
    );
  }
}

class MemberManagementModeFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberManagementMode>(
        () => MemberManagementMode._create());
  }
}
