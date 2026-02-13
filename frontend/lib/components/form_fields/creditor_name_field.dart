import 'package:flutter/material.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:green3neo/localizer.dart';

class CreditorNameField extends FormBuilderTextField {
  CreditorNameField({super.key})
      : super(
          name: "creditorName",
          decoration: InputDecoration(
              labelText: Localizer.instance.text((l) => l.creditorName)),
          keyboardType: TextInputType.text,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(
                errorText:
                    Localizer.instance.text((l) => l.invalidCreditorName))
            // FIXME Introduce regex in backend and call match function in frontend
          ]),
        );
}
