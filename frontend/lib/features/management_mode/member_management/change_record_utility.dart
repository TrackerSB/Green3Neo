import 'package:flutter/material.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/interface/database_api/api/member.dart';
import 'package:green3neo/localizer.dart';

Future<bool> commitDataChanges(List<ChangeRecord> changeRecords) async {
  // Copy list for improved thread safety
  final List<ChangeRecord> records = changeRecords.toList();
  changeRecords.clear();

  final getIt = GetIt.instance;
  final LoadedProfile profile = await getIt.getAsync<LoadedProfile>();

  if (profile.connection == null) {
    return false;
  }

  final Uint64List succeededUpdateIndices =
      await changeMember(connection: profile.connection!, changes: records);

  succeededUpdateIndices.sort();
  for (final BigInt index in succeededUpdateIndices.reversed) {
    records.removeAt(index.toInt());
  }

  // Add records that failed to update back to the list
  changeRecords.addAll(records);

  return true;
}

Widget visualizeChanges(
    BuildContext context, List<ChangeRecord> changeRecords) {
  return Table(
    children: [
      TableRow(
        children: [
          // FIXME Localize texts
          Text("Membership ID"),
          Text(Localizer.instance.text((l) => l.column)),
          Text(Localizer.instance.text((l) => l.previousValue)),
          Text(Localizer.instance.text((l) => l.newValue)),
        ],
      ),
      for (final record in changeRecords)
        TableRow(
          children: [
            Text(record.membershipid.toString()),
            Text(record.column),
            Text(record.previousValue ?? "null"),
            Text(record.newValue ?? "null"),
          ],
        ),
    ],
  );
}

List<ChangeRecord> mergeChangeRecords(List<ChangeRecord> changeRecords) {
  // Merge changes of same membershipid and column removing identity records
  List<ChangeRecord> mergedChangeRecords = [];

  for (final record in changeRecords) {
    final int existingMergeRecordIndex = mergedChangeRecords.indexWhere((r) =>
        r.membershipid == record.membershipid && r.column == record.column);

    if (existingMergeRecordIndex < 0) {
      mergedChangeRecords.add(record);
    } else {
      final existingMergeRecord = mergedChangeRecords[existingMergeRecordIndex];
      if (existingMergeRecord.previousValue == record.newValue) {
        // Remove identity record
        mergedChangeRecords.removeAt(existingMergeRecordIndex);
      } else {
        // Update existing record with new value
        if (record.previousValue != existingMergeRecord.newValue) {
          throw Exception(
              "Record changes (membershipid: ${record.membershipid}, "
              "column: ${record.column}) do not match. Previous changed "
              "from '${existingMergeRecord.previousValue}' to "
              "'${existingMergeRecord.newValue}', next is expected to change "
              "from '${record.previousValue}' to '${record.newValue}'");
        }

        mergedChangeRecords[existingMergeRecordIndex] = ChangeRecord(
          membershipid: existingMergeRecord.membershipid,
          column: existingMergeRecord.column,
          previousValue: existingMergeRecord.previousValue,
          newValue: record.newValue,
        );
      }
    }
  }

  return mergedChangeRecords;
}
