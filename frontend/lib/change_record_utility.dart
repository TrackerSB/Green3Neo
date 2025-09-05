import 'package:flutter/material.dart';
import 'package:green3neo/database_api/api/member.dart';

void commitDataChanges(List<ChangeRecord> changeRecords) {
  // Copy list for improved thread safety
  final List<ChangeRecord> records = changeRecords.toList();
  changeRecords.clear();
  changeMember(changes: records).then(
    (succeededUpdateIndices) {
      succeededUpdateIndices.sort();
      for (final BigInt index in succeededUpdateIndices.reversed) {
        records.removeAt(index.toInt());
      }

      // Add records that failed to update back to the list
      changeRecords.addAll(records);
    },
  );
}

Widget visualizeChanges(List<ChangeRecord> changeRecords) {
  return Table(
    children: [
      const TableRow(
        children: [
          // FIXME Localize texts
          Text("Membership ID"),
          Text("Column"),
          Text("Previous Value"),
          Text("New Value"),
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
    final int existingRecordIndex = mergedChangeRecords.indexWhere((r) =>
        r.membershipid == record.membershipid && r.column == record.column);
    if (existingRecordIndex < 0) {
      mergedChangeRecords.add(record);
    } else {
      final existingRecord = mergedChangeRecords[existingRecordIndex];
      if (existingRecord.previousValue == record.newValue) {
        // Remove identity record
        mergedChangeRecords.removeAt(existingRecordIndex);
      } else {
        // Update existing record with new value
        // FIXME Assert previous value of existing record and new record are the same
        mergedChangeRecords[existingRecordIndex] = ChangeRecord(
          membershipid: existingRecord.membershipid,
          column: existingRecord.column,
          previousValue: existingRecord.previousValue,
          newValue: record.newValue,
        );
      }
    }
  }

  return mergedChangeRecords;
}
