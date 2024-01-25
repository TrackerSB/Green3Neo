import 'package:flutter/material.dart';
import 'package:green3neo/api.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

class DataTablePageState extends State<DataTablePage> {
  final _tableViewState = TableViewState<Member>();

  DataTablePageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    getDummyMember().then((member) => setState(() {
          _tableViewState.setData(List<Member>.of(<Member>[member]));
        }));
  }

  void _commitDataChanges() {
    // TODO Implement
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
