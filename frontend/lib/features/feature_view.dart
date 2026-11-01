import 'dart:collection';

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
  final _ProfileFeatureState featureState;
  late final ValueListenable<Color> backgroundColor;
  late final ValueListenable<Color> fontColor;

  _GraphNode.create({required this.featureState}) {
    backgroundColor = featureState.featureEnabled.map((bool enabled) {
      return featureState.description.isSystemFeature
          ? (enabled
                ? Colors.lightBlue
                : const Color.fromARGB(255, 61, 97, 114))
          : (enabled ? Colors.pink : const Color.fromARGB(255, 172, 112, 132));
    });
    fontColor = backgroundColor.map((Color color) {
      // FIXME Adapt to background color
      return Colors.black;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              child: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: featureState.featureDependencyRequested,
                    builder: (innerContext, value, child) {
                      return value
                          ? Icon(Icons.lock, color: Colors.brown)
                          : SizedBox.shrink();
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: featureState.featureUserRequested,
                    builder: (innerContext, value, child) {
                      return value
                          ? Icon(Icons.check, color: Colors.green)
                          : SizedBox.shrink();
                    },
                  ),
                  Text(
                    featureState.description.name,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(color: watch(fontColor).value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      onTap: () => featureState.featureUserRequested.value =
          !featureState.featureUserRequested.value,
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

class _ProfileFeatureState {
  final FeatureDescription description;
  final featureUserRequested = ValueNotifier<bool>(false);
  final featureDependencyRequested = ValueNotifier<bool>(false);
  late final ValueListenable<bool> featureEnabled;

  _ProfileFeatureState({
    required this.description,
    required bool initialUserRequested,
  }) {
    featureEnabled = featureUserRequested.combineLatest(
      featureDependencyRequested,
      (bool userRequested, bool dependencyRequested) =>
          userRequested || dependencyRequested,
    );

    featureUserRequested.value = initialUserRequested;
  }
}

class _FeatureSettingsView extends StatelessWidget {
  final profileFeatures = <Feature, _ProfileFeatureState>{};

  _FeatureSettingsView({
    required Map<Feature, FeatureDescription> descriptions,
    required List<Feature> initialFeatures,
  }) {
    for (final entry in descriptions.entries) {
      profileFeatures[entry.key] = _ProfileFeatureState(
        description: entry.value,
        initialUserRequested: initialFeatures.contains(entry.key),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final featureToNode = <Feature, Node>{};

    final graph = Graph();

    for (final entry in profileFeatures.entries) {
      final node = Node.Id(entry.value);

      featureToNode[entry.key] = node;
      graph.addNode(node);
    }

    for (final entry in profileFeatures.entries) {
      final Node? sourceNode = featureToNode[entry.key];

      if (sourceNode == null) {
        _logger.warning(
          "Skipping feature ${entry.key} since there is no node representing it",
        );
        continue;
      }

      for (final dependency in entry.value.description.dependencies) {
        final Node? destinationNode = featureToNode[dependency];

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

    _ProfileFeatureState getStateOfNode(Node n) {
      return n.key?.value;
    }

    void updateFeatureDependencyRequestedStates(Node startNode) {
      final nodesToCheck = Queue<Node>();
      nodesToCheck.addAll(graph.successorsOf(startNode));

      while (nodesToCheck.isNotEmpty) {
        final Node currentNode = nodesToCheck.removeFirst();
        final List<Node> currentNodePredecessors = graph.predecessorsOf(
          currentNode,
        );
        final Iterable<_ProfileFeatureState> currentNodePredecessorStates =
            currentNodePredecessors.map(getStateOfNode);
        final _ProfileFeatureState currentNodeState = getStateOfNode(
          currentNode,
        );
        currentNodeState.featureDependencyRequested.value =
            currentNodePredecessorStates.any((s) {
              return s.featureEnabled.value;
            });
      }
    }

    // Ensure initial state
    for (final Node node in graph.nodes) {
      updateFeatureDependencyRequestedStates(node);
    }

    final graphView = GraphView.builder(
      graph: graph,
      algorithm: algorithm,
      builder: (node) {
        final _ProfileFeatureState featureState = getStateOfNode(node);

        final graphNode = _GraphNode.create(featureState: featureState);

        featureState.featureEnabled.addListener(() {
          updateFeatureDependencyRequestedStates(node);
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

class PreloadingData {
  Map<Feature, FeatureDescription>? descriptions;
  LoadedProfile? profile;

  PreloadingData.create({required this.descriptions, required this.profile});
}

class FeatureSettingsPage extends StatelessWidget {
  final Future<PreloadingData> preloadingDataLoader;

  @visibleForTesting
  const FeatureSettingsPage.create({
    super.key,
    required this.preloadingDataLoader,
  });

  @override
  Widget build(BuildContext context) {
    LoadedProfile? currentChangedProfile;
    Map<Feature, _ProfileFeatureState>? profileFeatureStates;

    return Scaffold(
      appBar: AppBar(
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (currentChangedProfile == null ||
                  profileFeatureStates == null) {
                _logger.warning(
                  "Could not save profile since it's not been loaded",
                );
              } else {
                for (final entry in profileFeatureStates!.entries) {
                  /* Store only features as enabled that are explicitly
                   * requested by the user
                   */
                  if (entry.value.featureUserRequested.value) {
                    if (!currentChangedProfile!.features.contains(entry.key)) {
                      currentChangedProfile!.features.add(entry.key);
                    }
                  } else {
                    currentChangedProfile!.features.remove(entry.key);
                  }
                }
                await currentChangedProfile!.save();
              }
            },
            child: Text(MaterialLocalizations.of(context).saveButtonLabel),
          ),
        ],
      ),
      body: FutureBuilder<PreloadingData>(
        future: preloadingDataLoader,
        builder:
            (BuildContext context, AsyncSnapshot<PreloadingData> snapshot) {
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

                    currentChangedProfile = snapshotData.profile!;

                    final featureView = _FeatureSettingsView(
                      descriptions: snapshotData.descriptions!,
                      initialFeatures: currentChangedProfile!.features,
                    );

                    profileFeatureStates = featureView.profileFeatures;

                    return featureView;
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
    final getIt = GetIt.instance;
    instance ??= FeatureSettingsPage.create(
      preloadingDataLoader:
          Future.wait([_loadDescriptions(), getIt.getAsync<LoadedProfile>()])
              .then((List<Object> values) async {
                return PreloadingData.create(
                  descriptions:
                      values.elementAt(0) as Map<Feature, FeatureDescription>,
                  profile: values.elementAt(1) as LoadedProfile,
                );
              }),
    );
    return instance!;
  }
}
