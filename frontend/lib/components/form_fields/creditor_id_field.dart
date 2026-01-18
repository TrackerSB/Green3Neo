import 'package:flutter/material.dart';
import 'package:green3neo/components/form_fields/form_text_field.dart';
import 'package:green3neo/localizer.dart';

class CreditorIdField extends FormTextField<String> {
  CreditorIdField({super.key})
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.creditorId),
          invalidText: Localizer.instance.text((l) => l.invalidCreditorId),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}
