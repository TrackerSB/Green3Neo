import 'package:graphview/GraphView.dart';
import 'package:green3neo/features/widget_feature.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:watch_it/watch_it.dart';

// FIXME Determine DART file name automatically
final _logger = Logger("feature_view");

class _GraphNode extends WatchingWidget {
  // FIXME Specify meaningful placeholder text
  final nodeText = ValueNotifier<String>("unknown");
  final FeatureDescription nodeValue;

  _GraphNode.create({super.key, required this.nodeValue});

  @override
  Widget build(BuildContext context) {
    nodeText.value = nodeValue.name;

    final backgroundColor = nodeValue.isSystemFeature
        ? Colors.indigo
        : Colors.pink;

    return SizedBox(
      // FIXME Determine suitable size of nodes
      width: 180,
      height: 40,
      child: Container(
        decoration: BoxDecoration(color: backgroundColor),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              watch(nodeText).value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: Color.from(
                  alpha: 1,
                  red: 1 - backgroundColor.r,
                  green: 1 - backgroundColor.g,
                  blue: 1 - backgroundColor.b,
                ),
              ),
            ),
          ),
        ),
      ),
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

Widget _createGraph(Map<Feature, FeatureDescription> descriptions) {
  final featureToNode = <Feature, Node>{};

  for (final entry in descriptions.entries) {
    featureToNode[entry.key] = Node.Id(entry.value);
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

  return GraphView.builder(
    graph: graph,
    algorithm: algorithm,
    builder: (node) => _GraphNode.create(
      nodeValue:
          // FIXME Warn about null values in nodes
          node.key?.value ??
          FeatureDescription(
            name: "nullPlaceholder",
            dependencies: [],
            isSystemFeature: true,
          ),
    ),
    autoZoomToFit: true,
    centerGraph: true,
    animated: true,
  );
}

class FeatureSettingsPage extends StatelessWidget {
  FeatureSettingsPage._create({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Map<Feature, FeatureDescription>>(
        future: _loadDescriptions(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<Feature, FeatureDescription>> snapshot,
            ) {
              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                  return Center(child: CircularProgressIndicator.adaptive());
                case ConnectionState.active:
                case ConnectionState.none:
                case ConnectionState.done:
                  if (snapshot.hasError) {
                    throw UnimplementedError();
                  } else {
                    return _createGraph(snapshot.data!);
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
