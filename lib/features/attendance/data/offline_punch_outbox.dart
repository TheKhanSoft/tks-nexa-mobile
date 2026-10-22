import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';

abstract interface class OfflinePunchOutbox {
  Future<List<OfflinePunchItem>> getAll();
  Future<List<OfflinePunchItem>> getPending();
  Future<List<OfflinePunchItem>> getRejected();
  Future<void> enqueue(OfflinePunchItem item);
  Future<void> update(OfflinePunchItem item);
  Future<void> remove(String id);
  Future<int> getPendingCount();
  Future<int> getRejectedCount();
  Future<void> clear();
  Future<void> clearRejected();
  Future<void> clearSynced();
}

class FileOfflinePunchOutbox implements OfflinePunchOutbox {
  FileOfflinePunchOutbox({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<Directory> _getDirectory() async {
    if (_baseDirectory != null) {
      if (!await _baseDirectory!.exists()) {
        await _baseDirectory!.create(recursive: true);
      }
      return _baseDirectory!;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/offline_punch_outbox');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<List<OfflinePunchItem>> getAll() async {
    try {
      final dir = await _getDirectory();
      final files = await dir.list().toList();
      final items = <OfflinePunchItem>[];
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            items.add(OfflinePunchItem.fromJson(json));
          } catch (_) {
            // Ignore corrupted individual files
          }
        }
      }
      items.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<OfflinePunchItem>> getPending() async {
    final all = await getAll();
    return all
        .where((item) =>
            item.status == OfflinePunchStatus.pending ||
            item.status == OfflinePunchStatus.failed)
        .toList();
  }

  @override
  Future<List<OfflinePunchItem>> getRejected() async {
    final all = await getAll();
    return all
        .where((item) => item.status == OfflinePunchStatus.rejected)
        .toList();
  }

  @override
  Future<void> enqueue(OfflinePunchItem item) async {
    final dir = await _getDirectory();
    final cleanId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final file = File('${dir.path}/$cleanId.json');
    await file.writeAsString(jsonEncode(item.toJson()), flush: true);
  }

  @override
  Future<void> update(OfflinePunchItem item) async {
    await enqueue(item);
  }

  @override
  Future<void> remove(String id) async {
    try {
      final dir = await _getDirectory();
      final cleanId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${dir.path}/$cleanId.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Future<int> getPendingCount() async {
    final pending = await getPending();
    return pending.length;
  }

  @override
  Future<int> getRejectedCount() async {
    final rejected = await getRejected();
    return rejected.length;
  }

  @override
  Future<void> clearRejected() async {
    final rejected = await getRejected();
    for (final item in rejected) {
      await remove(item.id);
    }
  }

  @override
  Future<void> clearSynced() async {
    final all = await getAll();
    for (final item in all.where((i) => i.status == OfflinePunchStatus.synced)) {
      await remove(item.id);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final dir = await _getDirectory();
      final files = await dir.list().toList();
      for (final f in files) {
        if (f is File) {
          await f.delete();
        }
      }
    } catch (_) {}
  }
}

final offlinePunchOutboxProvider = Provider<OfflinePunchOutbox>(
  (ref) => FileOfflinePunchOutbox(),
);
