import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/notifications/application/notification_inbox_service.dart';
import 'package:tks_nexa_attendance/features/notifications/domain/app_notification_item.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showOnlyUnread = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<AppNotificationItem> items) {
    setState(() {
      _selectedIds.addAll(items.map((i) => i.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text('Are you sure you want to delete $count selected notification${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(notificationInboxProvider.notifier).deleteSelected(_selectedIds);
      if (mounted) {
        _clearSelection();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count notification${count > 1 ? 's' : ''} deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteOpened() async {
    final inbox = ref.read(notificationInboxProvider).value ?? [];
    final openedIds = inbox.where((item) => item.isRead).map((item) => item.id).toSet();

    if (openedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No opened or read notifications to delete.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Opened Notifications'),
        content: Text('Delete all ${openedIds.length} read notifications from your inbox?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Opened'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(notificationInboxProvider.notifier).deleteSelected(openedIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${openedIds.length} read notifications deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final inbox = ref.read(notificationInboxProvider).value ?? [];
    if (inbox.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear your entire notification inbox? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(notificationInboxProvider.notifier).clearAll();
      if (mounted) {
        _clearSelection();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showNotificationDetail(AppNotificationItem item) {
    if (!item.isRead) {
      ref.read(notificationInboxProvider.notifier).markAsRead(item.id);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationDetailSheet(
        item: item,
        onDelete: () async {
          Navigator.of(ctx).pop();
          await ref.read(notificationInboxProvider.notifier).deleteNotification(item.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification deleted.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onToggleRead: () async {
          Navigator.of(ctx).pop();
          if (item.isRead) {
            await ref.read(notificationInboxProvider.notifier).markAsUnread(item.id);
          } else {
            await ref.read(notificationInboxProvider.notifier).markAsRead(item.id);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final inboxAsync = ref.watch(notificationInboxProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: brand.heroStart,
        foregroundColor: Colors.white,
        title: _isSelectionMode
            ? Text(
                '${_selectedIds.length} Selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              )
            : const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              tooltip: 'Select All',
              icon: const Icon(Icons.select_all_rounded),
              onPressed: () {
                final items = inboxAsync.value ?? [];
                _selectAll(items);
              },
            ),
            IconButton(
              tooltip: 'Delete Selected',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select items',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: _toggleSelectionMode,
            ),
            IconButton(
              tooltip: 'Notification Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(AppRoutes.notificationPreferences),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'mark_all_read':
                    ref.read(notificationInboxProvider.notifier).markAllAsRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    break;
                  case 'delete_opened':
                    _deleteOpened();
                    break;
                  case 'clear_all':
                    _clearAll();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.done_all_rounded),
                    title: Text('Mark all as read'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_opened',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete opened / read'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.clear_all_rounded, color: Color(0xFFEF4444)),
                    title: Text('Clear all notifications', style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: inboxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load notifications: $err'),
          ),
        ),
        data: (items) {
          final displayedItems = _showOnlyUnread ? items.where((i) => !i.isRead).toList() : items;

          return Column(
            children: [
              // Filter bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('All (${items.length})'),
                      selected: !_showOnlyUnread,
                      onSelected: (selected) {
                        if (selected) setState(() => _showOnlyUnread = false);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Unread ($unreadCount)'),
                      selected: _showOnlyUnread,
                      onSelected: (selected) {
                        setState(() => _showOnlyUnread = selected);
                      },
                    ),
                    const Spacer(),
                    if (unreadCount > 0 && !_isSelectionMode)
                      TextButton.icon(
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('Read all', style: TextStyle(fontSize: 12)),
                        onPressed: () => ref.read(notificationInboxProvider.notifier).markAllAsRead(),
                      ),
                  ],
                ),
              ),

              // Items list or empty state
              Expanded(
                child: displayedItems.isEmpty
                    ? _EmptyNotificationsView(showOnlyUnread: _showOnlyUnread)
                    : ListView.separated(
                        itemCount: displayedItems.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: _isSelectionMode ? 72 : 64,
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                        itemBuilder: (context, index) {
                          final item = displayedItems[index];
                          final isSelected = _selectedIds.contains(item.id);

                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              color: const Color(0xFFEF4444),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              ref.read(notificationInboxProvider.notifier).deleteNotification(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notification removed.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: _NotificationTile(
                              item: item,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleItemSelection(item.id);
                                } else {
                                  _showNotificationDetail(item);
                                }
                              },
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  _toggleSelectionMode();
                                  _toggleItemSelection(item.id);
                                }
                              },
                              onToggleRead: () {
                                if (item.isRead) {
                                  ref.read(notificationInboxProvider.notifier).markAsUnread(item.id);
                                } else {
                                  ref.read(notificationInboxProvider.notifier).markAsRead(item.id);
                                }
                              },
                              onDelete: () {
                                ref.read(notificationInboxProvider.notifier).deleteNotification(item.id);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleRead,
    required this.onDelete,
  });

  final AppNotificationItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  Color _getCategoryColor(NotificationCategory cat) {
    return switch (cat) {
      NotificationCategory.shiftReminder => const Color(0xFF2563EB),
      NotificationCategory.overdueAttendance => const Color(0xFFF59E0B),
      NotificationCategory.approvalStatus => const Color(0xFF10B981),
      NotificationCategory.security => const Color(0xFF8B5CF6),
      NotificationCategory.system => const Color(0xFF0D9488),
    };
  }

  IconData _getCategoryIcon(NotificationCategory cat) {
    return switch (cat) {
      NotificationCategory.shiftReminder => Icons.alarm_rounded,
      NotificationCategory.overdueAttendance => Icons.warning_amber_rounded,
      NotificationCategory.approvalStatus => Icons.assignment_turned_in_rounded,
      NotificationCategory.security => Icons.shield_rounded,
      NotificationCategory.system => Icons.notifications_rounded,
    };
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = _getCategoryColor(item.category);
    final catIcon = _getCategoryIcon(item.category);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: !item.isRead
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : (isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                ),
              ),

            // Icon avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: catColor.withValues(alpha: 0.12),
                  child: Icon(catIcon, color: catColor, size: 20),
                ),
                if (!item.isRead)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (!isSelectionMode)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                tooltip: 'Options',
                onSelected: (val) {
                  if (val == 'toggle_read') {
                    onToggleRead();
                  } else if (val == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle_read',
                    child: Text(item.isRead ? 'Mark as unread' : 'Mark as read'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({
    required this.item,
    required this.onDelete,
    required this.onToggleRead,
  });

  final AppNotificationItem item;
  final VoidCallback onDelete;
  final VoidCallback onToggleRead;

  Color _getCategoryColor(NotificationCategory cat) {
    return switch (cat) {
      NotificationCategory.shiftReminder => const Color(0xFF2563EB),
      NotificationCategory.overdueAttendance => const Color(0xFFF59E0B),
      NotificationCategory.approvalStatus => const Color(0xFF10B981),
      NotificationCategory.security => const Color(0xFF8B5CF6),
      NotificationCategory.system => const Color(0xFF0D9488),
    };
  }

  IconData _getCategoryIcon(NotificationCategory cat) {
    return switch (cat) {
      NotificationCategory.shiftReminder => Icons.alarm_rounded,
      NotificationCategory.overdueAttendance => Icons.warning_amber_rounded,
      NotificationCategory.approvalStatus => Icons.assignment_turned_in_rounded,
      NotificationCategory.security => Icons.shield_rounded,
      NotificationCategory.system => Icons.notifications_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = _getCategoryColor(item.category);
    final catIcon = _getCategoryIcon(item.category);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: catColor.withValues(alpha: 0.12),
                child: Icon(catIcon, color: catColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: catColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} at ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            item.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Body
          Text(
            item.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),

          // Action buttons
          if (item.category == NotificationCategory.shiftReminder ||
              item.category == NotificationCategory.overdueAttendance) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: catColor,
              ),
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Mark Attendance Now', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.attendancePreparation);
              },
            ),
            const SizedBox(height: 12),
          ] else if (item.route != null && item.route!.isNotEmpty) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: catColor,
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                context.push(item.route!);
              },
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(item.isRead ? Icons.mark_email_unread_outlined : Icons.drafts_outlined),
                  label: Text(item.isRead ? 'Mark Unread' : 'Mark Read'),
                  onPressed: onToggleRead,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView({required this.showOnlyUnread});

  final bool showOnlyUnread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                showOnlyUnread ? Icons.mark_email_read_outlined : Icons.notifications_off_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              showOnlyUnread ? 'No Unread Notifications' : 'No Notifications Yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              showOnlyUnread
                  ? 'You have caught up with all your shift and system notifications.'
                  : 'Automated shift alerts, overdue warnings, and system updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
