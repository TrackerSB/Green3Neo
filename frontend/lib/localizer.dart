import 'package:flutter/material.dart';
import 'package:green3neo/l10n/app_localizations.dart';
import 'package:logging/logging.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("localizer");

class Localizer {
  static Localizer? _instance;
  AppLocalizations? _localizations;

  Localizer._();

  static Localizer get instance {
    _instance ??= Localizer._();
    return _instance!;
  }

  void init(BuildContext context) {
    _localizations = AppLocalizations.of(context);
  }

  String text(String Function(AppLocalizations) function) {
    if (_localizations == null) {
      const String message = "No localization available";
      _logger.warning(message);
      return message;
    }

    return function(_localizations!);
  }
}
