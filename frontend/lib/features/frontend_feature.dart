import 'package:green3neo/interface/backend_api/api/feature.dart';

abstract class FrontendFeature {
  // Do not override this method
  void register() {
    registerImpl();
  }

  // Do not call this method directly
  void registerImpl();

  Feature requiredFeature();
}
