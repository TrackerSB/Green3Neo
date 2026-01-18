import 'package:flutter/material.dart';

import 'package:green3neo/features/management_mode/management_mode.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/features/management_mode/sepa_management/sepa_generation_wizard.dart';
import 'package:green3neo/interface/database_api/api/models.dart';
import 'package:green3neo/localizer.dart';
import 'package:listen_it/listen_it.dart';
import 'package:watch_it/watch_it.dart';

class _StartSepaGenerationWizardButton extends WatchingWidget {
  final ListNotifier<Member> selectedMember;

  const _StartSepaGenerationWizardButton(
      {super.key, required this.selectedMember});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: watch(selectedMember).isEmpty
          ? null
          : () {
              final getIt = GetIt.instance;

              final wizard =
                  getIt<SepaGenerationWizard>(param1: selectedMember);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => wizard,
                  fullscreenDialog: true,
                ),
              );
            },
      child: Text(Localizer.instance.text((l) => l.createDirectDebit)),
    );
  }
}

class SepaManagementPage extends StatelessWidget {
  const SepaManagementPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    final MemberView memberView = getIt<MemberViewFeature>().widget;
    memberView.viewMode = ViewMode.selectable;
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
        _StartSepaGenerationWizardButton(
            selectedMember: memberView.selectedRecords),
        Expanded(
          child: memberView,
        ),
      ],
    );
  }
}

class SepaManagementMode implements ManagementMode<SepaManagementPage> {
  static SepaManagementPage? instance;

  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<SepaManagementMode>(() => SepaManagementMode());
  }

  @override
  String get modeName => "SepaManagementMode"; // FIXME Localize

  @override
  SepaManagementPage get widget {
    instance ??= SepaManagementPage._create();
    return instance!;
  }
}
