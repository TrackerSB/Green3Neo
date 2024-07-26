import 'package:reflectable/reflectable.dart';

class Reflector extends Reflectable {
  const Reflector()
      : super(
          // NOTE 2024-07-26: This set of required capabilities is found by try and error
          reflectedTypeCapability,
          typeAnnotationDeepQuantifyCapability,
          instanceInvokeCapability,
        );
}

const reflectableMarker = Reflector();
