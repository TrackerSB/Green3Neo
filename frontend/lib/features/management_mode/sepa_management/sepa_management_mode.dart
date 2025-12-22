import 'package:flutter/material.dart';
import 'package:green3neo/features/management_mode/management_mode.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:watch_it/watch_it.dart';

class SepaManagementPage extends WatchingWidget {
  const SepaManagementPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    final MemberView memberView = getIt<MemberView>();
    memberView.editable = false;
    memberView.propertyFilter = (final String propertyName) {
      return [
        "membershipid",
        "prename",
        "surname",
        "title",
        "accountholderprename",
        "accountholdersurname",
        "iban",
        "bic",
        "iscontributionfree"
      ].map((p) => p.toLowerCase()).contains(propertyName.toLowerCase());
    };

    return Column(
      children: [
        Expanded(
          child: memberView,
        ),
      ],
    );
  }
}

class SepaManagementMode implements ManagementMode {
  static SepaManagementPage? instance;

  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<SepaManagementMode>(() => SepaManagementMode());
  }

  @override
  String get modeName => "SepaManagementMode"; // FIXME Localize

  @override
  WatchingWidget get widget {
    instance ??= SepaManagementPage._create();
    return instance!;
  }
}
