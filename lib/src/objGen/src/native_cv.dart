import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// C function signatures
typedef _CVersionFunc = ffi.Pointer<Utf8> Function();
typedef _CProcessImageFunc = ffi.Void Function(
  ffi.Pointer<Utf8>,
  ffi.Pointer<Utf8>,
);
typedef _CAdaptiveThreshold = Pointer<ImageData> Function(
    ffi.Int32, ffi.Pointer<ffi.Uint8>);

class ImageData extends Struct {
  @Int32()
  external int len;

  external Pointer<ffi.Uint8> data;
}

// Dart function signatures
typedef _VersionFunc = ffi.Pointer<Utf8> Function();
typedef _ProcessImageFunc = void Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef _ProcessAdaptvie = Pointer<ImageData> Function(
    int, ffi.Pointer<ffi.Uint8>);

// Getting a library that holds needed symbols
ffi.DynamicLibrary _openDynamicLibrary() {
  if (Platform.isAndroid) {
    return ffi.DynamicLibrary.open('libnative_opencv.so');
  } else if (Platform.isWindows) {
    return ffi.DynamicLibrary.open("native_opencv_windows_plugin.dll");
  }

  return ffi.DynamicLibrary.process();
}

ffi.DynamicLibrary _lib = _openDynamicLibrary();

// Looking for the functions
final _VersionFunc _version =
    _lib.lookup<ffi.NativeFunction<_CVersionFunc>>('version').asFunction();

final _ProcessAdaptvie _processImage = _lib
    .lookup<ffi.NativeFunction<_CAdaptiveThreshold>>('process_image')
    .asFunction();

String opencvVersion() {
  return _version().toDartString();
}

void processImage(ProcessImageArguments args) {
  final ffi.Pointer<ffi.Uint8> data =
      malloc.allocate<ffi.Uint8>(ffi.sizeOf<ffi.Uint8>() * args.bytes.length);

  for (var i = 0; i < args.bytes.length; i++) {
    data.elementAt(i).value = args.bytes[i];
  }

  ffi.Pointer<ImageData> myStructPtr = _processImage(args.bytes.length, data);

  args.port.send(myStructPtr.ref.data.asTypedList(myStructPtr.ref.len - 1));
}

Future<Uint8List> houghCircles(
    Uint8List byteData, int width, int height, int typr) async {
  final ffi.Pointer<ffi.Uint8> data =
      malloc.allocate<ffi.Uint8>(ffi.sizeOf<ffi.Uint8>() * byteData.length);

  for (var i = 0; i < byteData.length; i++) {
    data.elementAt(i).value = byteData[i];
  }

  ffi.Pointer<ImageData> myStructPtr = _processImage(byteData.length, data);
  return myStructPtr.ref.data.asTypedList(myStructPtr.ref.len);
}

class ProcessImageArguments {
  Uint8List bytes;
  SendPort port;

  ProcessImageArguments(this.bytes, this.port);
}
