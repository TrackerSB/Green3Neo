import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/components/form_fields/creditor_iban_field.dart';
import 'package:green3neo/components/form_fields/creditor_id_field.dart';
import 'package:green3neo/components/form_fields/creditor_name_field.dart';
import 'package:green3neo/components/form_fields/currency_field.dart';
import 'package:green3neo/components/form_fields/message_id_field.dart';
import 'package:green3neo/components/form_fields/purpose_field.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/interface/backend_api/api.dart' as backend_api;
import 'package:green3neo/interface/backend_api/api/paths.dart';
import 'package:green3neo/interface/backend_api/api/profile.dart';
import 'package:green3neo/interface/database_api/api/models.dart';
import 'package:green3neo/interface/sepa_api/api.dart';
import 'package:green3neo/interface/sepa_api/api/generation.dart';
import 'package:green3neo/localizer.dart';
import 'package:logging/logging.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("sepa_generation_wizard");

Future<String> _generateSepaContent(
    final String messageId,
    final Creditor creditor,
    final List<Member> member,
    final double value,
    final String purpose) {
  final transactions = member.map(
    (final Member m) {
      final mandate = Mandate(
        id: MandateID(value: m.membershipid.toString()),
        // FIXME Use correct date of signature
        dateOfSignatureUtc: DateTime.utc(2023, 5, 1),
      );
      final debitor = Debitor(
        name: Name(
            value:
                "${m.accountholderprename ?? m.prename} ${m.accountholdersurname ?? m.surname}"),
        iban: IBAN(value: m.iban),
        mandate: mandate,
      );
      return Transaction(
        debitor: debitor,
        value: value,
        purpose: Purpose(value: purpose),
      );
    },
  ).toList();
  return generateSepaDocument(
      messageId: MessageID(value: messageId),
      collectionDateUtc: DateTime.now().toUtc(),
      creditor: creditor,
      transactions: transactions);
}

Future<String?> _askUserForOutputPath() {
  final Future<String> downloadDir = getUserDownloadDir();

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

Future<bool> _writeContentToPath(
    final Future<String> contentFuture, final Future<String?> pathFuture) {
  return (contentFuture, pathFuture).wait.then(
    (final (String, String?) resultRecord) {
      final (content, path) = resultRecord;
      if (path == null) {
        return false;
      }

      final outputFile = File(path);
      outputFile.writeAsStringSync(content);
      return true;
    },
  );
}

class SepaGenerationWizard extends StatelessWidget {
  final _formKey = GlobalKey<FormBuilderState>();
  final List<Member> member;

  SepaGenerationWizard._create({super.key, required this.member});

  Future<bool> _onOkButtonPressed(
      final MessageIdField messageIdField,
      final CreditorNameField creditorNameField,
      final CreditorIbanField creditorIbanField,
      final CreditorIdField creditorIdField,
      final CurrencyField currencyField,
      final PurposeField purposeField) async {
    final FormBuilderState formState = _formKey.currentState!;

    if (!formState.saveAndValidate()) {
      return false;
    }

    final String? messageId =
        formState.getTransformedValue(messageIdField.name, fromSaved: true);
    final double? amount =
        formState.getTransformedValue(currencyField.name, fromSaved: true);
    final String? creditorName =
        formState.getTransformedValue(creditorNameField.name, fromSaved: true);
    final String? creditorIban =
        formState.getTransformedValue(creditorIbanField.name, fromSaved: true);
    final String? creditorId =
        formState.getTransformedValue(creditorIdField.name, fromSaved: true);
    final String? purpose =
        formState.getTransformedValue(purposeField.name, fromSaved: true);

    if ((messageId == null) ||
        (amount == null) ||
        (creditorName == null) ||
        (creditorIban == null) ||
        (creditorId == null) ||
        (purpose == null)) {
      _logger.severe(
          "The form should not be valid since there are not set form fields");
      return false;
    }

    final creditor = Creditor(
        name: Name(value: creditorName),
        id: CreditorID(value: creditorId),
        iban: IBAN(value: creditorIban));

    final Future<String> sepaContent =
        _generateSepaContent(messageId, creditor, member, amount, purpose);
    final Future<String?> outputPath = _askUserForOutputPath();

    return _writeContentToPath(sepaContent, outputPath)
        .then((final bool wasWritten) async {
      if (!wasWritten) {
        return false;
      }

      await saveProfile(
        profile: Profile(
          creditor: backend_api.Creditor(
            name: backend_api.Name(value: creditorName),
            id: backend_api.CreditorID(value: creditorId),
            iban: backend_api.IBAN(value: creditorIban),
          ),
        ),
      );
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messageIdField = MessageIdField();
    final currencyField = CurrencyField();
    final purposeField = PurposeField();
    final creditorNameField = CreditorNameField();
    final creditorIbanField = CreditorIbanField();
    final creditorIdField = CreditorIdField();

    loadProfile().then(
      (final Profile? profile) {
        if (profile == null) {
          return;
        }

        final FormBuilderState formState = _formKey.currentState!;
        formState.fields[creditorNameField.name]
            ?.didChange(profile.creditor.name.value);
        formState.fields[creditorIbanField.name]
            ?.didChange(profile.creditor.iban.value);
        formState.fields[creditorIdField.name]
            ?.didChange(profile.creditor.id.value);
      },
    );

    return Scaffold(
      body: Column(
        children: [
          FormBuilder(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              children: [
                Text(Localizer.instance.text(
                    (l) => l.numMembersSelected(numSelected: member.length))),
                messageIdField,
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
                        messageIdField,
                        creditorNameField,
                        creditorIbanField,
                        creditorIdField,
                        currencyField,
                        purposeField)
                    .then(
                  (final bool submitted) {
                    if (submitted && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
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
