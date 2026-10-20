import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final localSelfieStorageProvider = Provider<LocalSelfieStorage>((ref) {
  return LocalSelfieStorage();
});

class LocalSelfieStorage {
  static const _dirName = 'selfies';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}${d.second.toString().padLeft(2, '0')}';

  Future<String?> saveSelfie({
    required Uint8List imageBytes,
    required DateTime date,
    required String type, // 'check_in' or 'check_out'
    String? id,
    String? verificationCode,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final selfieDir = Directory('${docDir.path}/$_dirName');
      if (!await selfieDir.exists()) {
        await selfieDir.create(recursive: true);
      }

      final localD = date.toLocal();
      final localDateStr = _formatDate(localD);
      final localTimeStr = _formatTime(localD);

      final utcD = date.toUtc();
      final utcDateStr = _formatDate(utcD);
      final utcTimeStr = _formatTime(utcD);

      // 1. Save specific punch file by local timestamp
      final localTsFile = File('${selfieDir.path}/${localDateStr}_${localTimeStr}_$type.jpg');
      await localTsFile.writeAsBytes(imageBytes);

      // 2. Also save by ID under local date prefix
      if (id != null && id.isNotEmpty) {
        final localIdFile = File('${selfieDir.path}/${localDateStr}_${id}_$type.jpg');
        await localIdFile.writeAsBytes(imageBytes);
      }

      // 3. Save by verificationCode if provided
      if (verificationCode != null && verificationCode.isNotEmpty) {
        final codeClean = verificationCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final localCodeFile = File('${selfieDir.path}/${localDateStr}_code_$codeClean.jpg');
        await localCodeFile.writeAsBytes(imageBytes);
      }

      // 4. Save UTC mirror if date or time differs (ensures cross-timezone queries match)
      if (utcDateStr != localDateStr || utcTimeStr != localTimeStr) {
        final utcTsFile = File('${selfieDir.path}/${utcDateStr}_${utcTimeStr}_$type.jpg');
        await utcTsFile.writeAsBytes(imageBytes);
        if (id != null && id.isNotEmpty) {
          final utcIdFile = File('${selfieDir.path}/${utcDateStr}_${id}_$type.jpg');
          await utcIdFile.writeAsBytes(imageBytes);
        }
      }

      // 5. Update the generic day fallback file
      final dayFile = File('${selfieDir.path}/${localDateStr}_$type.jpg');
      await dayFile.writeAsBytes(imageBytes);

      return localTsFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSelfiePath({
    required DateTime date,
    String type = 'check_in',
    String? id,
    String? verificationCode,
    DateTime? timestamp,
    bool exactOnly = false,
  }) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final selfieDir = Directory('${docDir.path}/$_dirName');
      if (!await selfieDir.exists()) return null;

      final localD = date.toLocal();
      final localDateStr = _formatDate(localD);
      final utcD = date.toUtc();
      final utcDateStr = _formatDate(utcD);

      final datePrefixes = <String>{localDateStr, utcDateStr};

      if (timestamp != null) {
        final tsLocal = timestamp.toLocal();
        final tsUtc = timestamp.toUtc();
        datePrefixes.add(_formatDate(tsLocal));
        datePrefixes.add(_formatDate(tsUtc));
      }

      // 1. By ID (check both local and UTC date prefixes, with and without type suffix)
      if (id != null && id.isNotEmpty) {
        for (final prefix in datePrefixes) {
          final idWithType = File('${selfieDir.path}/${prefix}_${id}_$type.jpg');
          if (await idWithType.exists()) return idWithType.path;
          final idExact = File('${selfieDir.path}/${prefix}_$id.jpg');
          if (await idExact.exists()) return idExact.path;
        }
      }

      // 2. By verification code
      if (verificationCode != null && verificationCode.isNotEmpty) {
        final codeClean = verificationCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        for (final prefix in datePrefixes) {
          final codeFile = File('${selfieDir.path}/${prefix}_code_$codeClean.jpg');
          if (await codeFile.exists()) return codeFile.path;
        }
      }

      // 3. By timestamp: search for the closest timestamped punch photo
      if (timestamp != null) {
        final tsLocal = timestamp.toLocal();
        final tsUtc = timestamp.toUtc();
        final localTimeStr = _formatTime(tsLocal);
        final utcTimeStr = _formatTime(tsUtc);

        // Check exact timestamp match first
        for (final prefix in datePrefixes) {
          final exactLocal = File('${selfieDir.path}/${prefix}_${localTimeStr}_$type.jpg');
          if (await exactLocal.exists()) return exactLocal.path;
          final exactUtc = File('${selfieDir.path}/${prefix}_${utcTimeStr}_$type.jpg');
          if (await exactUtc.exists()) return exactUtc.path;
        }

        // Scan all files in directory for timestamped punch files
        final allFiles = selfieDir.listSync().whereType<File>().toList(growable: false);
        File? bestFile;
        int bestDiffSeconds = 1 << 30;

        for (final f in allFiles) {
          final bName = f.uri.pathSegments.last;
          if (!bName.endsWith('.jpg')) continue;

          // Check if file belongs to any matching date prefix
          String? matchedPrefix;
          for (final prefix in datePrefixes) {
            if (bName.startsWith('${prefix}_')) {
              matchedPrefix = prefix;
              break;
            }
          }
          if (matchedPrefix == null) continue;

          // Parse 6-digit time component (e.g. "YYYY-MM-DD_HHmmss_check_in.jpg")
          final rest = bName.replaceFirst('${matchedPrefix}_', '');
          final timeMatch = RegExp(r'^(\d{2})(\d{2})(\d{2})').firstMatch(rest);
          if (timeMatch != null) {
            final h = int.parse(timeMatch.group(1)!);
            final m = int.parse(timeMatch.group(2)!);
            final s = int.parse(timeMatch.group(3)!);

            // Compute difference against local timestamp
            final fileDtLocal = DateTime(tsLocal.year, tsLocal.month, tsLocal.day, h, m, s);
            final diffLocal = (fileDtLocal.difference(tsLocal).inSeconds).abs();

            // Compute difference against UTC timestamp (using DateTime.utc to prevent PKT offset bug)
            final fileDtUtc = DateTime.utc(tsUtc.year, tsUtc.month, tsUtc.day, h, m, s);
            final diffUtc = (fileDtUtc.difference(tsUtc).inSeconds).abs();

            var minDiff = min(diffLocal, diffUtc);

            // Favor exact type match (e.g. check_in vs check_out)
            final matchesType = bName.contains('_$type.');
            if (!matchesType) {
              minDiff += 180; // minor penalty if type doesn't match
            }

            if (minDiff < bestDiffSeconds) {
              bestDiffSeconds = minDiff;
              bestFile = f;
            }
          }
        }

        // A punch file must be within a 45-minute window (2700s) to be considered a match
        if (bestFile != null && bestDiffSeconds <= 2700) {
          return bestFile.path;
        }

        // When a specific timestamp is requested, NEVER fall back to generic day files
        // or an unrelated punch from a different time of day. Return null.
        return null;
      }

      if (exactOnly) return null;

      // 4. Fallback: only if timestamp was NOT specified, generic day file for this specific type
      for (final prefix in datePrefixes) {
        final dayFile = File('${selfieDir.path}/${prefix}_$type.jpg');
        if (await dayFile.exists()) return dayFile.path;
      }

      // 5. Fallback: only if timestamp was NOT specified, check-in day file if looking for checkout
      for (final prefix in datePrefixes) {
        final inDayFile = File('${selfieDir.path}/${prefix}_check_in.jpg');
        if (await inDayFile.exists()) return inDayFile.path;
      }

      // 6. Fallback: only if timestamp was NOT specified, any selfie file for this date
      try {
        final allFiles = selfieDir.listSync().whereType<File>();
        for (final f in allFiles) {
          final bName = f.uri.pathSegments.last;
          for (final prefix in datePrefixes) {
            if (bName.startsWith('${prefix}_') && bName.endsWith('.jpg')) {
              return f.path;
            }
          }
        }
      } catch (_) {}
    } catch (_) {}
    return null;
  }
}
