import 'package:get_it/get_it.dart';
import 'package:green3neo/features/feature_registration.dart';

class FeatureCatalog {
  Future<void> registerEnabledFeatures() {
    return Future.wait(
      GetIt.instance.getAll<FeatureRegistration>().map(
        (feature) => feature.register(),
      ),
    );
  }
}
