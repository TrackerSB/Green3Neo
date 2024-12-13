import 'package:flutter/material.dart';
import 'package:green3neo/backend/api/dummy.dart';
import 'package:green3neo/backend/models.dart';
import 'package:provider/provider.dart';
import 'table_view.dart';

class DataTablePage extends StatefulWidget {
  const DataTablePage({super.key});

  @override
  State<StatefulWidget> createState() => DataTablePageState();
}

class DataTablePageState extends State<DataTablePage> {
  TableViewSource<Member>? _tableViewState;

  DataTablePageState() {
    _receiveDataFromDB();
  }

  void _receiveDataFromDB() {
    getDummyMembers().then(
      (members) => setState(
        () {
          // FIXME Warn about state not being initialized yet
          if (members == null) {
            // FIXME Provide error message
            _tableViewState?.setData(List.empty());
          } else {
            _tableViewState?.setData(members);
          }
        },
      ),
    );
  }

  void _commitDataChanges() {
    // TODO Implement
  }

  Widget _wrapInScrollable(Widget toWrap, Axis direction) {
    var scrollController = ScrollController();

    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: direction,
        child: toWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _tableViewState = TableViewSource<Member>(context);

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
        Expanded(
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: true),
            child: _wrapInScrollable(
              _wrapInScrollable(
                SizedBox(
                  width: 2000, // FIXME Determine required width for table
                  child: ChangeNotifierProvider(
                    create: (_) => _tableViewState,
                    child: const TableView<Member>(),
                  ),
                ),
                Axis.horizontal,
              ),
              Axis.vertical,
            ),
          ),
        ),
      ],
    );
  }
}
