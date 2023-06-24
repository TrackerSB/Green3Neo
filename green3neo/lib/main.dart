import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ffi.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MainAppState(),
      child: MaterialApp(
        home: HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var mainAppState = context.watch<MainAppState>();

    return Scaffold(
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                mainAppState.updateIt();
              },
              child: const Text("Click me"),
            ),
            Text(
              mainAppState.current,
            ),
          ],
        ),
      ),
    );
  }
}

class MainAppState extends ChangeNotifier {
  MainAppState() {
    updateIt();
  }

  var current = "Uninitialized";

  Future<void> updateIt() async {
    current = (await backendApi.getMe()).toString();
    notifyListeners();
  }
}
