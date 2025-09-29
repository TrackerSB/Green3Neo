import 'package:flutter/material.dart';
import 'package:green3neo/member_management_page.dart';
import 'package:green3neo/backend_api/frb_generated.dart' as backend_api;
import 'package:green3neo/database_api/frb_generated.dart' as database_api;
import 'main.reflectable.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

const String windowTitle = "Green3Neo"; // FIXME Localize text

void main() async {
  initializeReflectable();

  await backend_api.RustLib.init();
  await database_api.RustLib.init();

  bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (isDesktop) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      center: true,
      title: windowTitle,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();

      windowManager.setTitle(windowTitle);
    });
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: windowTitle,
      home: Scaffold(
        body: MemberManagementPage(),
      ),
    );
  }
}
