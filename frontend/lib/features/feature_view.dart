import 'package:flutter/material.dart';

import 'package:graphview/GraphView.dart';
import 'package:green3neo/features/widget_feature.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:watch_it/watch_it.dart';

class FeatureSettingsPage extends WatchingWidget {
  FeatureSettingsPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    final Node nodeA = Node.Id("nodeA");
    final Node nodeB = Node.Id("nodeB");

    var graph = Graph();
    graph.addEdge(nodeA, nodeB);

    final algorithmConfig = SugiyamaConfiguration()
      ..nodeSeparation = 15
      ..levelSeparation = 15
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;

    return Scaffold(
      body: GraphView.builder(
        graph: graph,
        algorithm: SugiyamaAlgorithm(algorithmConfig),
        builder: (node) {
          final nodeId = node.key!.value as String;
          return Container(
            decoration: BoxDecoration(color: Colors.blue),
            child: Center(child: Text(nodeId)),
          );
        },
      ),
    );
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
  Feature associatedFeature() {
    return Feature.featureSettings;
  }

  @override
  FeatureSettingsPage get widget {
    instance ??= FeatureSettingsPage._create();
    return instance!;
  }
}
