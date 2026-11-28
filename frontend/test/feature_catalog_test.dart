import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/features/feature_catalog.dart';
import 'package:green3neo/features/feature_view.dart';
import 'package:green3neo/features/feature_registration.dart';
import 'package:green3neo/injection.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';
import 'package:green3neo/interface/backend_api/frb_generated.dart';

class _SystemFeatureApi implements RustLibApi {
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

void main() {
  test("registers injectable feature catalog", () async {
    configureDependencies();
    addTearDown(GetIt.instance.reset);
    RustLib.initMock(api: _SystemFeatureApi());
    addTearDown(RustLib.dispose);

    expect(GetIt.instance.getAll<FeatureRegistration>(), hasLength(8));
    expect(GetIt.instance.isRegistered<FeatureSettings>(), isFalse);

    await FeatureCatalog(GetIt.instance).registerEnabledFeatures();

    expect(GetIt.instance.isRegistered<FeatureSettings>(), isTrue);
  });
}
