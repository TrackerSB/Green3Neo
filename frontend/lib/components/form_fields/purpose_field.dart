import 'package:flutter/material.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:green3neo/interface/sepa_api/api.dart';
import 'package:green3neo/localizer.dart';

class PurposeField extends FormBuilderTextField {
  PurposeField({super.key})
      : super(
          name: "purpose",
          decoration: InputDecoration(
              labelText: Localizer.instance.text((l) => l.purpose)),
          keyboardType: TextInputType.text,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(
                errorText: Localizer.instance.text((l) => l.invalidPurpose))
            // FIXME Introduce regex in backend and call match function in frontend
          ]),
          valueTransformer: (final String? value) {
            return (value == null) ? null : Purpose(value: value);
          },
        );
}
