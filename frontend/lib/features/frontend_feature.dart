import 'package:get_it/get_it.dart';
import 'package:green3neo/features/loaded_profile.dart';
import 'package:green3neo/interface/backend_api/api/feature.dart';

abstract class FrontendFeature {
  static bool _featureRegistered = false;

  // Do not override this method
  Future<Null> register() {
    final getIt = GetIt.instance;

    if (_featureRegistered) {
      return Future.value();
    }

    return getIt.getAsync<LoadedProfile>().then((LoadedProfile profile) {
      if (profile.features.contains(requiredFeature())) {
        registerUnconditionally();
        _featureRegistered = true;
      }
    });
  }

  // Do not call this method directly
  void registerUnconditionally();

  Feature requiredFeature();
}
