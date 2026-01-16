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
    );
  }
}

Future<String> _generateSepaContent() {
  // FIXME Make fields configurable
  const creditor = Creditor(
      name: "Collecting collective",
      id: "DE98ZZZ09999999999",
      iban: "DE07123412341234123412");
  final transactions = [
    Transaction(
      debitor: Debitor(
        name: "Paying Paula",
        iban: "DE89370400440532013000",
        mandate: Mandate(
          id: "42",
          dateOfSignature: DateTime.utc(2023, 5, 1),
        ),
      ),
      purpose: "contribution",
      value: 42.0,
    ),
  ];
  return generateSepaDocument(
      messageId: "2026-01-09_FancyMessageID",
      collectionDate: DateTime.now(),
      creditor: creditor,
      transactions: transactions);
}

Future<String?> _askUserForOutputPath() {
  final Future<String?> downloadDir =
      getDownloadsDirectory().then((dir) => dir?.absolute.path);

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

  void _onOkButtonPressed() async {
    final Future<String> sepaContent = _generateSepaContent();
    final Future<String?> outputPath = _askUserForOutputPath();

    final Future<void> generationResult =
        _writeContentToPath(sepaContent, outputPath);

    await generationResult;
  }

  @override
  Widget build(BuildContext context) {
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
                _AmountField(),
              ],
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  _onOkButtonPressed();
                  Navigator.pop(context);
                },
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
