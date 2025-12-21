import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:listen_it/listen_it.dart';
import 'package:provider/provider.dart';

class MemberView extends StatelessWidget {
  final _tableViewSource = TableViewSource<Member>();
  final _changeRecords = ListNotifier<ChangeRecord>(data: []);
  final _editable = ValueNotifier<bool>(false);

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

        _tableViewSource.content.addAll(members);
        return true;
      },
    );
  }

  ListNotifier<ChangeRecord> get changeRecords {
    return _changeRecords;
  }

  set editable(bool editable) {
    _editable.value = editable;
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

  void _reinitTableSource(BuildContext context) {
    _tableViewSource.initialize(
        context, _editable.value ? _onCellChange : null);
  }

  @override
  Widget build(BuildContext context) {
    _editable.addListener(() => _reinitTableSource(context));
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
