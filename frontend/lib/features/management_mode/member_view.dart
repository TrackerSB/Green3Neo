import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/components/table_view.dart';
import 'package:green3neo/database_api/api/member.dart';
import 'package:green3neo/database_api/api/models.dart';
import 'package:green3neo/features/feature.dart';
import 'package:provider/provider.dart';

class MemberView extends StatelessWidget {
  final TableViewSource<Member> tableViewSource;

  // ignore: unused_element_parameter
  const MemberView._create({super.key, required this.tableViewSource});

  Future<bool> forceReloadDataFromDB() {
    return getAllMembers().then(
      (members) {
        // FIXME Warn about state not being initialized yet
        tableViewSource.content.clear();
        if (members == null) {
          // FIXME Provide error message
          return false;
        }

        tableViewSource.content.addAll(members);
        return true;
      },
    );
  }

  static Widget _wrapInScrollable(Widget toWrap, Axis direction) {
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
    // FIXME Visualize failed reload
    forceReloadDataFromDB();

    return Expanded(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: _wrapInScrollable(
          _wrapInScrollable(
            SizedBox(
              width: 2000, // FIXME Determine required width for table
              child: ChangeNotifierProvider(
                create: (_) => tableViewSource,
                child: const TableView<Member>(),
              ),
            ),
            Axis.horizontal,
          ),
          Axis.vertical,
        ),
      ),
    );
  }
}

class MemberViewFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerCachedFactoryParam<MemberView, TableViewSource<Member>, void>(
        (tableViewSource, _) =>
            MemberView._create(tableViewSource: tableViewSource));
  }
}
