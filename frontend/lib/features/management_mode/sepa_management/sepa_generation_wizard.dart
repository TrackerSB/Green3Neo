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

class _AmountField extends StatelessWidget {
  final _amount = ValueNotifier<double?>(null);

  ValueNotifier<double?> get amount => _amount;

  @override
  Widget build(BuildContext context) {
    final requiredDoubleFormat =
        RegExp(r"^[1-9][0-9]*([,|\.][0-9]+)?$", caseSensitive: false);

    return TextFormField(
      decoration: InputDecoration(
        labelText: Localizer.instance.text((l) => l.amount(unit: "€")),
        border: OutlineInputBorder(),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if ((value == null) || !requiredDoubleFormat.hasMatch(value)) {
          return Localizer.instance.text((l) => l.invalidAmount(unit: "€"));
        }
        return null;
      },
      onSaved: (final String? value) =>
          _amount.value = value == null ? null : double.tryParse(value),
    );
  }
}

class _PurposeField extends StatelessWidget {
  final _purpose = ValueNotifier<String>("");

  ValueNotifier<String> get purpose => _purpose;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: Localizer.instance.text((l) => l.purpose),
        border: OutlineInputBorder(),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (final String? value) {
        // FIXME Introduce regex in backend and call match function in frontend
        if ((value == null) || (value == "")) {
          return Localizer.instance.text((l) => l.invalidPurpose);
        }
        return null;
      },
      onSaved: (final String? value) => _purpose.value = value ?? "",
    );
  }
}

Future<String> _generateSepaContent(
    final List<Member> member, final double value, final String purpose) {
  // FIXME Make creditor configurable
  const creditor = Creditor(
      name: "Collecting collective",
      id: "DE98ZZZ09999999999",
      iban: "DE07123412341234123412");
  final transactions = member.map(
    (final Member m) {
      final mandate = Mandate(
        id: m.membershipid.toString(),
        // FIXME Use correct date of signature
        dateOfSignature: DateTime.utc(2023, 5, 1),
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
      collectionDate: DateTime.now(),
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

  void _onOkButtonPressed(final _AmountField amountField,
      final _PurposeField purposeField, final BuildContext context) async {
    final FormState formState = _formKey.currentState!;

    if (!formState.validate()) {
      return;
    }

    formState.save();

    final double? amount = amountField.amount.value;
    if (amount == null) {
      _logger.severe("The form should not be valid if there is no amount");
      return;
    }

    final Future<String> sepaContent =
        _generateSepaContent(member, amount, purposeField.purpose.value);
    final Future<String?> outputPath = _askUserForOutputPath();

    await _writeContentToPath(sepaContent, outputPath);

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountField = _AmountField();
    final purposeField = _PurposeField();

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
                purposeField,
                amountField,
              ],
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () =>
                    _onOkButtonPressed(amountField, purposeField, context),
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
