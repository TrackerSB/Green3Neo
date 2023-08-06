import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';
import 'ffi.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

class Member {
  Member(this.id, this.prename, this.surname);

  int id;
  String prename;
  String surname;
}

class DataRetriever<DataObject> {
  DataRetriever(this.retrievers);
  Map<String, dynamic Function(DataObject)> retrievers;
}

class DataTablePageState extends State<DataTablePage> {
  final _tableViewState =
      TableViewState<Member>(DataRetriever<Member>(Map.fromEntries([
    MapEntry("Nummer", (member) => member.id),
    MapEntry("Vorname", (member) => member.prename),
    MapEntry("Nachname", (member) => member.surname)
  ])));

  DataTablePageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    backendApi.getMemberData().then((data) {
      final List<Member> memberData = [];

      // Skip headings assuming the order of columns
      for (final row in data.skip(1)) {
        memberData.add(Member(
            int.parse(row.elementAt(0)), row.elementAt(1), row.elementAt(2)));
      }

      setState(() {
        _tableViewState.setData(memberData);
      });
    });
  }

  void _commitDataChanges() {
    // backendApi.applyMemberDataChanges(_tableViewState.getChanges());
    // TODO
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _receiveDataFromDB,
              child: const Text("Update data"),
            ),
            ElevatedButton(
              onPressed: _commitDataChanges,
              child: const Text("Commit changes"),
            ),
          ],
        ),
        ChangeNotifierProvider(
          create: (_) => _tableViewState,
          child: const TableView<Member>(),
        ),
      ],
    );
  }
}
