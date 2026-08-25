import 'package:green3neo/interface/backend_api/api/feature.dart';

abstract interface class FrontendFeature {
  void register();
  Feature requiredFeature();
}
