import 'package:flutter/material.dart';
import 'package:green3neo/components/form_fields/form_text_field.dart';
import 'package:green3neo/localizer.dart';

class CreditorIbanField extends FormTextField<String> {
  CreditorIbanField({super.key})
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.creditorIban),
          invalidText: Localizer.instance.text((l) => l.invalidCreditorIban),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}
