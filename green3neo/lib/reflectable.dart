import 'package:reflectable/reflectable.dart';

class Reflector extends Reflectable {
  const Reflector() : super(declarationsCapability);
}

const reflectableMarker = Reflector();
