import 'package:flutter/material.dart';
import 'package:green3neo/data_table_page.dart';
import 'package:green3neo/backend_api/frb_generated.dart';
import 'main.reflectable.dart';

void main() async {
  initializeReflectable();

  await RustLib.init();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: DataTablePage(),
      ),
    );
  }
}
