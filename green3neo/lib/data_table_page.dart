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
  final _tableViewState =
      TableViewState<Member>(getMemberConnection());

  DataTablePageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    getMemberConnection().then((connection) {
      final data = MemberConnection.getData();
      data.then((d) {
        setState(() {
          _tableViewState.setData(d);
        });
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
