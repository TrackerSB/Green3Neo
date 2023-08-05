import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';
import 'ffi.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

class DataTablePageState extends State<DataTablePage> {
  final TableViewState tableViewState = TableViewState();

  DataTablePageState() {
    updateDataFromDB();
  }

  void updateDataFromDB() {
    backendApi.getMemberData().then((memberData) {
      setState(() {
        tableViewState.setData(memberData);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center ,
          children: [
            ElevatedButton(
              onPressed: updateDataFromDB,
              child: const Text("Update data"),
            )
          ],
        ),
        ChangeNotifierProvider(
          create: (_) => tableViewState,
          child: const TableView(),
        ),
      ],
    );
  }
}
