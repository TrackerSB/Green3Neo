import 'package:flutter/material.dart';
import 'package:green3neo/features/widget_feature.dart';

abstract interface class ManagementMode<WidgetType extends Widget>
    implements WidgetFeature<WidgetType> {
  String get modeName;
}
