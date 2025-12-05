import 'package:flutter/material.dart';

import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'change_record_utility.dart';

class MemberManagementPage extends WatchingStatefulWidget {
  // ignore: unused_element_parameter
  const MemberManagementPage._create({super.key});

  @override
  State<StatefulWidget> createState() => MemberManagementPageState();
}

class MemberManagementPageFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberManagementPage>(
        () => MemberManagementPage._create());
  }
}

class MemberManagementPageState extends State<MemberManagementPage> {
  TableViewSource<Member>? _tableViewSource;
  final _changeRecords = ListNotifier<ChangeRecord>(data: []);
  final _lastMemberSourceUpdate = ValueNotifier<DateTime?>(null);

  MemberManagementPageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    if (_changeRecords.isNotEmpty) {
      // FIXME Warn about unsaved changes
      return;
    }

    getAllMembers().then(
      (members) {
        // FIXME Warn about state not being initialized yet
        _tableViewSource?.content.clear();
        if (members == null) {
          // FIXME Provide error message
        } else {
          _tableViewSource?.content.addAll(members);
          _lastMemberSourceUpdate.value = DateTime.now();
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

  void onCellChange(Member member, String setterName,
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

  String _formatLastDate(DateTime? date) {
    if (date == null) {
      return AppLocalizations.of(context).noDate;
    }

    return AppLocalizations.of(context).lastUpdate(date: date);
  }

  @override
  Widget build(BuildContext context) {
    _tableViewSource ??= TableViewSource<Member>(context, onCellChange);

    final uncommittedChanges = watch(_changeRecords).isNotEmpty;
    final formattedLastDate =
        watch(_lastMemberSourceUpdate).map(_formatLastDate);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: uncommittedChanges ? null : _receiveDataFromDB,
              child: Text(AppLocalizations.of(context).updateData),
            ),
            ElevatedButton(
              onPressed: uncommittedChanges ? _showPersistChangesDialog : null,
              child: Text(AppLocalizations.of(context).commitChanges),
            ),
            Text(formattedLastDate.value),
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
