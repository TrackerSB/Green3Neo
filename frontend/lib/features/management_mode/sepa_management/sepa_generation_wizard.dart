import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/components/form_fields/creditor_iban_field.dart';
import 'package:green3neo/components/form_fields/creditor_id_field.dart';
import 'package:green3neo/components/form_fields/creditor_name_field.dart';
import 'package:green3neo/components/form_fields/currency_field.dart';
import 'package:green3neo/components/form_fields/message_id_field.dart';
import 'package:green3neo/components/form_fields/purpose_field.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/interface/backend_api/api/paths.dart';
import 'package:green3neo/interface/database_api/api/models.dart';
import 'package:green3neo/interface/sepa_api/api/creditor.dart';
import 'package:green3neo/interface/sepa_api/api/debitor.dart';
import 'package:green3neo/interface/sepa_api/api/generation.dart';
import 'package:green3neo/interface/sepa_api/api/transaction.dart';
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
      messageId: messageId,
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
      final MessageIdField messageIdField,
      final CreditorNameField creditorNameField,
      final CreditorIbanField creditorIbanField,
      final CreditorIdField creditorIdField,
      final CurrencyField currencyField,
      final PurposeField purposeField,
      final BuildContext context) async {
    final FormState formState = _formKey.currentState!;

    if (!formState.validate()) {
      return;
    }

    formState.save();

    final String? messageId = messageIdField.value.value;
    final double? amount = currencyField.value.value;
    final String? creditorName = creditorNameField.value.value;
    final String? creditorIban = creditorIbanField.value.value;
    final String? creditorId = creditorIdField.value.value;
    final String? purpose = purposeField.value.value;
    if ((messageId == null) ||
        (amount == null) ||
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
        _generateSepaContent(messageId, creditor, member, amount, purpose);
    final Future<String?> outputPath = _askUserForOutputPath();

    await _writeContentToPath(sepaContent, outputPath);

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageIdField = MessageIdField();
    final currencyField = CurrencyField();
    final purposeField = PurposeField();
    final creditorNameField = CreditorNameField();
    final creditorIbanField = CreditorIbanField();
    final creditorIdField = CreditorIdField();

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
