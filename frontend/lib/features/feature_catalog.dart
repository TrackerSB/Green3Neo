import 'package:get_it/get_it.dart';
import 'package:green3neo/features/feature_registration.dart';

class FeatureCatalog {
  final GetIt _getIt;

  FeatureCatalog(this._getIt);

  Future<void> registerEnabledFeatures() {
    return Future.wait(
      _getIt.getAll<FeatureRegistration>().map((feature) => feature.register()),
    );
  }
}
