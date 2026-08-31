import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:green3neo/features/feature_view.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/features/management_mode/member_management/member_management_mode.dart';
import 'package:green3neo/features/management_mode/member_management_view.dart';
import 'package:green3neo/features/management_mode/member_view.dart';
import 'package:green3neo/features/management_mode/sepa_management/sepa_generation_wizard.dart';
import 'package:green3neo/features/management_mode/sepa_management/sepa_management_mode.dart';
import 'package:green3neo/features/management_mode/view_management/view_management_mode.dart';
import 'package:green3neo/interface/backend_api/api/logging.dart'
    as backend_logging;
import 'package:green3neo/interface/backend_api/frb_generated.dart'
    as backend_api;
import 'package:green3neo/interface/database_api/frb_generated.dart'
    as database_api;
import 'package:green3neo/interface/sepa_api/frb_generated.dart' as sepa_api;
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:green3neo/localizer.dart';
import 'package:green3neo/main.reflectable.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:watch_it/watch_it.dart';
import 'package:window_manager/window_manager.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("main");

void setupLogging() {
  // Reroute Dart logging output
  hierarchicalLoggingEnabled = false;
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord record) {
    /* FIXME Due to performance considerations make stack trace resolving
     * optional
     */

    final String? callingFrame;

    if (record.stackTrace == null) {
      final StackTrace stackTrace = StackTrace.current;
      final List<String> frames = stackTrace.toString().split("\n");

      final int lastFrameInLoggingModuleIndex = frames.lastIndexWhere((
        String frame,
      ) {
        return frame.contains("package:logging/");
      });
      callingFrame = frames.elementAtOrNull(lastFrameInLoggingModuleIndex + 1);
    } else {
      final StackTrace stackTrace = record.stackTrace!;
      final List<String> frames = stackTrace.toString().split("\n");
      callingFrame = frames.elementAtOrNull(0);
    }

    final String? logLocation = callingFrame
        ?.replaceFirst(RegExp(r"^#\d+\s*"), "")
        .trim();
    final String message =
        "${(logLocation ?? "")} '${record.loggerName}': ${record.message}";

    runZonedGuarded(
      () {
        switch (record.level) {
          case Level.SHOUT:
          case Level.SEVERE:
            backend_logging.error(message: message);
            break;
          case Level.WARNING:
            backend_logging.warn(message: message);
            break;
          case Level.INFO:
            backend_logging.info(message: message);
            break;
          default:
            backend_logging.warn(
              message:
                  "Log level ${record.level.name} is unsupported. "
                  "Message was $message",
            );
            break;
        }
      },
      (Object error, StackTrace stackTrace) {
        FlutterError.presentError(
          FlutterErrorDetails(
            exception: "Could not log to backend. Presenting to user",
          ),
        );
        FlutterError.presentError(
          FlutterErrorDetails(exception: error, stack: stackTrace),
        );
      },
    );
  });

  // Duplicate errors and exceptions caught by Flutter to logger
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logger.shout(details);
  };

  /* Print errors and exceptions not caught by Flutter to logger before
   * exiting application
   */
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    _logger.shout("Encountered error not caught by Flutter", error, stackTrace);
    // FIXME When to consider an error "recoverable" or "not too bad"?
    return true;
  };
}

void main() async {
  setupLogging();

  initializeReflectable();

  // Prepare FFI bindings
  /* NOTE 2026-01-02: Due to usage of Cargo Workspaces the default generated
   * paths for loading the external libraries do not work. However, since the
   * the resulting SO files are expected to be within the folder bundle/lib
   * (for linux copied by CMake) these are found anyways.
   */
  await backend_api.RustLib.init();
  await database_api.RustLib.init();
  await sepa_api.RustLib.init();

  // Prepare desktop window manager
  final bool isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (isDesktop) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(center: true);

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Register all features considering currently loaded profile and system features
  await Future.wait([
    FeatureSettings().register(),
    LoadedProfileFeature().register(),
    MemberViewFeature().register(),
    MemberManagementView().register(),
    MemberManagementMode().register(),
    ViewManagementMode().register(),
    SepaManagementMode().register(),
    SepaGenerationWizardFactory().register(),
  ]);

  // Start app
  runApp(const MainApp());
}

class MainApp extends WatchingWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    return MaterialApp(
      onGenerateTitle: (context) {
        Localizer.instance.init(context);
        final localizedAppTitle = Localizer.instance.text((l) => l.appTitle);
        windowManager.setTitle(localizedAppTitle);
        return localizedAppTitle;
      },
      localizationsDelegates: [
        /* WARN 2026-08-21: Do not use AppLocalizations.localizationDelegates
         * since these include old (non-material_ui) delegates
         */
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatefulBuilder(
        builder: (BuildContext context, StateSetter _) {
          Localizer.instance.init(context);

          return Scaffold(
            appBar: AppBar(
              actions: [
                ElevatedButton(
                  onPressed: () => {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return getIt.maybeGet<FeatureSettings>()?.widget ??
                              Placeholder(
                                child: Text(
                                  "Feature ${FeatureSettings().requiredFeature().name} unavailable", // FIXME Localize
                                ),
                              );
                        },
                      ),
                    ),
                  },
                  child: Text(Localizer.instance.text((l) => l.settings)),
                ),
              ],
            ),
            body:
                getIt.maybeGet<MemberManagementView>()?.widget ??
                Placeholder(
                  child: Text(
                    "Feature ${MemberManagementView().requiredFeature().name} unavailable", // FIXME Localize
                  ),
                ),
          );
        },
      ),
    );
  }
}
