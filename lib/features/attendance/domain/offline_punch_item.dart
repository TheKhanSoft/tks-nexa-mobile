enum OfflinePunchStatus {
  pending,
  syncing,
  failed,
  synced,
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
    return OfflinePunchItem(
      id: json['id'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      requestPayload: Map<String, dynamic>.from(json['request_payload'] as Map),
      status: OfflinePunchStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OfflinePunchStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      syncAttempts: (json['sync_attempts'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
    );
  }
}
