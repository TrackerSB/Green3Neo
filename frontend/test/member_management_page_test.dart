import 'package:flutter_test/flutter_test.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/change_record_utility.dart';

class MergeChangeRecordsTestCase {
  final List<ChangeRecord> initialRecords;
  final List<ChangeRecord> mergedRecords;

  MergeChangeRecordsTestCase(
      {required this.initialRecords, required this.mergedRecords});
}

Map<String, MergeChangeRecordsTestCase> goodMergeTestCases = {
  "empty": MergeChangeRecordsTestCase(
      initialRecords: List.empty(), mergedRecords: List.empty()),
  "single": MergeChangeRecordsTestCase(initialRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 1,
        previousValue: "Ritson",
        newValue: "Smith")
  ], mergedRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 1,
        previousValue: "Ritson",
        newValue: "Smith"),
  ]),
  "multiple": MergeChangeRecordsTestCase(initialRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 1,
        previousValue: "Ritson",
        newValue: "Smith"),
    ChangeRecord(
        column: "surname",
        membershipid: 2,
        previousValue: "Clears",
        newValue: "Johnson"),
  ], mergedRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 1,
        previousValue: "Ritson",
        newValue: "Smith"),
    ChangeRecord(
        column: "surname",
        membershipid: 2,
        previousValue: "Clears",
        newValue: "Johnson"),
  ]),
  "transitive": MergeChangeRecordsTestCase(initialRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 3,
        previousValue: "Bliven",
        newValue: "Green"),
    ChangeRecord(
        column: "surname",
        membershipid: 3,
        previousValue: "Green",
        newValue: "Red"),
  ], mergedRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 3,
        previousValue: "Bliven",
        newValue: "Red"),
  ]),
  "mismatch original": MergeChangeRecordsTestCase(initialRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 101,
        previousValue: "NotAdds",
        newValue: "AnotherSurname"),
  ], mergedRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 101,
        previousValue: "NotAdds",
        newValue: "AnotherSurname"),
  ]),
  // FIXME What about changing primary key values?
};

Map<String, MergeChangeRecordsTestCase> badMergeTestCases = {
  "transitive mismatch previous": MergeChangeRecordsTestCase(initialRecords: [
    ChangeRecord(
        column: "surname",
        membershipid: 100,
        previousValue: "Hargitt",
        newValue: "Green"),
    ChangeRecord(
        column: "surname",
        membershipid: 100,
        previousValue: "NotGreen",
        newValue: "Red"),
  ], mergedRecords: []),
};

void main() {
  testWidgets("Verify merging valid change records", (tester) async {
    for (final testCase in goodMergeTestCases.entries) {
      final name = testCase.key;
      final initialRecords = testCase.value.initialRecords;
      final expectedMergedRecords = testCase.value.mergedRecords;

      final actualMergedRecords = mergeChangeRecords(initialRecords);

      expect(actualMergedRecords, expectedMergedRecords,
          reason: "Test case: '$name' failed");
    }
  });

  testWidgets("Verify merging invalid change records or sequences",
      (tester) async {
    for (final testCase in badMergeTestCases.entries) {
      final name = testCase.key;
      final initialRecords = testCase.value.initialRecords;
      final expectedMergedRecords = testCase.value.mergedRecords;
      assert(expectedMergedRecords.isEmpty);

      // FIXME Should a custom exception be used here?
      expect(
          () => mergeChangeRecords(initialRecords), throwsA(isA<Exception>()),
          reason: "Test case: '$name' failed");
    }
  });
}
