import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/components/form_fields/creditor_iban_field.dart';
import 'package:green3neo/components/form_fields/creditor_id_field.dart';
import 'package:green3neo/components/form_fields/creditor_name_field.dart';
import 'package:green3neo/components/form_fields/currency_field.dart';
import 'package:green3neo/components/form_fields/message_id_field.dart';
import 'package:green3neo/components/form_fields/purpose_field.dart';
import 'package:green3neo/features/frontend_feature.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:green3neo/interface/backend_api/api/paths.dart';
import 'package:green3neo/interface/database_api/api/models.dart';
import 'package:green3neo/interface/sepa_api/api.dart';
import 'package:green3neo/interface/sepa_api/api/generation.dart';
import 'package:green3neo/localizer.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("sepa_generation_wizard");

Future<String> _generateSepaContent(
  MessageID messageId,
  Creditor creditor,
  List<Member> member,
  double value,
  Purpose purpose,
) {
  final transactions = member.map((Member m) {
    final mandate = Mandate(
      id: MandateID(value: m.membershipId.toString()),
      // FIXME Use correct date of signature
      dateOfSignatureUtc: DateTime.utc(2023, 5, 1),
    );
    final debitor = Debitor(
      name: Name(
        value:
            "${m.accountholderPrename ?? m.prename} ${m.accountholderSurname ?? m.surname}",
      ),
      iban: IBAN(value: m.iban),
      mandate: mandate,
    );
    return Transaction(debitor: debitor, value: value, purpose: purpose);
  }).toList();
  return generateSepaDocument(
    messageId: messageId,
    collectionDateUtc: DateTime.now().toUtc(),
    creditor: creditor,
    transactions: transactions,
  );
}

Future<Uri?> _saveOutputToPath(Uint8List outputBytes) {
  final Future<String> downloadDir = getUserDownloadDir();

  return downloadDir.then(
    (String? dir) => FilePicker.saveFile(
      fileName: "sepaOutput.xml", // FIXME Determine meaningful file name
      allowedExtensions: ["xml"],
      linuxOptions: LinuxOptions(lockParentWindow: true),
      type: FileType.custom,
      bytes: outputBytes,
      initialDirectory: dir,
    ),
    onError: (Object error, StackTrace trace) =>
        _logger.shout("Failed to ask user for save path", error, trace),
  );
}

Uint8List _convertContentToBytes(String content) {
  return Uint8List.fromList(content.codeUnits);
}

class SepaGenerationWizard extends StatelessWidget {
  final _formKey = GlobalKey<FormBuilderState>();
  final List<Member> member;

  SepaGenerationWizard._create({super.key, required this.member});

  Future<bool> _onOkButtonPressed(
    MessageIdField messageIdField,
    CreditorNameField creditorNameField,
    CreditorIbanField creditorIbanField,
    CreditorIdField creditorIdField,
    CurrencyField currencyField,
    PurposeField purposeField,
  ) async {
    final FormBuilderState formState = _formKey.currentState!;

    if (!formState.saveAndValidate()) {
      return false;
    }

    final MessageID? messageId = formState.getTransformedValue(
      messageIdField.name,
      fromSaved: true,
    );
    final double? amount = formState.getTransformedValue(
      currencyField.name,
      fromSaved: true,
    );
    final Name? creditorName = formState.getTransformedValue(
      creditorNameField.name,
      fromSaved: true,
    );
    final IBAN? creditorIban = formState.getTransformedValue(
      creditorIbanField.name,
      fromSaved: true,
    );
    final CreditorID? creditorId = formState.getTransformedValue(
      creditorIdField.name,
      fromSaved: true,
    );
    final Purpose? purpose = formState.getTransformedValue(
      purposeField.name,
      fromSaved: true,
    );

    if ((messageId == null) ||
        (amount == null) ||
        (creditorName == null) ||
        (creditorIban == null) ||
        (creditorId == null) ||
        (purpose == null)) {
      _logger.severe(
        "The form should not be valid since there are not set form fields",
      );
      return false;
    }

    final creditor = Creditor(
      name: creditorName,
      id: creditorId,
      iban: creditorIban,
    );

    final Future<String> sepaContent = _generateSepaContent(
      messageId,
      creditor,
      member,
      amount,
      purpose,
    );

    final Uint8List encodedContent = _convertContentToBytes(await sepaContent);
    final Future<Uri?> outputPathFuture = _saveOutputToPath(encodedContent);

    return outputPathFuture.then((Uri? outputPath) async {
      if (outputPath == null) {
        _logger.info("The user presumably aborted saving");
        return false;
      }

      final getIt = GetIt.instance;
      LoadedProfile profile = await getIt.getAsync<LoadedProfile>();

      profile = profile.copyWith(
        creditor: Creditor(
          name: creditorName,
          id: creditorId,
          iban: creditorIban,
        ),
      );

      await profile.save();

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

    final getIt = GetIt.instance;
    getIt.getAsync<LoadedProfile>().then((LoadedProfile profile) {
      final FormBuilderState formState = _formKey.currentState!;
      formState.fields[creditorNameField.name]?.didChange(
        profile.creditor?.name.value,
      );
      formState.fields[creditorIbanField.name]?.didChange(
        profile.creditor?.iban.value,
      );
      formState.fields[creditorIdField.name]?.didChange(
        profile.creditor?.id.value,
      );
    });

    return Scaffold(
      body: Column(
        children: [
          FormBuilder(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              children: [
                Text(
                  Localizer.instance.text(
                    (l) => l.numMembersSelected(numSelected: member.length),
                  ),
                ),
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
                onPressed: () =>
                    _onOkButtonPressed(
                      messageIdField,
                      creditorNameField,
                      creditorIbanField,
                      creditorIdField,
                      currencyField,
                      purposeField,
                    ).then((bool submitted) {
                      if (submitted && context.mounted) {
                        Navigator.pop(context);
                      }
                    }),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
              CloseButton(onPressed: () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class SepaGenerationWizardFactory implements FrontendFeature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerFactoryParam<SepaGenerationWizard, List<Member>, void>(
      (member, _) => SepaGenerationWizard._create(member: member),
    );
  }

  @override
  Feature requiredFeature() {
    return Feature.sepaGenerationWizard;
  }
}
