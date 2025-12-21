import 'package:flutter/material.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';

class ViewManagementMode extends WatchingWidget {
  final _tableViewSource = TableViewSource<Member>();
  final _lastMemberSourceUpdate = ValueNotifier<DateTime?>(null);

  ViewManagementMode._create({super.key});

  void _receiveDataFromDB(MemberView memberView) {
    memberView.forceReloadDataFromDB().then((reloadSucceeded) {
      if (reloadSucceeded) {
        _lastMemberSourceUpdate.value = DateTime.now();
      }
    });
  }

  static String _formatLastDate(DateTime? date, BuildContext context) {
    if (date == null) {
      return AppLocalizations.of(context).noDate;
    }

    return AppLocalizations.of(context).lastUpdate(date: date);
  }

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    _tableViewSource.initialize(context, null);
    _lastMemberSourceUpdate.value = DateTime.now();

    final MemberView memberView = getIt<MemberView>(param1: _tableViewSource);

    final formattedLastDate = watch(_lastMemberSourceUpdate)
        .map((value) => _formatLastDate(value, context));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _receiveDataFromDB(memberView),
              child: Text(AppLocalizations.of(context).updateData),
            ),
            Text(formattedLastDate.value),
          ],
        ),
        memberView
      ],
    );
  }
}

class ViewManagementModeFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<ViewManagementMode>(
        () => ViewManagementMode._create());
  }
}
