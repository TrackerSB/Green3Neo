import 'package:flutter/material.dart';
import 'package:green3neo/features/feature.dart';

abstract interface class WidgetFeature implements Feature {
  StatelessWidget get widget;
}
