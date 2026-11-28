import 'package:flutter_test/flutter_test.dart';
import 'package:green3neo/features/frontend_feature.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:green3neo/interface/backend_api/frb_generated.dart';

class _FakeRustLibApi implements RustLibApi {
  @override
  Future<FeatureDescription> crateApiFeatureGetFeatureDescription({
    required Feature feature,
  }) async {
    return FeatureDescription(
      name: feature.name,
      dependencies: const [],
      isSystemFeature: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FirstFeature extends FrontendFeature {
  bool registered = false;

  @override
  void registerUnconditionally() => registered = true;

  @override
  Feature associatedFeature() => Feature.featureSettings;
}

class _SecondFeature extends FrontendFeature {
  bool registered = false;

  @override
  void registerUnconditionally() => registered = true;

  @override
  Feature associatedFeature() => Feature.profiles;
}

void main() {
  test("registers derived features independently", () async {
    RustLib.initMock(api: _FakeRustLibApi());
    addTearDown(RustLib.dispose);
    final first = _FirstFeature();
    final second = _SecondFeature();

    expect(first.registered, isFalse);
    expect(second.registered, isFalse);

    await first.register();
    expect(first.registered, isTrue);
    expect(second.registered, isFalse);

    await second.register();

    expect(first.registered, isTrue);
    expect(second.registered, isTrue);
  });
}
