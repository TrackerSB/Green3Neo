import 'package:green3neo/features/feature.dart';
import 'package:watch_it/watch_it.dart';

abstract interface class ManagementMode implements Feature {
  String get modeName;
  WatchingWidget get widget;
}
