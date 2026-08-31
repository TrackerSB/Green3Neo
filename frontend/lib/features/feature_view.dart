import 'package:flutter/widgets.dart';

import 'package:green3neo/features/widget_feature.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:watch_it/watch_it.dart';

class FeatureSettingsPage extends WatchingWidget {
  FeatureSettingsPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    return Text("HERE");
  }
}

class FeatureSettings extends WidgetFeature {
  FeatureSettingsPage? instance;

  @override
  void registerUnconditionally() {
    final getIt = GetIt.instance;
    getIt.registerLazySingleton<FeatureSettings>(() => FeatureSettings());
  }

  @override
  Feature requiredFeature() {
    return Feature.featureSettings;
  }

  @override
  FeatureSettingsPage get widget {
    instance ??= FeatureSettingsPage._create();
    return instance!;
  }
}
