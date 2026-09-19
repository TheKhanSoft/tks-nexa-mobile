import 'dart:io';

Future<void> deleteTemporaryCapture(String path) async {
  if (path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // The camera plugin or operating system may already have removed it.
  }
}
