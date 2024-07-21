import 'package:reflectable/reflectable.dart';

class Reflector extends Reflectable {
  const Reflector()
      : super(
          declarationsCapability, // For accessing declarations
          instanceInvokeCapability, // For reading declarations (fields and methods) of instances
          typeCapability, // For accessing types of declarations
        );
}

const reflectableMarker = Reflector();
