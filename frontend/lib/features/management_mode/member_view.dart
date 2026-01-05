import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/widget_feature.dart';
import 'package:green3neo/localizer.dart';
import 'package:listen_it/listen_it.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:watch_it/watch_it.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("member_view");

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
  final _viewMode = ValueNotifier<ViewMode>(ViewMode.readOnly);
  final _propertyFilter = ValueNotifier<bool Function(String)?>(null);

  final _changeRecords = ListNotifier<ChangeRecord>(data: []);
  final _selectedRecords = ListNotifier<Member>(data: []);

  // ignore: unused_element_parameter
  MemberView._create({super.key});

  Future<bool> forceReloadDataFromDB() {
    return getAllMembers().then(
      (members) {
        _tableViewSource.content.clear();
        _changeRecords.clear();

        if (members == null) {
          _logger.severe("Could not load members");
          return false;
        }

        _tableViewSource.content.addAll(members
            .map((m) => TableViewSourceEntry(value: m, selected: false)));
        return true;
      },
    );
  }

  set viewMode(final ViewMode viewMode) => _viewMode.value = viewMode;

  set propertyFilter(final bool Function(String)? propertyFilter) {
    _propertyFilter.value = propertyFilter;
  }

  ListNotifier<ChangeRecord> get changeRecords => _changeRecords;

  ListNotifier<Member> get selectedRecords => _selectedRecords;

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

  void _onSelectedChanged(final Member member, final bool selected) {
    if (selected) {
      _selectedRecords.add(member);
    } else {
      if (!_selectedRecords.remove(member)) {
        _logger.warning("Could not remove element from selected member");
      }
    }
  }

  void _reinitTableSource(final BuildContext context) {
    final onCellChanged =
        (_viewMode.value == ViewMode.editable) ? _onCellChanged : null;
    final onSelectedChanged =
        (_viewMode.value == ViewMode.selectable) ? _onSelectedChanged : null;

    _tableViewSource.initialize(
      context: context,
      onCellChanged: onCellChanged,
      onSelectedChanged: onSelectedChanged,
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

    final selectionText = ValueNotifier<String>("");
    _tableViewSource.addListener(() {
      selectionText.value = Localizer.instance.text(
        (l) => l.selectedOf(
          selected: _tableViewSource.selectedRowCount,
          totalNum: _tableViewSource.rowCount,
        ),
      );
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

class MemberViewFeature implements WidgetFeature<MemberView> {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberViewFeature>(() => MemberViewFeature());
  }

  @override
  MemberView get widget => MemberView._create();
}
