import 'package:flutter/material.dart';
import 'package:green3neo/member_management_page.dart';
import 'package:green3neo/backend_api/frb_generated.dart' as backend_api;
import 'package:green3neo/database_api/frb_generated.dart' as database_api;
import 'main.reflectable.dart';

void main() async {
  initializeReflectable();

  await backend_api.RustLib.init();
  await database_api.RustLib.init();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: MemberManagementPage(),
      ),
    );
  }
}
