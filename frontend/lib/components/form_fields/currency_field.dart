import 'package:flutter/material.dart';
import 'package:green3neo/components/form_fields/form_text_field.dart';
import 'package:green3neo/localizer.dart';

class CurrencyField extends FormTextField<double> {
  static final requiredDoubleFormat =
      RegExp(r"^[1-9][0-9]*([,|\.][0-9]+)?$", caseSensitive: false);

  CurrencyField({super.key})
      : super(
          convert: (final String value) => double.tryParse(value),
          labelText: Localizer.instance.text((l) => l.amount(unit: "€")),
          invalidText:
              Localizer.instance.text((l) => l.invalidAmount(unit: "€")),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          validate: (final String value) =>
              requiredDoubleFormat.hasMatch(value),
        );
}
