import 'package:reflectable/reflectable.dart';

class Reflector extends Reflectable {
  const Reflector()
      : super(
            declarationsCapability, // For allowing access to declarations
            instanceInvokeCapability // For allowing reading declarations (fields and methods)
            );
}

const reflectableMarker = Reflector();
