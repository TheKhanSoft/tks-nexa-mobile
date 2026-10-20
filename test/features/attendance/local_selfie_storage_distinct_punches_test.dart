import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';

class _MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _MockPathProviderPlatform(this.testDir);
  final Directory testDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => testDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late LocalSelfieStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('selfie_test_');
    PathProviderPlatform.instance = _MockPathProviderPlatform(tempDir);
    storage = LocalSelfieStorage();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('LocalSelfieStorage saves and resolves distinct photos for multiple punches on the same day', () async {
    final bytes1 = Uint8List.fromList([1, 1, 1, 1]);
    final bytes2 = Uint8List.fromList([2, 2, 2, 2]);
    final bytes3 = Uint8List.fromList([3, 3, 3, 3]);
    final bytes4 = Uint8List.fromList([4, 4, 4, 4]);

    final baseDate = DateTime(2026, 10, 8);
    final punch1 = DateTime(2026, 10, 8, 13, 45, 0); // 1:45 PM
    final punch2 = DateTime(2026, 10, 8, 13, 49, 0); // 1:49 PM
    final punch3 = DateTime(2026, 10, 8, 14, 12, 0); // 2:12 PM
    final punch4 = DateTime(2026, 10, 8, 15, 54, 0); // 3:54 PM

    // Save all 4 punches
    await storage.saveSelfie(imageBytes: bytes1, date: punch1, type: 'check_in', id: 'punch-1');
    await storage.saveSelfie(imageBytes: bytes2, date: punch2, type: 'check_in', id: 'punch-2');
    await storage.saveSelfie(imageBytes: bytes3, date: punch3, type: 'check_in', id: 'punch-3');
    await storage.saveSelfie(imageBytes: bytes4, date: punch4, type: 'check_in', id: 'punch-4');

    // Retrieve by punch timestamp
    final path1 = await storage.getSelfiePath(date: baseDate, timestamp: punch1, type: 'check_in');
    final path2 = await storage.getSelfiePath(date: baseDate, timestamp: punch2, type: 'check_in');
    final path3 = await storage.getSelfiePath(date: baseDate, timestamp: punch3, type: 'check_in');
    final path4 = await storage.getSelfiePath(date: baseDate, timestamp: punch4, type: 'check_in');

    expect(path1, isNotNull);
    expect(path2, isNotNull);
    expect(path3, isNotNull);
    expect(path4, isNotNull);

    // Verify all 4 paths are completely distinct from one another
    final paths = {path1!, path2!, path3!, path4!};
    expect(paths.length, equals(4), reason: 'Each punch must resolve to its own distinct photo file');

    // Verify content of each resolved photo matches the corresponding punch
    expect(await File(path1).readAsBytes(), equals(bytes1));
    expect(await File(path2).readAsBytes(), equals(bytes2));
    expect(await File(path3).readAsBytes(), equals(bytes3));
    expect(await File(path4).readAsBytes(), equals(bytes4));
  });

  test('LocalSelfieStorage preserves separate check-in and check-out photos on the same day', () async {
    final checkInBytes = Uint8List.fromList([10, 20, 30]);
    final checkOutBytes = Uint8List.fromList([70, 80, 90]);

    final checkInDt = DateTime(2026, 10, 9, 8, 30, 0);
    final checkOutDt = DateTime(2026, 10, 9, 17, 15, 0);

    await storage.saveSelfie(imageBytes: checkInBytes, date: checkInDt, type: 'check_in', id: 'in-1');
    await storage.saveSelfie(imageBytes: checkOutBytes, date: checkOutDt, type: 'check_out', id: 'out-1');

    final resolvedIn = await storage.getSelfiePath(date: DateTime(2026, 10, 9), timestamp: checkInDt, type: 'check_in');
    final resolvedOut = await storage.getSelfiePath(date: DateTime(2026, 10, 9), timestamp: checkOutDt, type: 'check_out');

    expect(resolvedIn, isNotNull);
    expect(resolvedOut, isNotNull);
    expect(resolvedIn, isNot(equals(resolvedOut)));

    expect(await File(resolvedIn!).readAsBytes(), equals(checkInBytes));
    expect(await File(resolvedOut!).readAsBytes(), equals(checkOutBytes));
  });

  test('LocalSelfieStorage does NOT return a punch photo if timestamp exceeds 45-minute window', () async {
    final eveningBytes = Uint8List.fromList([99, 99, 99]);
    final eveningPunch = DateTime(2026, 10, 8, 18, 55, 0); // 6:55 PM
    await storage.saveSelfie(imageBytes: eveningBytes, date: eveningPunch, type: 'check_in', id: 'punch-evening');

    // Query for morning touchpoint (7:11 AM) on the same date
    final morningTouchpoint = DateTime(2026, 10, 8, 7, 11, 0);
    final resolvedMorning = await storage.getSelfiePath(
      date: DateTime(2026, 10, 8),
      timestamp: morningTouchpoint,
      type: 'check_in',
    );

    // Morning touchpoint must NOT receive the 6:55 PM evening photo
    expect(resolvedMorning, isNull, reason: 'Punches separated by hours must never hijack each other photos');
  });

  test('LocalSelfieStorage correctly matches UTC timestamped punch files across timezones', () async {
    final utcBytes = Uint8List.fromList([55, 55, 55]);
    final punchUtc = DateTime.utc(2026, 10, 8, 10, 54, 0);
    await storage.saveSelfie(imageBytes: utcBytes, date: punchUtc, type: 'check_in', id: 'punch-utc');

    // Query using local DateTime equivalent (e.g. +5h = 15:54 local)
    final localPunch = punchUtc.toLocal();
    final resolved = await storage.getSelfiePath(
      date: localPunch,
      timestamp: localPunch,
      type: 'check_in',
    );

    expect(resolved, isNotNull);
    expect(await File(resolved!).readAsBytes(), equals(utcBytes));
  });
}
