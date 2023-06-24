// This file initializes the dynamic library and connects it with the stub
// generated by flutter_rust_bridge_codegen.

import 'dart:ffi';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import 'bridge_generated.dart';
// import 'bridge_definitions.dart'; // FIXME Required?

// Re-export the bridge so it is only necessary to import this file.
export 'bridge_generated.dart';
import 'dart:io' as io;

const _base = 'backend';

// On MacOS, the dynamic library is not bundled with the binary,
// but rather directly **linked** against the binary.
final path = io.Platform.isWindows ? '$_base.dll' : 'lib$_base.so';

late final dylib = loadLibForFlutter(path);
late final backendApi = BackendImpl(dylib);
