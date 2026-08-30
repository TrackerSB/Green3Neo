import 'package:green3neo/features/management_mode/management_mode.dart';
import 'package:green3neo/features/management_mode/member_management/member_management_mode.dart';
import 'package:green3neo/features/management_mode/sepa_management/sepa_management_mode.dart';
import 'package:green3neo/features/management_mode/view_management/view_management_mode.dart';
import 'package:green3neo/features/widget_feature.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:material_ui/material_ui.dart';
import 'package:watch_it/watch_it.dart';

class MemberManagementPage extends WatchingWidget {
  final _selectedMode = ValueNotifier<ManagementMode<Widget>?>(null);

  MemberManagementPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    List<ManagementMode<Widget>> managementModes = [];
    if (getIt.isRegistered<ViewManagementMode>()) {
      managementModes.add(getIt<ViewManagementMode>());
    }
    if (getIt.isRegistered<MemberManagementMode>()) {
      managementModes.add(getIt<MemberManagementMode>());
    }
    if (getIt.isRegistered<SepaManagementMode>()) {
      managementModes.add(getIt<SepaManagementMode>());
    }

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return managementModes.isEmpty
            ? Placeholder(
                child: Text(
                  "No member management mode features enabled", // FIXME Localize
                ),
              )
            : Column(
                children: [
                  SegmentedButton<ManagementMode<Widget>>(
                    segments: managementModes.map((mode) {
                      return ButtonSegment(
                        value: mode,
                        label: Text(mode.modeName),
                      );
                    }).toList(),
                    selected: {
                      ?_selectedMode.value,
                    }, // FIXME What does the leading question mark do?
                    emptySelectionAllowed: false,
                    multiSelectionEnabled: false,
                    onSelectionChanged:
                        (Set<ManagementMode<Widget>>? selectedModes) {
                          assert(
                            selectedModes != null && selectedModes.isNotEmpty,
                          );

                          setState(() {
                            _selectedMode.value = selectedModes!.first;
                          });
                        },
                  ),
                  Expanded(
                    child: _selectedMode.value!.widget,
                  ),
                ],
              );
      },
    );
  }
}

class MemberManagementView extends WidgetFeature {
  static MemberManagementPage? instance;

  @override
  void registerUnconditionally() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<MemberManagementView>(
      () => MemberManagementView(),
    );
  }

  @override
  MemberManagementPage get widget {
    instance ??= MemberManagementPage._create();
    return instance!;
  }

  @override
  Feature requiredFeature() {
    return Feature.memberManagementView;
  }
}
