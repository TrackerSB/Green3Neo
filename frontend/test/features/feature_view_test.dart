import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';
import 'package:green3neo/features/feature_view.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpFeatureView(
  WidgetTester tester,
  Map<Feature, FeatureDescription> descriptions,
  List<Feature> enabledFeatures,
) async {
  final loader = Future<PreloadingData>.sync(() {
    final loadedProfile = LoadedProfile.create(features: enabledFeatures);
    final data = PreloadingData.create(
      descriptions: descriptions,
      profile: loadedProfile,
    );
    return data;
  });

  await tester.pumpWidget(
    MaterialApp(home: FeatureSettingsPage.create(preloadingDataLoader: loader)),
  );
  await tester.pumpAndSettle();
}

Finder findVisualNodeContent(String name) {
  // FIXME Verify there is only a single widget found
  return find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
}

Finder findVisualNodeTapTarget(String name) {
  return find
      .ancestor(
        of: findVisualNodeContent(name),
        matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onTap != null,
        ),
      )
      .first;
}

void verifyVisualNodeContent(
  WidgetTester tester,
  Finder foundNode,
  bool userRequestedExpected,
  bool dependencyRequestedExpected,
  bool isSystemFeatureExpected,
  bool isEnabledExpected,
) {
  expect(foundNode, findsOneWidget);
  expect(
    find.descendant(of: foundNode, matching: find.byIcon(Icons.check)),
    userRequestedExpected ? findsOneWidget : findsNothing,
  );
  expect(
    find.descendant(of: foundNode, matching: find.byIcon(Icons.lock)),
    dependencyRequestedExpected ? findsOneWidget : findsNothing,
  );
  final nodeContainer = find
      .ancestor(of: foundNode, matching: find.byType(Container))
      .first;
  final nodeDecoration =
      tester.widget<Container>(nodeContainer).decoration! as BoxDecoration;
  final expectedBackgroundColor = isSystemFeatureExpected
      ? (isEnabledExpected
            ? Colors.lightBlue
            : const Color.fromARGB(255, 61, 97, 114))
      : (isEnabledExpected
            ? Colors.pink
            : const Color.fromARGB(255, 172, 112, 132));
  expect(nodeDecoration.color, expectedBackgroundColor);
}

void main() {
  testWidgets("Single disabled user feature", (WidgetTester tester) async {
    final featureName = "profiles";
    final descriptions = <Feature, FeatureDescription>{
      Feature.profiles: FeatureDescription(
        dependencies: [],
        isSystemFeature: false,
        name: featureName,
      ),
    };
    final enabledFeatures = <Feature>[];
    await pumpFeatureView(tester, descriptions, enabledFeatures);

    expect(find.byType(FeatureSettingsPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final foundNode = findVisualNodeContent(featureName);
    verifyVisualNodeContent(tester, foundNode, false, false, false, false);
  });

  testWidgets("Enabled system feature has system enabled styling", (
    WidgetTester tester,
  ) async {
    const featureName = "profiles";
    final descriptions = <Feature, FeatureDescription>{
      Feature.profiles: FeatureDescription(
        dependencies: [],
        isSystemFeature: true,
        name: featureName,
      ),
    };

    await pumpFeatureView(tester, descriptions, [Feature.profiles]);

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(featureName),
      true,
      false,
      true,
      true,
    );
  });

  testWidgets("Enabling a node enables and locks its dependency", (
    WidgetTester tester,
  ) async {
    const parentName = "memberManagementMode";
    const dependencyName = "memberView";
    final descriptions = <Feature, FeatureDescription>{
      Feature.memberManagementMode: FeatureDescription(
        dependencies: [Feature.memberView],
        isSystemFeature: false,
        name: parentName,
      ),
      Feature.memberView: FeatureDescription(
        dependencies: [],
        isSystemFeature: false,
        name: dependencyName,
      ),
    };

    await pumpFeatureView(tester, descriptions, [Feature.memberManagementMode]);

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(parentName),
      true,
      false,
      false,
      true,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(dependencyName),
      false,
      true,
      false,
      true,
    );

    final graphView = tester.widget<GraphView>(find.byType(GraphView));
    expect(graphView.graph.edges, hasLength(1));
    final edge = graphView.graph.edges.single;
    expect(edge.source, same(graphView.graph.nodes[0]));
    expect(edge.destination, same(graphView.graph.nodes[1]));
  });

  testWidgets("A locked dependency can be user-requested independently", (
    WidgetTester tester,
  ) async {
    const parentName = "memberManagementMode";
    const dependencyName = "memberView";
    final descriptions = <Feature, FeatureDescription>{
      Feature.memberManagementMode: FeatureDescription(
        dependencies: [Feature.memberView],
        isSystemFeature: false,
        name: parentName,
      ),
      Feature.memberView: FeatureDescription(
        dependencies: [],
        isSystemFeature: false,
        name: dependencyName,
      ),
    };

    await pumpFeatureView(tester, descriptions, [Feature.memberManagementMode]);

    tester
        .widget<GestureDetector>(findVisualNodeTapTarget(dependencyName))
        .onTap!();
    await tester.pumpAndSettle();

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(dependencyName),
      true,
      true,
      false,
      true,
    );

    tester
        .widget<GestureDetector>(findVisualNodeTapTarget(parentName))
        .onTap!();
    await tester.pumpAndSettle();

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(parentName),
      false,
      false,
      false,
      false,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(dependencyName),
      true,
      false,
      false,
      true,
    );
  });

  testWidgets("A shared dependency is locked while either parent is enabled", (
    WidgetTester tester,
  ) async {
    const firstParentName = "memberManagementMode";
    const secondParentName = "sepaManagementMode";
    const sharedDependencyName = "memberView";
    final descriptions = <Feature, FeatureDescription>{
      Feature.memberManagementMode: FeatureDescription(
        dependencies: [Feature.memberView],
        isSystemFeature: false,
        name: firstParentName,
      ),
      Feature.sepaManagementMode: FeatureDescription(
        dependencies: [Feature.memberView],
        isSystemFeature: false,
        name: secondParentName,
      ),
      Feature.memberView: FeatureDescription(
        dependencies: [],
        isSystemFeature: false,
        name: sharedDependencyName,
      ),
    };

    await pumpFeatureView(tester, descriptions, []);

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(sharedDependencyName),
      false,
      false,
      false,
      false,
    );

    final graphView = tester.widget<GraphView>(find.byType(GraphView));
    expect(graphView.graph.edges, hasLength(2));
    expect(
      graphView.graph.edges[0].destination,
      same(graphView.graph.edges[1].destination),
    );

    tester
        .widget<GestureDetector>(findVisualNodeTapTarget(firstParentName))
        .onTap!();
    await tester.pumpAndSettle();

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(sharedDependencyName),
      false,
      true,
      false,
      true,
    );

    tester
        .widget<GestureDetector>(findVisualNodeTapTarget(secondParentName))
        .onTap!();
    await tester.pumpAndSettle();
    tester
        .widget<GestureDetector>(findVisualNodeTapTarget(firstParentName))
        .onTap!();
    await tester.pumpAndSettle();

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(firstParentName),
      false,
      false,
      false,
      false,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(secondParentName),
      true,
      false,
      false,
      true,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(sharedDependencyName),
      false,
      true,
      false,
      true,
    );

    tester
        .widget<GestureDetector>(findVisualNodeTapTarget(secondParentName))
        .onTap!();
    await tester.pumpAndSettle();

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(sharedDependencyName),
      false,
      false,
      false,
      false,
    );
  });

  testWidgets("Dependency locking propagates transitively", (
    WidgetTester tester,
  ) async {
    const rootName = "featureSettings";
    const middleName = "memberManagementMode";
    const leafName = "memberView";
    final descriptions = <Feature, FeatureDescription>{
      Feature.featureSettings: FeatureDescription(
        dependencies: [Feature.memberManagementMode],
        isSystemFeature: false,
        name: rootName,
      ),
      Feature.memberManagementMode: FeatureDescription(
        dependencies: [Feature.memberView],
        isSystemFeature: false,
        name: middleName,
      ),
      Feature.memberView: FeatureDescription(
        dependencies: [],
        isSystemFeature: false,
        name: leafName,
      ),
    };

    await pumpFeatureView(tester, descriptions, [Feature.featureSettings]);

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(rootName),
      true,
      false,
      false,
      true,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(middleName),
      false,
      true,
      false,
      true,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(leafName),
      false,
      true,
      false,
      true,
    );

    final graph = tester.widget<GraphView>(find.byType(GraphView)).graph;
    expect(graph.edges, hasLength(2));
    expect(graph.successorsOf(graph.nodes[0]), [same(graph.nodes[1])]);
    expect(graph.successorsOf(graph.nodes[1]), [same(graph.nodes[2])]);
    expect(graph.successorsOf(graph.nodes[0]), isNot(contains(graph.nodes[2])));

    tester.widget<GestureDetector>(findVisualNodeTapTarget(rootName)).onTap!();
    await tester.pumpAndSettle();

    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(middleName),
      false,
      false,
      false,
      false,
    );
    verifyVisualNodeContent(
      tester,
      findVisualNodeContent(leafName),
      false,
      false,
      false,
      false,
    );
  });
}
