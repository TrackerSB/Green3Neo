import 'package:flutter/material.dart';
import 'package:green3neo/features/management_mode/management_mode.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/localizer.dart';
import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';

class ViewManagementPage extends WatchingWidget {
  final _lastMemberSourceUpdate = ValueNotifier<DateTime?>(null);

  ViewManagementPage._create({super.key});

  void _receiveDataFromDB(MemberView memberView) {
    memberView.forceReloadDataFromDB().then((reloadSucceeded) {
      if (reloadSucceeded) {
        _lastMemberSourceUpdate.value = DateTime.now();
      }
    });
  }

  static String _formatLastDate(DateTime? date, BuildContext context) {
    if (date == null) {
      return Localizer.instance.text((l) => l.noDate);
    }

    return Localizer.instance.text((l) => l.lastUpdate(date: date));
  }

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    _lastMemberSourceUpdate.value = DateTime.now();

    final MemberView memberView = getIt<MemberView>();
    memberView.viewMode = ViewMode.readOnly;
    memberView.propertyFilter = null;

    final formattedLastDate = watch(_lastMemberSourceUpdate)
        .map((value) => _formatLastDate(value, context));

    return Column(
      children: [
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _receiveDataFromDB(memberView),
              child: Text(Localizer.instance.text((l) => l.updateData)),
            ),
            Text(formattedLastDate.value),
          ],
        ),
        Expanded(
          child: memberView,
        ),
      ],
    );
  }
}

class ViewManagementMode implements ManagementMode<ViewManagementPage> {
  static ViewManagementPage? instance;

  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<ViewManagementMode>(() => ViewManagementMode());
  }

  @override
  String get modeName => "ViewManagementMode"; // FIXME Localize

  @override
  ViewManagementPage get widget {
    instance ??= ViewManagementPage._create();
    return instance!;
  }
}
