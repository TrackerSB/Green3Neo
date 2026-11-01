import 'package:flutter/widgets.dart';

import 'package:green3neo/features/frontend_feature.dart';

abstract class WidgetFeature<WidgetType extends Widget>
    extends FrontendFeature {
  // Do not access the widget directly
  WidgetType get widget;
}
