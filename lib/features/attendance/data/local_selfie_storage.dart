import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final localSelfieStorageProvider = Provider<LocalSelfieStorage>((ref) {
  return LocalSelfieStorage();
});

class LocalSelfieStorage {
  static const _dirName = 'selfies';

  Future<String?> saveSelfie({
    required Uint8List imageBytes,
    required DateTime date,
    required String type, // 'check_in' or 'check_out'
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final selfieDir = Directory('${docDir.path}/$_dirName');
      if (!await selfieDir.exists()) {
        await selfieDir.create(recursive: true);
      }

      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final fileName = '${dateStr}_$type.jpg';
      final file = File('${selfieDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSelfiePath({
    required DateTime date,
    String type = 'check_in',
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final fileName = '${dateStr}_$type.jpg';
      final file = File('${docDir.path}/$_dirName/$fileName');
      if (await file.exists()) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }
}
