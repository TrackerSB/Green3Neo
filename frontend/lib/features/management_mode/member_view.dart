import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/localizer.dart';
import 'package:listen_it/listen_it.dart';
import 'package:provider/provider.dart';
import 'package:watch_it/watch_it.dart';

enum ViewMode {
  readOnly,
  editable,
  selectable,
}

class _SelfUpdatingText extends WatchingWidget {
  final ValueListenable<String> listenableText;

  const _SelfUpdatingText({super.key, required this.listenableText});

  @override
  Widget build(BuildContext context) {
    return Text(watch(listenableText).value);
  }
}

class MemberView extends WatchingWidget {
  final _tableViewSource = TableViewSource<Member>();
  final _changeRecords = ListNotifier<ChangeRecord>(data: []);
  final _viewMode = ValueNotifier<ViewMode>(ViewMode.readOnly);
  final _propertyFilter = ValueNotifier<bool Function(String)?>(null);

  // ignore: unused_element_parameter
  MemberView._create({super.key});

  Future<bool> forceReloadDataFromDB() {
    return getAllMembers().then(
      (members) {
        // FIXME Warn about state not being initialized yet
        _tableViewSource.content.clear();
        if (members == null) {
          // FIXME Provide error message
          return false;
        }

        _tableViewSource.content.addAll(members
            .map((m) => TableViewSourceEntry(value: m, selected: false)));
        return true;
      },
    );
  }

  ListNotifier<ChangeRecord> get changeRecords => _changeRecords;

  set viewMode(final ViewMode viewMode) => _viewMode.value = viewMode;

  set propertyFilter(final bool Function(String)? propertyFilter) {
    _propertyFilter.value = propertyFilter;
  }

  void _onCellChanged(final Member member, final String setterName,
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

  void _reinitTableSource(final BuildContext context) {
    final onCellChanged =
        (_viewMode.value == ViewMode.editable) ? _onCellChanged : null;

    _tableViewSource.initialize(
      context: context,
      onCellChanged: onCellChanged,
      rowsSelectable: (_viewMode.value == ViewMode.selectable),
      propertyFilter: _propertyFilter.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    _viewMode.addListener(() => _reinitTableSource(context));
    _propertyFilter.addListener(() => _reinitTableSource(context));
    _reinitTableSource(context);

    // FIXME Visualize failed reload
    forceReloadDataFromDB();

    final selectionText = _tableViewSource.content.select((c) {
      final numSelected = c.fold(
          0,
          (final int currentNumSelected, final entry) =>
              currentNumSelected + (entry.selected ? 1 : 0));
      final numEntries = c.length;

      return Localizer.instance.text(
          (l) => l.selectedOf(selected: numSelected, totalNum: numEntries));
    });

    final Widget expandedTableView = Expanded(
      child: ChangeNotifierProvider(
        create: (_) => _tableViewSource,
        child: TableView<Member>(tableViewSource: _tableViewSource),
      ),
    );

    /* NOTE 2025-12-22: Embedding the table view in Expanded and Column or Row
     * mitigates sizing problems. This pattern should be reused by any other
     * component including this widget
     */
    return (watch(_viewMode).value == ViewMode.selectable)
        ? Column(
            children: [
              _SelfUpdatingText(listenableText: selectionText),
              expandedTableView,
            ],
          )
        : expandedTableView;
  }
}

class MemberViewFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberView>(() => MemberView._create());
  }
}
