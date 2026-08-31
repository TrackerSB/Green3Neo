import 'package:get_it/get_it.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';

abstract class FrontendFeature {
  static bool _featureRegistered = false;

  Future<Null> register() {
    final getIt = GetIt.instance;

    // FIXME Allow unregistering features

    if (_featureRegistered) {
      return Future.value();
    }

    return description(feature: requiredFeature()).then((description) async {
      if (description.isSystemFeature) {
        // FIXME Verify whether system feature is enabled
        registerUnconditionally();
        _featureRegistered = true;
      } else {
        // FIXME Do not wait indefinitely
        Future.doWhile(() {
          final bool profileAvailable = getIt.isRegistered<LoadedProfile>();
          return !profileAvailable;
        });

        await getIt.getAsync<LoadedProfile>().then((LoadedProfile profile) {
          if (profile.features.contains(requiredFeature())) {
            registerUnconditionally();
            _featureRegistered = true;
          }
        });
      }
    });
  }

  // Do not call this method directly
  void registerUnconditionally();

  Feature requiredFeature();
}
