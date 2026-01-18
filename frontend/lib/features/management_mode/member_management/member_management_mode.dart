import 'package:flutter/material.dart';

import 'package:green3neo/features/management_mode/management_mode.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/interface/database_api/api/member.dart';
import 'package:green3neo/localizer.dart';
import 'package:listen_it/listen_it.dart';
import 'package:logging/logging.dart';
import 'package:watch_it/watch_it.dart';

import 'change_record_utility.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("member_management_mode");

class _ApplyChangeRecordsButton extends WatchingWidget {
  final ListNotifier<ChangeRecord> changeRecords;

  const _ApplyChangeRecordsButton({super.key, required this.changeRecords});

  void _showPersistChangesDialog(
      BuildContext context, List<ChangeRecord> changeRecords) {
    List<ChangeRecord> mergedChangeRecords = mergeChangeRecords(changeRecords);

    if (mergedChangeRecords.isEmpty) {
      _logger.warning("Not changes to apply left after merging");
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

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: watch(changeRecords).isNotEmpty
          ? () => _showPersistChangesDialog(context, changeRecords)
          : null,
      child: Text(Localizer.instance.text((l) => l.commitChanges)),
    );
  }
}

class MemberManagementPage extends StatelessWidget {
  // ignore: unused_element_parameter
  const MemberManagementPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    final MemberView memberView = getIt<MemberViewFeature>().widget;
    memberView.viewMode = ViewMode.editable;
    memberView.propertyFilter = null;

    return Column(
      children: [
        _ApplyChangeRecordsButton(changeRecords: memberView.changeRecords),
        Expanded(
          child: memberView,
        ),
      ],
    );
  }
}

class MemberManagementMode implements ManagementMode<MemberManagementPage> {
  static MemberManagementPage? instance;

  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberManagementMode>(
        () => MemberManagementMode());
  }

  @override
  String get modeName => "MemberManagementMode"; // FIXME Localize

  @override
  MemberManagementPage get widget {
    instance ??= MemberManagementPage._create();
    return instance!;
  }
}
