import 'package:flutter/material.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:green3neo/localizer.dart';

class MessageIdField extends FormBuilderTextField {
  MessageIdField({super.key})
      : super(
          name: "messageId",
          decoration: InputDecoration(
              labelText: Localizer.instance.text((l) => l.messageId)),
          keyboardType: TextInputType.text,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(
                errorText: Localizer.instance.text((l) => l.invalidMessageId))
            // FIXME Introduce regex in backend and call match function in frontend
          ]),
        );
}
