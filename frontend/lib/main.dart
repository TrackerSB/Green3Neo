import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'package:get_it/get_it.dart';
import 'package:green3neo/backend_api/frb_generated.dart' as backend_api;
import 'package:green3neo/database_api/frb_generated.dart' as database_api;
import 'package:green3neo/features/management_mode/member_management_mode/page.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:green3neo/main.reflectable.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // Initialize reflectable mechanism
  initializeReflectable();

  // Prepare FFI bindings
  await backend_api.RustLib.init();
  await database_api.RustLib.init();

  // Prepare desktop window manager
  bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (isDesktop) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      center: true,
      title: "No title", // FIXME Insert app title
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Register top level features
  MemberManagementPageFeature().register();
  MemberViewFeature().register();

  // Start app
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    return MaterialApp(
      title: "No title", // FIXME AppLocalizations.of(...) returns null
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: getIt<MemberManagementPage>(),
      ),
    );
  }
}
