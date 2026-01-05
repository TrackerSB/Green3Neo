import 'package:flutter/material.dart';
import 'package:green3neo/features/feature.dart';

abstract interface class WidgetFeature<WidgetType extends Widget> implements Feature {
  WidgetType get widget;
}
