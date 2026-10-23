import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/requests/application/requests_providers.dart';
import 'package:tks_nexa_attendance/features/requests/domain/regularization_request.dart';

class RegularizationRequestBottomSheet extends ConsumerStatefulWidget {
  const RegularizationRequestBottomSheet({
    super.key,
    this.initialDate,
    this.initialPunchType,
  });

  final DateTime? initialDate;
  final String? initialPunchType;

  static void show(BuildContext context, {DateTime? initialDate, String? initialPunchType}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegularizationRequestBottomSheet(
        initialDate: initialDate,
        initialPunchType: initialPunchType,
      ),
    );
  }

  @override
  ConsumerState<RegularizationRequestBottomSheet> createState() =>
      _RegularizationRequestBottomSheetState();
}

class _RegularizationRequestBottomSheetState
    extends ConsumerState<RegularizationRequestBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  String _punchType = 'check_in';
  TimeOfDay _requestedTime = const TimeOfDay(hour: 9, minute: 0);
  final _reasonController = TextEditingController();
  bool _submitting = false;
  RegularizationMeta? _meta;
  bool _loadingMeta = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (widget.initialPunchType != null && widget.initialPunchType!.isNotEmpty) {
      _punchType = widget.initialPunchType!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMeta();
    });
  }

  Future<void> _fetchMeta() async {
    if (!mounted) return;
    setState(() => _loadingMeta = true);
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    try {
      final meta = await ref.read(requestsApiProvider).fetchRegularizationMeta(dateStr);
      if (mounted) {
        setState(() {
          _meta = meta;
          _loadingMeta = false;
          if (widget.initialPunchType == null && meta?.isMissedCheckout == true) {
            _punchType = 'check_out';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  void _applySuggestedCheckout(String exitStr) {
    final parsed = _parseTimeOfDay(exitStr);
    if (parsed != null) {
      setState(() {
        _requestedTime = parsed;
        _punchType = 'check_out';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-filled suggested checkout time: $exitStr'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  TimeOfDay? _parseTimeOfDay(String s) {
    try {
      final trimmed = s.trim();
      final match12 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$', caseSensitive: false).firstMatch(trimmed);
      if (match12 != null) {
        var hour = int.parse(match12.group(1)!);
        final min = int.parse(match12.group(2)!);
        final period = match12.group(4)!.toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return TimeOfDay(hour: hour, minute: min);
      }
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0].trim()), minute: int.parse(parts[1].trim()));
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _submitting = true);

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_requestedTime.hour.toString().padLeft(2, '0')}:${_requestedTime.minute.toString().padLeft(2, '0')}';

    try {
      await ref.read(requestsApiProvider).submitRegularization(
        date: dateStr,
        punchType: _punchType,
        requestedPunchTime: timeStr,
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;
      ref.invalidate(regularizationsProvider);
      ref.invalidate(requestsOverviewProvider);

      Navigator.of(context).pop();
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26),
              SizedBox(width: 10),
              Text('Request Submitted', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            'Your regularization request for $dateStr (${_requestedTime.format(context)}) has been submitted to your line manager.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Great'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e is AppFailure ? e.message : e.toString();
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 26),
              SizedBox(width: 10),
              Text('Cannot Submit', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(
            errorMsg,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Regularization / Missed Punch Request',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(
                'Submit an attendance correction for missed check in/out or grace deductions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              // Date Selector
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setState(() => _selectedDate = d);
                    _fetchMeta();
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(
                  'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              if (_meta != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _meta!.remainingThisMonth > 0
                        ? theme.colorScheme.primary.withValues(alpha: 0.08)
                        : const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _meta!.remainingThisMonth > 0
                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                          : const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _meta!.remainingThisMonth > 0
                            ? Icons.info_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: _meta!.remainingThisMonth > 0
                            ? theme.colorScheme.primary
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _meta!.remainingThisMonth > 0
                              ? 'Monthly Quota: ${_meta!.remainingThisMonth} of ${_meta!.monthlyLimit} requests remaining'
                              : 'Monthly Regularization Quota Exceeded (0 remaining)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _meta!.remainingThisMonth > 0
                                ? theme.colorScheme.primary
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Punch Type Dropdown
              DropdownButtonFormField<String>(
                value: _punchType,
                decoration: const InputDecoration(labelText: 'Missed Attendance Type'),
                items: const [
                  DropdownMenuItem(value: 'check_in', child: Text('Missed Check-In')),
                  DropdownMenuItem(value: 'check_out', child: Text('Missed Check-Out')),
                  DropdownMenuItem(value: 'both', child: Text('Full Day Correction')),
                  DropdownMenuItem(value: 'grace_deduction', child: Text('Grace Time Waiver')),
                ],
                onChanged: (val) => setState(() => _punchType = val ?? 'check_in'),
              ),
              const SizedBox(height: 14),
              // Requested Time Selector
              OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _requestedTime,
                  );
                  if (t != null) setState(() => _requestedTime = t);
                },
                icon: const Icon(Icons.access_time_rounded, size: 18),
                label: Text(
                  'Actual Time: ${_requestedTime.format(context)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              if (_meta?.suggestedCheckoutTime != null && _meta!.suggestedCheckoutTime!.isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _applySuggestedCheckout(_meta!.suggestedCheckoutTime!),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Smart 30-Day Clean Average Exit (Shift Capped)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              Text(
                                '${_meta!.suggestedCheckoutTime!} (Tap to Auto-fill)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.touch_app_rounded, size: 18, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Reason
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for Regularization',
                  hintText: 'e.g., Biometric terminal offline, field visit, mobile battery issue',
                ),
                validator: (val) => val == null || val.trim().length < 8
                    ? 'Please provide a reason (at least 8 characters).'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_submitting || (_meta != null && _meta!.remainingThisMonth <= 0))
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Regularization Request', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

