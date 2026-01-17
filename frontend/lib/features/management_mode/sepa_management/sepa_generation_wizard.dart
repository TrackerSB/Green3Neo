import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/localizer.dart';
import 'package:green3neo/sepa_api/api/creditor.dart';
import 'package:green3neo/sepa_api/api/debitor.dart';
import 'package:green3neo/sepa_api/api/generation.dart';
import 'package:green3neo/sepa_api/api/transaction.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("sepa_generation_wizard");

class _FormTextField<ResultType> extends StatelessWidget {
  final value = ValueNotifier<ResultType?>(null);
  final ResultType? Function(String) convert;
  final String labelText;
  final String invalidText;
  final TextInputType? keyboardType;
  final bool Function(String)? validate;

  _FormTextField({
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

class _CurrencyField extends _FormTextField<double> {
  static final requiredDoubleFormat =
      RegExp(r"^[1-9][0-9]*([,|\.][0-9]+)?$", caseSensitive: false);

  _CurrencyField()
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

class _PurposeField extends _FormTextField<String> {
  _PurposeField()
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.purpose),
          invalidText: Localizer.instance.text((l) => l.invalidPurpose),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}

class _CreditorNameField extends _FormTextField<String> {
  _CreditorNameField()
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.creditorName),
          invalidText: Localizer.instance.text((l) => l.invalidCreditorName),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}

class _CreditorIbanField extends _FormTextField<String> {
  _CreditorIbanField()
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.creditorIban),
          invalidText: Localizer.instance.text((l) => l.invalidCreditorIban),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}

class _CreditorIdField extends _FormTextField<String> {
  _CreditorIdField()
      : super(
          convert: (final String value) => value,
          labelText: Localizer.instance.text((l) => l.creditorId),
          invalidText: Localizer.instance.text((l) => l.invalidCreditorId),
          keyboardType: TextInputType.text,
          // FIXME Introduce regex in backend and call match function in frontend
          validate: (final String value) => value.isNotEmpty,
        );
}

Future<String> _generateSepaContent(final Creditor creditor,
    final List<Member> member, final double value, final String purpose) {
  final transactions = member.map(
    (final Member m) {
      final mandate = Mandate(
        id: m.membershipid.toString(),
        // FIXME Use correct date of signature
        dateOfSignatureUtc: DateTime.utc(2023, 5, 1),
      );
      final debitor = Debitor(
        name:
            "${m.accountholderprename ?? m.prename} ${m.accountholdersurname ?? m.surname}",
        iban: m.iban,
        mandate: mandate,
      );
      return Transaction(
        debitor: debitor,
        value: value,
        purpose: purpose,
      );
    },
  ).toList();
  return generateSepaDocument(
      // FIXME Make message ID configurable
      messageId: "2026-01-09_FancyMessageID",
      collectionDateUtc: DateTime.now().toUtc(),
      creditor: creditor,
      transactions: transactions);
}

Future<String?> _askUserForOutputPath() {
  final Future<String?> downloadDir = getDownloadsDirectory()
      .then((final Directory? dir) => dir?.absolute.path);

  return downloadDir.then(
    (final String? dir) => FilePicker.platform.saveFile(
      allowedExtensions: ["xml"],
      lockParentWindow: true,
      type: FileType.custom,
      initialDirectory: dir,
    ),
    onError: (final Object error, final StackTrace trace) =>
        _logger.shout("Failed to ask user for save path", error, trace),
  );
}

Future<void> _writeContentToPath(
    final Future<String> contentFuture, final Future<String?> pathFuture) {
  return (contentFuture, pathFuture).wait.then(
    (final (String, String?) resultRecord) {
      final (content, path) = resultRecord;
      if (path == null) {
        return;
      }

      final outputFile = File(path);
      outputFile.writeAsStringSync(content);
    },
  );
}

class SepaGenerationWizard extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final List<Member> member;

  SepaGenerationWizard._create({super.key, required this.member});

  void _onOkButtonPressed(
      final _CreditorNameField creditorNameField,
      final _CreditorIbanField creditorIbanField,
      final _CreditorIdField creditorIdField,
      final _CurrencyField currencyField,
      final _PurposeField purposeField,
      final BuildContext context) async {
    final FormState formState = _formKey.currentState!;

    if (!formState.validate()) {
      return;
    }

    formState.save();

    final double? amount = currencyField.value.value;
    final String? creditorName = creditorNameField.value.value;
    final String? creditorIban = creditorIbanField.value.value;
    final String? creditorId = creditorIdField.value.value;
    final String? purpose = purposeField.value.value;
    if ((amount == null) ||
        (creditorName == null) ||
        (creditorIban == null) ||
        (creditorId == null) ||
        (purpose == null)) {
      _logger.severe(
          "The form should not be valid since there are not set form fields");
      return;
    }

    final creditor =
        Creditor(name: creditorName, id: creditorId, iban: creditorIban);

    final Future<String> sepaContent =
        _generateSepaContent(creditor, member, amount, purpose);
    final Future<String?> outputPath = _askUserForOutputPath();

    await _writeContentToPath(sepaContent, outputPath);

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyField = _CurrencyField();
    final purposeField = _PurposeField();
    final creditorNameField = _CreditorNameField();
    final creditorIbanField = _CreditorIbanField();
    final creditorIdField = _CreditorIdField();

    return Scaffold(
      body: Column(
        children: [
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                Text(Localizer.instance.text(
                    (l) => l.numMembersSelected(numSelected: member.length))),
                creditorNameField,
                creditorIbanField,
                creditorIdField,
                purposeField,
                currencyField,
              ],
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _onOkButtonPressed(
                    creditorNameField,
                    creditorIbanField,
                    creditorIdField,
                    currencyField,
                    purposeField,
                    context),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
              CloseButton(
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SepaGenerationWizardFactory implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerFactoryParam<SepaGenerationWizard, List<Member>, void>(
        (member, _) => SepaGenerationWizard._create(member: member));
  }
}
