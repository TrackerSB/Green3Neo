import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:green3neo/main.reflectable.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets("Member view renders inside its parent Expanded", (
    WidgetTester tester,
  ) async {
    final getIt = GetIt.instance;
    await getIt.reset();
    addTearDown(getIt.reset);
    getIt.registerSingletonAsync<LoadedProfile>(
      () async => LoadedProfile.create(),
    );
    initializeReflectable();

    final memberView = MemberViewFeature().widget;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(children: [Expanded(child: memberView)]),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
