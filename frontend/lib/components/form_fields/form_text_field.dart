import 'package:flutter/material.dart';

class FormTextField<ResultType> extends StatelessWidget {
  final value = ValueNotifier<ResultType?>(null);
  final ResultType? Function(String) convert;
  final String labelText;
  final String invalidText;
  final TextInputType? keyboardType;
  final bool Function(String)? validate;

  FormTextField({
    super.key,
    required this.convert,
    required this.labelText,
    required this.invalidText,
    this.keyboardType,
    this.validate,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      validator: (value) {
        if ((value == null) || (validate != null) && !validate!(value)) {
          return invalidText;
        }

        return null;
      },
      onSaved: (final String? textValue) {
        value.value = (textValue == null) ? null : convert(textValue);
      },
    );
  }
}
