import 'package:flutter/foundation.dart';

import 'package:graphview/GraphView.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/features/widget_feature.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:listen_it/listen_it.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:watch_it/watch_it.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("feature_view");

class _GraphNode extends WatchingWidget {
  // FIXME Specify meaningful placeholder text
  final nodeText = ValueNotifier<String>("unknown");
  final Feature feature;
  final FeatureDescription description;
  final featureEnabled = ValueNotifier<bool>(false);
  late final ValueListenable<Color> backgroundColor;
  late final ValueListenable<Color> fontColor;

  _GraphNode.create({
    super.key,
    required this.feature,
    required this.description,
    required bool enableFeature,
  }) {
    backgroundColor = featureEnabled.map((bool enabled) {
      return description.isSystemFeature
          ? (enabled
                ? Colors.lightBlue
                : const Color.fromARGB(255, 61, 97, 114))
          : (enabled ? Colors.pink : const Color.fromARGB(255, 172, 112, 132));
    });
    fontColor = backgroundColor.map((Color color) {
      // FIXME Adapt to background color
      return Colors.black;
    });
    featureEnabled.value = enableFeature;
  }

  @override
  Widget build(BuildContext context) {
    nodeText.value = description.name;

    return GestureDetector(
      child: SizedBox(
        // FIXME Determine suitable size of nodes
        width: 180,
        height: 40,
        child: Container(
          decoration: BoxDecoration(color: watch(backgroundColor).value),
          padding: EdgeInsets.all(5),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                watch(nodeText).value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(color: watch(fontColor).value),
              ),
            ),
          ),
        ),
      ),
      onTap: () => featureEnabled.value = !featureEnabled.value,
    );
  }
}

Future<Map<Feature, FeatureDescription>> _loadDescriptions() async {
  final descriptions = <Feature, FeatureDescription>{};
  for (final Feature feature in Feature.values) {
    descriptions[feature] = await getFeatureDescription(feature: feature);
  }

  return descriptions;
}

bool _isValidEdge(
  Graph graph,
  Feature sourceFeature,
  Feature destinationFeature,
  Node? source,
  Node? destination,
) {
  // Disallow automatic (and silent) creation of source nodes
  if (source == null) {
    _logger.warning("Ignore dependency with unknown source $sourceFeature");
    return false;
  }

  // Disallow automatic (and silent) creation of destination nodes
  if (destination == null) {
    _logger.warning(
      "Ignore dependency with unknown dependecy $destinationFeature",
    );
    return false;
  }

  // Disallow self-dependencies (since unsupported by Sugiyama)
  if (source == destination) {
    _logger.warning(
      "Ignore self dependency $sourceFeature -> $destinationFeature",
    );
    return false;
  }

  // Disallow duplicated edges (since unsupported by Sugiyama)
  if (graph.getEdgeBetween(source, destination) != null) {
    _logger.warning(
      "Ignore duplicate dependency $sourceFeature -> $destinationFeature",
    );
    return false;
  }

  return true;
}

class _FeatureSettingsView extends StatelessWidget {
  final Map<Feature, FeatureDescription> descriptions;
  final profileFeatures = ListNotifier<Feature>();

  _FeatureSettingsView({
    super.key,
    required this.descriptions,
    required initialFeatures,
  }) {
    profileFeatures.addAll(initialFeatures);
  }

  @override
  Widget build(BuildContext context) {
    final featureToNode = <Feature, Node>{};

    for (final entry in descriptions.entries) {
      featureToNode[entry.key] = Node.Id(entry);
    }

    final graph = Graph();

    for (final entry in descriptions.entries) {
      final sourceNode = featureToNode[entry.key];

      if (sourceNode == null) {
        _logger.warning("Skip feature without associated source");
        continue;
      } else {
        graph.addNode(sourceNode);
      }

      for (final dependency in entry.value.dependencies) {
        final destinationNode = featureToNode[dependency];
        if (_isValidEdge(
          graph,
          entry.key,
          dependency,
          sourceNode,
          destinationNode,
        )) {
          graph.addEdge(sourceNode, destinationNode!);
        }
      }
    }

    final algorithmConfig = SugiyamaConfiguration()
      ..nodeSeparation = 20
      ..levelSeparation = 40
      ..bendPointShape = MaxCurvedBendPointShape()
      ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT;
    final algorithm = SugiyamaAlgorithm(algorithmConfig);

    final graphViewController = GraphViewController();

    final graphView = GraphView.builder(
      graph: graph,
      algorithm: algorithm,
      builder: (node) {
        final nodeEntry = node.key?.value;
        final feature = nodeEntry.key;
        final description = nodeEntry.value;

        final graphNode = _GraphNode.create(
          feature: feature,
          description: description,
          // FIXME Handle system features
          enableFeature: profileFeatures.contains(feature),
        );

        graphNode.featureEnabled.addListener(() {
          if (graphNode.featureEnabled.value) {
            // FIXME Make features a set instead of a list
            if (!profileFeatures.contains(feature)) {
              profileFeatures.add(feature);
            }
          } else {
            profileFeatures.remove(feature);
          }
        });

        return graphNode;
      },
      controller: graphViewController,
      autoZoomToFit: true,
      centerGraph: true,
      animated: true,
    );

    return GestureDetector(
      child: graphView,
      onDoubleTap: () => graphViewController.zoomToFit(),
    );
  }
}

class _PreloadingData {
  Map<Feature, FeatureDescription>? descriptions;
  LoadedProfile? profile;
}

class FeatureSettingsPage extends StatelessWidget {
  FeatureSettingsPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    final requiredDataFuture = Future.value(_PreloadingData())
        .then((data) async {
          data.descriptions = await _loadDescriptions();

          final getIt = GetIt.instance;
          data.profile = await getIt.getAsync<LoadedProfile>();

          return data;
        });

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<_PreloadingData>(
        future: requiredDataFuture,
        builder:
            (BuildContext context, AsyncSnapshot<_PreloadingData> snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                  return Center(child: CircularProgressIndicator.adaptive());
                case ConnectionState.active:
                case ConnectionState.none:
                case ConnectionState.done:
                  if (snapshot.hasError) {
                    throw UnimplementedError();
                  } else {
                    final snapshotData = snapshot.data!;

                    return _FeatureSettingsView(
                      descriptions: snapshotData.descriptions!,
                      initialFeatures: snapshotData.profile!.features,
                    );
                  }
              }
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
