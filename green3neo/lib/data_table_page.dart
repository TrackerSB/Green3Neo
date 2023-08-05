import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data_view.dart';
import 'ffi.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

class DataTablePageState extends State<DataTablePage> {
  final TableViewState tableViewState = TableViewState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            final memberData = await backendApi.getMemberData();
            setState(() {
              tableViewState.setData(memberData);
            });
          },
          child: const Text("Retrieve data"),
        ),
        ChangeNotifierProvider(
          create: (_) => tableViewState,
          child: const TableView(),
        ),
      ],
    );
  }
}
