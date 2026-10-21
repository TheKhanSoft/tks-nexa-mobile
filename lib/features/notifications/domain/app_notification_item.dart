enum NotificationCategory {
  shiftReminder,
  overdueAttendance,
  approvalStatus,
  security,
  system;

  String get label => switch (this) {
        NotificationCategory.shiftReminder => 'Shift Reminder',
        NotificationCategory.overdueAttendance => 'Action Required',
        NotificationCategory.approvalStatus => 'Approvals',
        NotificationCategory.security => 'Security',
        NotificationCategory.system => 'System',
      };
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.route,
    this.payload = const {},
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool isRead;
  final String? route;
  final Map<String, dynamic> payload;

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? createdAt,
    bool? isRead,
    String? route,
    Map<String, dynamic>? payload,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      route: route ?? this.route,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        'route': route,
        'payload': payload,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: NotificationCategory.values.firstWhere(
        (c) => c.name == (json['category'] as String?),
        orElse: () => NotificationCategory.system,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      route: json['route'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }
}
