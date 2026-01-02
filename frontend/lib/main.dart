import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:green3neo/backend_api/api/logging.dart' as logging;
import 'package:green3neo/backend_api/frb_generated.dart' as backend_api;
import 'package:green3neo/database_api/frb_generated.dart' as database_api;
import 'package:green3neo/sepa_api/frb_generated.dart' as sepa_api;
import 'package:green3neo/features/management_mode/member_management/member_management_mode.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/features/management_mode/sepa_management/sepa_management_mode.dart';
import 'package:green3neo/features/management_mode/view_management/view_management_mode.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:green3neo/localizer.dart';
import 'package:green3neo/main.reflectable.dart';
import 'package:logging/logging.dart';
import 'package:watch_it/watch_it.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // Initialize reflectable mechanism
  initializeReflectable();

  // Prepare FFI bindings
  await backend_api.RustLib.init();
  await database_api.RustLib.init();
  await sepa_api.RustLib.init();

  // Set up logging
  hierarchicalLoggingEnabled = false;
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    /* FIXME Due to performance considerations make stack trace resolving
     * optional
     */

    final String? callingFrame;

    if (record.stackTrace == null) {
      final StackTrace stackTrace = StackTrace.current;
      final List<String> frames = stackTrace.toString().split("\n");

      final int lastFrameInLoggingModuleIndex =
          frames.lastIndexWhere((final String frame) {
        return frame.contains("package:logging/");
      });
      callingFrame = frames.elementAtOrNull(lastFrameInLoggingModuleIndex + 1);
    } else {
      final StackTrace stackTrace = record.stackTrace!;
      final List<String> frames = stackTrace.toString().split("\n");
      callingFrame = frames.elementAtOrNull(0);
    }

    final String? logLocation =
        callingFrame?.replaceFirst(RegExp(r"^#\d+\s*"), "").trim();
    final String message =
        "${(logLocation ?? "")} '${record.loggerName}': ${record.message}";

    switch (record.level) {
      case Level.SHOUT:
      case Level.SEVERE:
        logging.error(message: message);
        break;
      case Level.WARNING:
        logging.warn(message: message);
        break;
      case Level.INFO:
        logging.info(message: message);
        break;
      default:
        logging.warn(
            message: "Log level ${record.level.name} is unsupported. "
                "Message was $message");
        break;
    }
  });

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
  MemberViewFeature().register();
  MemberManagementMode().register();
  ViewManagementMode().register();
  SepaManagementMode().register();

  // Start app
  runApp(const MainApp());
}

class MainApp extends WatchingWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    final managementModes = [
      getIt<ViewManagementMode>(),
      getIt<MemberManagementMode>(),
      getIt<SepaManagementMode>(),
    ];

    Widget selectedModeWidget = managementModes.first.widget;

    return MaterialApp(
      title: "No title", // FIXME AppLocalizations.of(...) returns null
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatefulBuilder(
        builder: (final BuildContext context, final StateSetter _) {
          Localizer.instance.init(context);

          return Scaffold(
            body: StatefulBuilder(
              builder:
                  (final BuildContext context, final StateSetter setState) {
                return Column(
                  children: [
                    SegmentedButton<Widget>(
                      segments: managementModes.map((mode) {
                        return ButtonSegment(
                          value: mode.widget,
                          label: Text(mode.modeName),
                        );
                      }).toList(),
                      selected: {selectedModeWidget},
                      emptySelectionAllowed: false,
                      multiSelectionEnabled: false,
                      onSelectionChanged: (Set<Widget>? selectedModes) {
                        assert(
                            selectedModes != null && selectedModes.isNotEmpty);

                        setState(() {
                          selectedModeWidget = selectedModes!.first;
                        });
                      },
                    ),
                    Expanded(
                      child: selectedModeWidget,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
