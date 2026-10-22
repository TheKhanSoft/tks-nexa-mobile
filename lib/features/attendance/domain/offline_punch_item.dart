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
  });

  final String id;
  final DateTime capturedAt;
  final Map<String, dynamic> requestPayload;
  final OfflinePunchStatus status;
  final DateTime createdAt;
  final int syncAttempts;
  final String? lastError;

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
  }) {
    return OfflinePunchItem(
      id: id ?? this.id,
      capturedAt: capturedAt ?? this.capturedAt,
      requestPayload: requestPayload ?? this.requestPayload,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastError: lastError ?? this.lastError,
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
      };

  factory OfflinePunchItem.fromJson(Map<String, dynamic> json) {
    final rawError = json['last_error'] as String?;
    var resolvedStatus = OfflinePunchStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => OfflinePunchStatus.pending,
    );

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
      capturedAt: DateTime.parse(json['captured_at'] as String),
      requestPayload: Map<String, dynamic>.from(json['request_payload'] as Map),
      status: resolvedStatus,
      createdAt: DateTime.parse(json['created_at'] as String),
      syncAttempts: (json['sync_attempts'] as num?)?.toInt() ?? 0,
      lastError: rawError,
    );
  }
}
