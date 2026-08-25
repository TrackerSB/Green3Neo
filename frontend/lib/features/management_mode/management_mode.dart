import 'package:flutter/widgets.dart';

import 'package:green3neo/features/widget_feature.dart';

abstract class ManagementMode<WidgetType extends Widget>
    extends WidgetFeature<WidgetType> {
  String get modeName;
}
