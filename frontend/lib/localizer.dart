import 'package:flutter/material.dart';
import 'package:green3neo/l10n/app_localizations.dart';

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
      // FIXME Log warning about not finding localization
      return "no localization available";
    }

    return function(_localizations!);
  }
}
