import 'package:get_it/get_it.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';

abstract mixin class FeatureRegistration {
  static final Set<Feature> _registeredFeatures = {};

  Future<Null> register() {
    final getIt = GetIt.instance;
    final feature = associatedFeature();

    // FIXME Allow unregistering features

    if (_registeredFeatures.contains(feature)) {
      return Future.value();
    }

    return getFeatureDescription(feature: feature).then((description) async {
      if (description.isSystemFeature) {
        // FIXME Verify whether system feature is enabled
        registerUnconditionally();
        _registeredFeatures.add(feature);
      } else {
        // FIXME Do not wait indefinitely
        Future.doWhile(() {
          final bool profileAvailable = getIt.isRegistered<LoadedProfile>();
          return !profileAvailable;
        });

        await getIt.getAsync<LoadedProfile>().then((LoadedProfile profile) {
          if (profile.features.contains(feature)) {
            registerUnconditionally();
            _registeredFeatures.add(feature);
          }
        });
      }
    });
  }

  // Do not call this method directly
  void registerUnconditionally();

  Feature associatedFeature();
}
