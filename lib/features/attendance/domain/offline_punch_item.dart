import 'dart:convert';
import 'package:crypto/crypto.dart';

enum OfflinePunchStatus {
  pending,
  syncing,
  failed,
  rejected,
  synced;

  String get label => switch (this) {
        OfflinePunchStatus.pending => 'Pending Upload',
        OfflinePunchStatus.syncing => 'Uploading...',
        OfflinePunchStatus.failed => 'Sync Failed',
        OfflinePunchStatus.rejected => 'Rejected (Mismatch)',
        OfflinePunchStatus.synced => 'Uploaded',
      };

  bool get isPending => this == OfflinePunchStatus.pending;
  bool get isRejected => this == OfflinePunchStatus.rejected;
  bool get isFailed => this == OfflinePunchStatus.failed;
  bool get isSynced => this == OfflinePunchStatus.synced;
}

class OfflinePunchItem {
  const OfflinePunchItem({
    required this.id,
    required this.capturedAt,
    required this.requestPayload,
    required this.status,
    required this.createdAt,
    this.syncAttempts = 0,
    this.lastError,
    this.payloadHash,
    this.clockSkewSeconds,
    this.isTimeManipulated = false,
    this.isMockLocation = false,
    this.elapsedRealtimeMsAtPunch,
    this.isAutoTime = true,
  });

  final String id;
  final DateTime capturedAt;
  final Map<String, dynamic> requestPayload;
  final OfflinePunchStatus status;
  final DateTime createdAt;
  final int syncAttempts;
  final String? lastError;
  final String? payloadHash;
  final int? clockSkewSeconds;
  final bool isTimeManipulated;
  final bool isMockLocation;
  final int? elapsedRealtimeMsAtPunch;
  final bool isAutoTime;

  static String generatePayloadHash({
    required String id,
    required DateTime capturedAt,
    required Map<String, dynamic> payload,
  }) {
    // Generate deterministic digest over key security attributes
    final canonical = [
      id,
      capturedAt.toUtc().toIso8601String(),
      payload['challenge_id'] ?? '',
      payload['device_id'] ?? '',
      payload['latitude']?.toString() ?? '',
      payload['longitude']?.toString() ?? '',
      payload['similarity_score']?.toString() ?? '',
      payload['snapshot_base64'] != null ? sha256.convert(utf8.encode(payload['snapshot_base64'] as String)).toString() : '',
    ].join('|');
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  bool verifyIntegrity() {
    if (payloadHash == null) return true; // Legacy items without hash
    final expected = generatePayloadHash(
      id: id,
      capturedAt: capturedAt,
      payload: requestPayload,
    );
    return expected == payloadHash;
  }

  double? get similarityScore {
    final direct = requestPayload['similarity_score'] ?? requestPayload['confidence_score'];
    if (direct is num) return direct.toDouble();
    return null;
  }

  double? get matchThreshold {
    final direct = requestPayload['match_threshold'];
    if (direct is num) return direct.toDouble();
    return null;
  }

  String? get snapshotBase64 {
    final s = requestPayload['snapshot_base64'] ?? requestPayload['snapshot'];
    return s is String ? s : null;
  }

  String? get punchType {
    final t = requestPayload['attendance_type'] ?? requestPayload['type'];
    return t is String ? t : null;
  }

  String? get locationName {
    final loc = requestPayload['location_name'] ?? requestPayload['location'];
    return loc is String ? loc : null;
  }

  bool get isRejected => status == OfflinePunchStatus.rejected;
  bool get isPending => status == OfflinePunchStatus.pending;
  bool get isFailed => status == OfflinePunchStatus.failed;
  bool get isSynced => status == OfflinePunchStatus.synced;

  OfflinePunchItem copyWith({
    String? id,
    DateTime? capturedAt,
    Map<String, dynamic>? requestPayload,
    OfflinePunchStatus? status,
    DateTime? createdAt,
    int? syncAttempts,
    String? lastError,
    String? payloadHash,
    int? clockSkewSeconds,
    bool? isTimeManipulated,
    bool? isMockLocation,
    int? elapsedRealtimeMsAtPunch,
    bool? isAutoTime,
  }) {
    return OfflinePunchItem(
      id: id ?? this.id,
      capturedAt: capturedAt ?? this.capturedAt,
      requestPayload: requestPayload ?? this.requestPayload,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastError: lastError ?? this.lastError,
      payloadHash: payloadHash ?? this.payloadHash,
      clockSkewSeconds: clockSkewSeconds ?? this.clockSkewSeconds,
      isTimeManipulated: isTimeManipulated ?? this.isTimeManipulated,
      isMockLocation: isMockLocation ?? this.isMockLocation,
      elapsedRealtimeMsAtPunch: elapsedRealtimeMsAtPunch ?? this.elapsedRealtimeMsAtPunch,
      isAutoTime: isAutoTime ?? this.isAutoTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'captured_at': capturedAt.toIso8601String(),
        'request_payload': requestPayload,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'sync_attempts': syncAttempts,
        if (lastError != null) 'last_error': lastError,
        if (payloadHash != null) 'payload_hash': payloadHash,
        if (clockSkewSeconds != null) 'clock_skew_seconds': clockSkewSeconds,
        'is_time_manipulated': isTimeManipulated,
        'is_mock_location': isMockLocation,
        if (elapsedRealtimeMsAtPunch != null)
          'elapsed_realtime_ms_at_punch': elapsedRealtimeMsAtPunch,
        'is_auto_time': isAutoTime,
      };

  factory OfflinePunchItem.fromJson(Map<String, dynamic> json) {
    var rawError = json['last_error'] as String?;
    var resolvedStatus = OfflinePunchStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => OfflinePunchStatus.pending,
    );

    final storedHash = json['payload_hash'] as String?;
    final capturedAt = DateTime.parse(json['captured_at'] as String);
    final payload = Map<String, dynamic>.from(json['request_payload'] as Map);

    // Verify cryptographic integrity if hash was stored
    if (storedHash != null) {
      final expected = generatePayloadHash(
        id: json['id'] as String,
        capturedAt: capturedAt,
        payload: payload,
      );
      if (expected != storedHash) {
        resolvedStatus = OfflinePunchStatus.rejected;
        rawError = 'Security warning: Punch payload was altered or tampered with on device.';
      }
    }

    // Auto-migrate legacy items that were stuck due to similarity threshold or mismatch
    if (resolvedStatus != OfflinePunchStatus.synced && rawError != null) {
      final lowerErr = rawError.toLowerCase();
      if (lowerErr.contains('similarity') ||
          lowerErr.contains('threshold') ||
          lowerErr.contains('mismatch') ||
          lowerErr.contains('below') ||
          lowerErr.contains('rejected')) {
        resolvedStatus = OfflinePunchStatus.rejected;
      }
    }

    return OfflinePunchItem(
      id: json['id'] as String,
      capturedAt: capturedAt,
      requestPayload: payload,
      status: resolvedStatus,
      createdAt: DateTime.parse(json['created_at'] as String),
      syncAttempts: (json['sync_attempts'] as num?)?.toInt() ?? 0,
      lastError: rawError,
      payloadHash: storedHash,
      clockSkewSeconds: (json['clock_skew_seconds'] as num?)?.toInt(),
      isTimeManipulated: json['is_time_manipulated'] == true,
      isMockLocation: json['is_mock_location'] == true,
      elapsedRealtimeMsAtPunch: (json['elapsed_realtime_ms_at_punch'] as num?)?.toInt(),
      isAutoTime: json['is_auto_time'] != false,
    );
  }
}
