import 'package:flutter/material.dart';
import 'package:green3neo/components/form_fields/form_text_field.dart';
import 'package:green3neo/localizer.dart';

class CreditorNameField extends FormTextField<String> {
  CreditorNameField({super.key})
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.creditorName),
          invalidText: Localizer.instance.text((l) => l.invalidCreditorName),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}
