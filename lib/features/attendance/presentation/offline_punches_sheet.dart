import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/attendance/application/offline_punch_sync_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/offline_punch_item.dart';

void showOfflinePunchesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const OfflinePunchesSheet(),
  );
}

class OfflinePunchesSheet extends ConsumerStatefulWidget {
  const OfflinePunchesSheet({super.key});

  @override
  ConsumerState<OfflinePunchesSheet> createState() => _OfflinePunchesSheetState();
}

class _OfflinePunchesSheetState extends ConsumerState<OfflinePunchesSheet> {
  int _selectedFilterIndex = 0; // 0: All, 1: Pending, 2: Rejected

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final syncState =
        ref.watch(offlinePunchSyncProvider).value ?? const OfflineSyncState();
    final items = syncState.items;

    final pendingItems = items.where((i) => i.isPending || i.isFailed).toList();
    final rejectedItems = items.where((i) => i.isRejected).toList();

    final displayedItems = switch (_selectedFilterIndex) {
      1 => pendingItems,
      2 => rejectedItems,
      _ => items,
    };

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: syncState.hasRejected
                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  child: Icon(
                    syncState.hasRejected
                        ? Icons.warning_amber_rounded
                        : Icons.cloud_off_rounded,
                    color: syncState.hasRejected
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Offline Punches Outbox',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${items.length} total • ${pendingItems.length} pending • ${rejectedItems.length} rejected',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('All (${items.length})'),
                  selected: _selectedFilterIndex == 0,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilterIndex = 0);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Pending (${pendingItems.length})'),
                  selected: _selectedFilterIndex == 1,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilterIndex = 1);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Rejected (${rejectedItems.length})'),
                  selected: _selectedFilterIndex == 2,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilterIndex = 2);
                  },
                ),
                const Spacer(),
                if (items.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) async {
                      if (action == 'clear_rejected') {
                        await ref.read(offlinePunchSyncProvider.notifier).clearRejected();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All rejected offline punches cleared.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else if (action == 'clear_all') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear All Offline Punches'),
                            content: const Text(
                              'Delete all pending and rejected punches from this device? This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(offlinePunchSyncProvider.notifier).clearAll();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All offline punches removed.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (rejectedItems.isNotEmpty)
                        const PopupMenuItem(
                          value: 'clear_rejected',
                          child: Text('Clear rejected punches'),
                        ),
                      const PopupMenuItem(
                        value: 'clear_all',
                        child: Text(
                          'Clear all offline punches',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Content list or empty state
          Expanded(
            child: displayedItems.isEmpty
                ? _EmptyOfflinePunchesView(
                    filterIndex: _selectedFilterIndex,
                    totalCount: items.length,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: displayedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = displayedItems[index];
                      return _OfflinePunchCard(
                        item: item,
                        isSyncing: syncState.isSyncing,
                        onRetry: () async {
                          await ref
                              .read(offlinePunchSyncProvider.notifier)
                              .retryPunch(item.id);
                        },
                        onDelete: () async {
                          await ref
                              .read(offlinePunchSyncProvider.notifier)
                              .removePunch(item.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Offline punch removed.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),

          // Bottom action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                if (rejectedItems.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                      ),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Clear Rejected'),
                      onPressed: () async {
                        await ref.read(offlinePunchSyncProvider.notifier).clearRejected();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rejected punches cleared.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                if (rejectedItems.isNotEmpty && pendingItems.isNotEmpty)
                  const SizedBox(width: 12),
                if (pendingItems.isNotEmpty)
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: brand.heroStart,
                      ),
                      icon: syncState.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        syncState.isSyncing
                            ? 'Syncing...'
                            : 'Sync ${pendingItems.length} Pending',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: syncState.isSyncing
                          ? null
                          : () async {
                              final res = await ref
                                  .read(offlinePunchSyncProvider.notifier)
                                  .syncAll();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res.syncedCount > 0
                                          ? 'Successfully synced ${res.syncedCount} punch${res.syncedCount == 1 ? '' : 'es'}!'
                                          : (res.rejectedCount > 0
                                              ? '${res.rejectedCount} punch was rejected (low similarity / mismatch).'
                                              : (res.errors.isNotEmpty
                                                  ? res.errors.first
                                                  : 'Could not sync punches.')),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflinePunchCard extends StatelessWidget {
  const _OfflinePunchCard({
    required this.item,
    required this.isSyncing,
    required this.onRetry,
    required this.onDelete,
  });

  final OfflinePunchItem item;
  final bool isSyncing;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  Uint8List? _decodePhoto() {
    final raw = item.snapshotBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${local.day}/${local.month}/${local.year}';
    return '$dateStr at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoBytes = _decodePhoto();

    final statusBgColor = switch (item.status) {
      OfflinePunchStatus.pending => const Color(0xFFFEF3C7),
      OfflinePunchStatus.syncing => const Color(0xFFDBEAFE),
      OfflinePunchStatus.failed => const Color(0xFFF3F4F6),
      OfflinePunchStatus.rejected => const Color(0xFFFEE2E2),
      OfflinePunchStatus.synced => const Color(0xFFD1FAE5),
    };

    final statusFgColor = switch (item.status) {
      OfflinePunchStatus.pending => const Color(0xFFD97706),
      OfflinePunchStatus.syncing => const Color(0xFF2563EB),
      OfflinePunchStatus.failed => const Color(0xFF4B5563),
      OfflinePunchStatus.rejected => const Color(0xFFDC2626),
      OfflinePunchStatus.synced => const Color(0xFF059669),
    };

    final statusIcon = switch (item.status) {
      OfflinePunchStatus.pending => Icons.cloud_upload_outlined,
      OfflinePunchStatus.syncing => Icons.sync_rounded,
      OfflinePunchStatus.failed => Icons.error_outline_rounded,
      OfflinePunchStatus.rejected => Icons.person_off_rounded,
      OfflinePunchStatus.synced => Icons.check_circle_outline_rounded,
    };

    final statusLabel = switch (item.status) {
      OfflinePunchStatus.pending => 'Pending Upload',
      OfflinePunchStatus.syncing => 'Uploading...',
      OfflinePunchStatus.failed => 'Sync Failed',
      OfflinePunchStatus.rejected => 'Rejected (Face Mismatch)',
      OfflinePunchStatus.synced => 'Uploaded',
    };

    final punchTypeLabel = (item.punchType == 'check_out' || item.punchType == 'clock_out')
        ? 'Clock Out'
        : 'Clock In';

    final similarity = item.similarityScore;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isRejected
              ? const Color(0xFFFCA5A5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: item.isRejected ? 1.5 : 1.0,
        ),
      ),
      color: item.isRejected
          ? const Color(0xFFFFF5F5)
          : theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Photo + Time + Type + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo thumbnail or face icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: photoBytes != null
                      ? Image.memory(
                          photoBytes,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.face_rounded,
                            color: theme.colorScheme.primary,
                            size: 26,
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusFgColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusFgColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              punchTypeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(item.capturedAt),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (similarity != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Similarity Match: ${(similarity > 1.0 ? similarity : similarity * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.isRejected
                                ? const Color(0xFFDC2626)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Rejection reason banner if rejected or error
            if (item.lastError != null && item.lastError!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isRejected
                      ? const Color(0xFFFEE2E2)
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item.isRejected
                        ? const Color(0xFFFCA5A5)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.isRejected
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: item.isRejected
                          ? const Color(0xFFDC2626)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.lastError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: item.isRejected
                              ? const Color(0xFF991B1B)
                              : theme.colorScheme.onSurface,
                          fontWeight: item.isRejected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Actions row: Retry & Delete
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.isRejected || item.isFailed)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry Sync', style: TextStyle(fontSize: 12)),
                    onPressed: isSyncing ? null : onRetry,
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOfflinePunchesView extends StatelessWidget {
  const _EmptyOfflinePunchesView({
    required this.filterIndex,
    required this.totalCount,
  });

  final int filterIndex;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiltered = filterIndex != 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_list_off_rounded
                    : Icons.cloud_done_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No Punches in this Filter' : 'No Offline Punches',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'There are no offline punches matching the selected status.'
                  : 'All your attendance punches are successfully synced with the server.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
