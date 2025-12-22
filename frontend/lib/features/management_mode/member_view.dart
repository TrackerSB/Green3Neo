import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:listen_it/listen_it.dart';
import 'package:provider/provider.dart';
import 'package:watch_it/watch_it.dart';

enum ViewMode {
  readOnly,
  editable,
  selectable,
}

class MemberView extends StatelessWidget {
  final _tableViewSource = TableViewSource<Member>();
  final _changeRecords = ListNotifier<ChangeRecord>(data: []);
  final _viewMode = ValueNotifier<ViewMode>(ViewMode.readOnly);
  final _onSelectChangedUserDefined =
      ValueNotifier<void Function(Member, bool)?>(null);
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

  ValueListenable<int> get numEntries =>
      _tableViewSource.content.select((c) => c.length);

  ValueListenable<int> get numSelected {
    return _tableViewSource.content.select((c) {
      return c.fold(0, (final int currentNumSelected, final entry) {
        return currentNumSelected + (entry.selected ? 1 : 0);
      });
    });
  }

  set viewMode(final ViewMode viewMode) => _viewMode.value = viewMode;

  set onSelectedChanged(final void Function(Member, bool)? onSelectedChanged) {
    _onSelectChangedUserDefined.value = onSelectedChanged;
  }

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

  void _onSelectChanged(final Member member, final bool selected) {
    print("Internal called");
    _onSelectChangedUserDefined.value?.call(member, selected);
  }

  void _reinitTableSource(final BuildContext context) {
    final onCellChanged =
        (_viewMode.value == ViewMode.editable) ? _onCellChanged : null;

    final onSelectChanged =
        (_viewMode.value == ViewMode.selectable) ? _onSelectChanged : null;

    _tableViewSource.initialize(
      context: context,
      onCellChanged: onCellChanged,
      onSelectChanged: onSelectChanged,
      propertyFilter: _propertyFilter.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    _viewMode.addListener(() => _reinitTableSource(context));
    _onSelectChangedUserDefined.addListener(() => _reinitTableSource(context));
    _propertyFilter.addListener(() => _reinitTableSource(context));
    _reinitTableSource(context);

    // FIXME Visualize failed reload
    forceReloadDataFromDB();

    return ChangeNotifierProvider(
      create: (_) => _tableViewSource,
      child: TableView<Member>(tableViewSource: _tableViewSource),
    );
  }
}

class MemberViewFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberView>(() => MemberView._create());
  }
}
