import 'package:currency_widget/currency_widget.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
// import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:green3neo/localizer.dart';
import 'package:material_ui/material_ui.dart';

// FIXME Maybe extend from FormBuilderFieldDecoration<String>?
class CurrencyField extends FormBuilderField<String> {
  CurrencyField({super.key})
      : super(
          name: "currency",
          valueTransformer: (String? value) =>
              (value == null) ? null : double.tryParse(value),
          // keyboardType: TextInputType.numberWithOptions(decimal: true),
          // validator: FormBuilderValidators.compose([
          //   FormBuilderValidators.required(
          //       errorText:
          //           Localizer.instance.text((l) => l.invalidAmount(unit: "€"))),
          //   FormBuilderValidators.float(
          //       errorText:
          //           Localizer.instance.text((l) => l.invalidAmount(unit: "€"))),
          //   FormBuilderValidators.positiveNumber(
          //       errorText:
          //           Localizer.instance.text((l) => l.invalidAmount(unit: "€"))),
          //   FormBuilderValidators.min(
          //     0,
          //     inclusive: false,
          //     errorText:
          //         Localizer.instance.text((l) => l.invalidAmount(unit: "€")),
          //   ),
          // ]),
          builder: (FormFieldState<String> field) {
            // FIXME Adapt language
            final controller = CurrencyController(lang: "de");

            controller.mount.addListener(
              () {
                field.didChange(controller.mount.value?.toString());
              },
            );

            return InputDecorator(
              decoration: InputDecoration(
                labelText: Localizer.instance.text((l) => l.amount(unit: "€")),
                errorText: field.errorText,
                border: InputBorder.none,
              ),
              child: CurrencyTextField(
                currencyCode: "eur",
                currencyController: controller,
              ),
            );
          },
        );
}
