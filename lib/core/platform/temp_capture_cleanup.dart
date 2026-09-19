import 'temp_capture_cleanup_stub.dart'
    if (dart.library.io) 'temp_capture_cleanup_io.dart'
    as implementation;

Future<void> deleteTemporaryCapture(String path) =>
    implementation.deleteTemporaryCapture(path);
