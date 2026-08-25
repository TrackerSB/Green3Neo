import 'package:flutter/widgets.dart';

import 'package:green3neo/features/frontend_feature.dart';

abstract interface class WidgetFeature<WidgetType extends Widget>
    implements FrontendFeature {
  WidgetType get widget;
}
