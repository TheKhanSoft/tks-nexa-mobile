import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/regularization_request_bottom_sheet.dart';
import 'package:tks_nexa_attendance/features/requests/application/requests_providers.dart';
import 'package:tks_nexa_attendance/features/requests/domain/leave_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/official_duty_request.dart';
import 'package:tks_nexa_attendance/features/requests/domain/regularization_request.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showApplyLeaveSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ApplyLeaveBottomSheet(),
    );
  }

  void _showApplyOfficialDutySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ApplyOfficialDutyBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overviewAsync = ref.watch(requestsOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave & Duty Requests', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Leaves'),
                      if (overviewAsync.value?.pendingLeaveRequests case final count? when count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Official Duties'),
                      if (overviewAsync.value?.pendingDutyRequests case final count? when count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Regularizations'),
                      if (overviewAsync.value?.pendingRegularizationRequests case final count? when count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LeaveRequestsTab(),
          _OfficialDutyRequestsTab(),
          _RegularizationRequestsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showApplyLeaveSheet(context);
          } else if (_tabController.index == 1) {
            _showApplyOfficialDutySheet(context);
          } else {
            RegularizationRequestBottomSheet.show(context);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          switch (_tabController.index) {
            0 => 'Apply Leave',
            1 => 'New Duty Request',
            _ => 'Regularize Attendance',
          },
        ),
      ),
    );
  }
}

class _LeaveRequestsTab extends ConsumerWidget {
  const _LeaveRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(leaveRequestsProvider);
    final typesAsync = ref.watch(leaveTypesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (typesAsync.value case final types? when types.isNotEmpty && types.first.showBalance) ...[
          const Text(
            'Your Year Entitlements (2026)',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final lt = types[index];
                return _LeaveBalanceCard(leaveType: lt);
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          'Leave Request History',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
        ),
        const SizedBox(height: 12),
        leavesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (err, _) => _ErrorStateCard(error: err, onRetry: () => ref.invalidate(leaveRequestsProvider)),
          data: (leaves) {
            if (leaves.isEmpty) {
              return const _EmptyStateCard(
                icon: Icons.event_busy_rounded,
                title: 'No Leave Requests',
                message: 'You have not submitted any leave applications yet.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaves.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _LeaveRequestTile(request: leaves[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.leaveType});

  final LeaveType leaveType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ent = leaveType.entitlement;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leaveType.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  leaveType.code,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${ent.remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${ent.allocated.toStringAsFixed(0)} days',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Used: ${ent.used.toStringAsFixed(0)} · Pending: ${ent.pending.toStringAsFixed(0)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestTile extends ConsumerWidget {
  const _LeaveRequestTile({required this.request});

  final LeaveRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (statusColor, statusIcon) = _statusVisuals(request.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.leaveTypeName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.reference,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      request.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.markedToName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forward_rounded, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    'Forwarded/Marked to: ${request.markedToName}',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.formattedDates,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              if (request.approvedDaysCount != null &&
                  request.isApproved &&
                  request.approvedDaysCount != request.daysCount) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Granted: ${request.approvedDaysCount}d',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${request.daysCount} days',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (request.isCancelled && request.cancellationReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Text(
                'Cancellation reason: ${request.cancellationReason}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (request.approvals.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final app in request.approvals)
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 15, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Manager: ${app.approverName} — ${app.action}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          if (request.canCancel || request.canReschedule) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (request.canReschedule) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => _ChangeLeaveDatesDialog(request: request),
                      );
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Change Dates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (request.canCancel) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => _CancelLeaveDialog(request: request),
                      );
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                    label: const Text('Cancel Leave', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _statusVisuals(String status) {
    final s = status.toLowerCase();
    if (s.contains('approved')) return (const Color(0xFF10B981), Icons.check_circle_rounded);
    if (s.contains('rejected')) return (const Color(0xFFEF4444), Icons.cancel_rounded);
    if (s.contains('cancelled')) return (const Color(0xFF9CA3AF), Icons.cancel_outlined);
    if (s.contains('forwarded')) return (const Color(0xFF2563EB), Icons.forward_rounded);
    return (const Color(0xFFF59E0B), Icons.pending_actions_rounded);
  }
}

class _CancelLeaveDialog extends ConsumerStatefulWidget {
  const _CancelLeaveDialog({required this.request});
  final LeaveRequest request;

  @override
  ConsumerState<_CancelLeaveDialog> createState() => _CancelLeaveDialogState();
}

class _CancelLeaveDialogState extends ConsumerState<_CancelLeaveDialog> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(requestsApiProvider).cancelLeave(
        widget.request.id,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(leaveTypesProvider);
      ref.invalidate(requestsOverviewProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave application cancelled successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppFailure ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
          SizedBox(width: 10),
          Text('Cancel Leave', style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to cancel your leave request for ${widget.request.formattedDates} (${widget.request.leaveTypeName})?',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason for cancellation (optional)',
              hintText: 'e.g., Plans changed, postponed',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Keep Leave'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          child: _submitting
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Cancel'),
        ),
      ],
    );
  }
}

class _ChangeLeaveDatesDialog extends ConsumerStatefulWidget {
  const _ChangeLeaveDatesDialog({required this.request});
  final LeaveRequest request;

  @override
  ConsumerState<_ChangeLeaveDatesDialog> createState() => _ChangeLeaveDatesDialogState();
}

class _ChangeLeaveDatesDialogState extends ConsumerState<_ChangeLeaveDatesDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.request.startDate;
    _endDate = widget.request.endDate;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final startStr =
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';

    try {
      await ref.read(requestsApiProvider).changeLeaveDates(
        id: widget.request.id,
        startDate: startStr,
        endDate: endStr,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(requestsOverviewProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave dates updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppFailure ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStr =
        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    final endStr =
        '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.edit_calendar_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 10),
          Text('Change Leave Dates', style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Adjust date range for ${widget.request.leaveTypeName}:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      setState(() {
                        _startDate = d;
                        if (_endDate.isBefore(d)) _endDate = d;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: Text('From: $startStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _endDate = d);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: Text('To: $endStr', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason for reschedule (optional)',
              hintText: 'e.g., Event rescheduled',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Update Dates'),
        ),
      ],
    );
  }
}

class _OfficialDutyRequestsTab extends ConsumerWidget {
  const _OfficialDutyRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dutiesAsync = ref.watch(officialDutyRequestsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        const Text(
          'Official Duty History',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
        ),
        const SizedBox(height: 12),
        dutiesAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          error: (err, _) => _ErrorStateCard(error: err, onRetry: () => ref.invalidate(officialDutyRequestsProvider)),
          data: (duties) {
            if (duties.isEmpty) {
              return const _EmptyStateCard(
                icon: Icons.business_center_outlined,
                title: 'No Official Duty Requests',
                message: 'You have not submitted any official duty assignments yet.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: duties.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _OfficialDutyTile(request: duties[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _OfficialDutyTile extends StatelessWidget {
  const _OfficialDutyTile({required this.request});

  final OfficialDutyRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = request.isApproved
        ? const Color(0xFF10B981)
        : request.isRejected
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final statusIcon = request.isApproved
        ? Icons.check_circle_rounded
        : request.isRejected
            ? Icons.cancel_rounded
            : Icons.pending_actions_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.dutyTypeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.reference,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      request.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.location,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                request.formattedDates,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Host: ${request.hostOfficeName}',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            request.purpose,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (request.hasDocument) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.attachment_rounded, size: 15, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Supporting Document Attached',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RegularizationRequestsTab extends ConsumerWidget {
  const _RegularizationRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regularizationsAsync = ref.watch(regularizationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(regularizationsProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attendance Regularizations',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2),
              ),
              TextButton.icon(
                onPressed: () => RegularizationRequestBottomSheet.show(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Request New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          regularizationsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => _ErrorStateCard(
              error: err,
              onRetry: () => ref.invalidate(regularizationsProvider),
            ),
            data: (records) {
              if (records.isEmpty) {
                return const _EmptyStateCard(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No Regularization Requests',
                  message: 'You have not submitted any attendance regularizations or missed punch requests yet.',
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  return _RegularizationTile(request: records[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RegularizationTile extends StatelessWidget {
  const _RegularizationTile({required this.request});

  final RegularizationRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (statusColor, statusIcon) = _statusVisuals(request.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.punchTypeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.reference,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      request.statusLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                request.formattedDate,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              if (request.formattedTime != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.access_time_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  request.formattedTime!,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.reasonLabel,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              if (request.employeeRemarks != null && request.employeeRemarks!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.employeeRemarks!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (request.approverRemarks != null && request.approverRemarks!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.comment_outlined, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${request.approverName ?? 'Manager'}: ${request.approverRemarks}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _statusVisuals(String status) {
    final s = status.toLowerCase();
    if (s.contains('approved')) return (const Color(0xFF10B981), Icons.check_circle_rounded);
    if (s.contains('rejected')) return (const Color(0xFFEF4444), Icons.cancel_rounded);
    return (const Color(0xFFF59E0B), Icons.pending_actions_rounded);
  }
}

class _ErrorStateCard extends StatelessWidget {
  const _ErrorStateCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppFailure
        ? (error as AppFailure).message
        : error.toString();
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyLeaveBottomSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveBottomSheet();

  @override
  ConsumerState<_ApplyLeaveBottomSheet> createState() => _ApplyLeaveBottomSheetState();
}

class _ApplyLeaveBottomSheetState extends ConsumerState<_ApplyLeaveBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedLeaveTypeId;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedLeaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a leave type.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(requestsApiProvider).applyLeave(
            leaveTypeId: _selectedLeaveTypeId!,
            startDate: '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
            endDate: '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
            reason: _reasonController.text.trim(),
          );
      ref.invalidate(leaveRequestsProvider);
      ref.invalidate(leaveTypesProvider);
      ref.invalidate(requestsOverviewProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application submitted successfully.')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(leaveTypesProvider);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Apply for Leave',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const SizedBox(height: 20),
              typesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error: $err'),
                data: (types) => DropdownButtonFormField<int>(
                  value: _selectedLeaveTypeId,
                  decoration: const InputDecoration(labelText: 'Leave Type'),
                  items: types
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.showBalance
                                ? '${t.name} (${t.entitlement.remaining.toStringAsFixed(0)} days left)'
                                : t.name),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedLeaveTypeId = val),
                  validator: (val) => val == null ? 'Select leave type.' : null,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('From: ${_startDate.toIso8601String().split('T').first}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _endDate = d);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('To: ${_endDate.toIso8601String().split('T').first}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for leave',
                  hintText: 'Enter at least 10 characters explaining your leave.',
                ),
                validator: (val) => val == null || val.trim().length < 10
                    ? 'Enter at least 10 characters.'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplyOfficialDutyBottomSheet extends ConsumerStatefulWidget {
  const _ApplyOfficialDutyBottomSheet();

  @override
  ConsumerState<_ApplyOfficialDutyBottomSheet> createState() => _ApplyOfficialDutyBottomSheetState();
}

class _ApplyOfficialDutyBottomSheetState extends ConsumerState<_ApplyOfficialDutyBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  String _dutyType = 'official_tour';
  int? _hostOfficeId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _locationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _remarksController = TextEditingController();
  final _documentPathController = TextEditingController();
  bool _submitting = false;

  bool get _isRetrospective => _startDate.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  @override
  void dispose() {
    _locationController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    _documentPathController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_hostOfficeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a host office/department.')),
      );
      return;
    }
    if (_isRetrospective && (_documentPathController.text.trim().isEmpty || _remarksController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retrospective duties require explanation remarks and a supporting document path.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      File? docFile;
      if (_documentPathController.text.trim().isNotEmpty) {
        final f = File(_documentPathController.text.trim());
        if (f.existsSync()) docFile = f;
      }

      await ref.read(requestsApiProvider).applyOfficialDuty(
            dutyType: _dutyType,
            startDate: '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
            endDate: '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
            location: _locationController.text.trim(),
            hostOfficeId: _hostOfficeId!,
            purpose: _purposeController.text.trim(),
            remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
            document: docFile,
          );
      ref.invalidate(officialDutyRequestsProvider);
      ref.invalidate(requestsOverviewProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official duty request submitted successfully.')),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dutyTypes = [
      ('official_tour', 'Official Tour'),
      ('training', 'Training'),
      ('field_visit', 'Field Visit'),
      ('temporary_duty', 'Temporary Duty'),
      ('conference', 'Conference'),
      ('deputation', 'Deputation'),
      ('other', 'Other'),
    ];

    final officesAsync = ref.watch(hostOfficesProvider);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'New Official Duty Request',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _dutyType,
                decoration: const InputDecoration(labelText: 'Duty Type'),
                items: dutyTypes.map((dt) => DropdownMenuItem(value: dt.$1, child: Text(dt.$2))).toList(),
                onChanged: (val) => setState(() => _dutyType = val ?? 'official_tour'),
              ),
              const SizedBox(height: 16),
              officesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (err, _) => Text('Error: $err'),
                data: (offices) => DropdownButtonFormField<int>(
                  value: _hostOfficeId,
                  decoration: const InputDecoration(labelText: 'Host Office / Department'),
                  items: offices.map((o) => DropdownMenuItem(value: o.id, child: Text(o.name))).toList(),
                  onChanged: (val) => setState(() => _hostOfficeId = val),
                  validator: (val) => val == null ? 'Select host office.' : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location / Venue', hintText: 'e.g., HEC Headquarters Islamabad'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter location.' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() {
                            _startDate = d;
                            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('From: ${_startDate.toIso8601String().split('T').first}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _endDate = d);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text('To: ${_endDate.toIso8601String().split('T').first}'),
                    ),
                  ),
                ],
              ),
              if (_isRetrospective) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                  ),
                  child: const Text(
                    '⚠️ This request is retrospective (past date). Explanation remarks and supporting document path are strictly required.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Purpose of duty', hintText: 'Enter at least 10 characters.'),
                validator: (val) => val == null || val.trim().length < 10 ? 'Enter at least 10 characters.' : null,
              ),
              if (_isRetrospective) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Retrospective Explanation Remarks'),
                  validator: (val) => _isRetrospective && (val == null || val.trim().isEmpty) ? 'Remarks required for past dates.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _documentPathController,
                  decoration: const InputDecoration(labelText: 'Document File Path (*Required)', hintText: '/path/to/evidence.pdf'),
                  validator: (val) => _isRetrospective && (val == null || val.trim().isEmpty) ? 'Document path required for past dates.' : null,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Official Duty Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
