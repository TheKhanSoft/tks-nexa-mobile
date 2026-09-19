import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/features/attendance/application/camera_corroboration_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/camera_corroboration.dart';

class CameraVerificationScreen extends ConsumerStatefulWidget {
  const CameraVerificationScreen({required this.initialResult, super.key});

  final CameraCorroborationResult initialResult;

  @override
  ConsumerState<CameraVerificationScreen> createState() =>
      _CameraVerificationScreenState();
}

class _CameraVerificationScreenState
    extends ConsumerState<CameraVerificationScreen>
    with WidgetsBindingObserver {
  Timer? _countdownTimer;
  Timer? _pollTimer;
  late CameraCorroborationResult _result;
  Duration _remaining = Duration.zero;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _result = widget.initialResult;
    _refreshCountdown();
    _startMonitoringIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCountdown();
      _pollStatus();
    }
  }

  void _startMonitoringIfNeeded() {
    final challengeId = _result.cameraChallengeId;
    if (_result.status.isTerminal || challengeId == null) return;
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshCountdown(),
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollStatus());
  }

  void _refreshCountdown() {
    final expiresAt = _result.expiresAt;
    final now = ref.read(cameraClockProvider)();
    final remaining = expiresAt?.difference(now) ?? Duration.zero;
    if (!mounted) {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
      return;
    }
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  Future<void> _pollStatus() async {
    final challengeId = _result.cameraChallengeId;
    if (_polling || _result.status.isTerminal || challengeId == null) return;
    _polling = true;
    try {
      final next = await ref
          .read(cameraCorroborationServiceProvider)
          .getStatus(cameraChallengeId: challengeId);
      if (!mounted) return;
      setState(
        () => _result = CameraCorroborationResult(
          status: next.status,
          cameraChallengeId:
              next.cameraChallengeId ?? _result.cameraChallengeId,
          expiresAt: next.expiresAt ?? _result.expiresAt,
          message: next.message,
          remainingSeconds: next.remainingSeconds,
          matchedCamera: next.matchedCamera,
        ),
      );
      _refreshCountdown();
      if (next.status.isTerminal) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
      }
    } on Object {
      if (!mounted) return;
      setState(
        () => _result = CameraCorroborationResult(
          status: CameraCorroborationStatus.unavailable,
          cameraChallengeId: _result.cameraChallengeId,
          expiresAt: _result.expiresAt,
        ),
      );
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(_result.status);
    return Scaffold(
      appBar: AppBar(title: const Text('Additional Verification')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: visual.color.withValues(alpha: 0.14),
                    child: Icon(visual.icon, size: 48, color: visual.color),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    visual.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _result.message?.trim().isNotEmpty == true
                        ? _result.message!
                        : visual.message,
                    textAlign: TextAlign.center,
                  ),
                  if (_result.matchedCamera case final camera?) ...[
                    const SizedBox(height: 10),
                    Text(
                      camera,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_isWaiting(_result.status)) ...[
                    const SizedBox(height: 28),
                    Text(
                      _remaining == Duration.zero
                          ? 'Waiting for server confirmation'
                          : 'Approximately ${_formatDuration(_remaining)} remaining',
                      key: const Key('camera_countdown'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'You may leave this screen open. Attendance time and '
                      'challenge expiry are determined by the server.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_result.status.isTerminal)
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: Text(
                        _result.status == CameraCorroborationStatus.expired ||
                                _result.status ==
                                    CameraCorroborationStatus.failed
                            ? 'Return and try again'
                            : 'Done',
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _polling ? null : _pollStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check status'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isWaiting(CameraCorroborationStatus status) {
    return status == CameraCorroborationStatus.challengeRequired ||
        status == CameraCorroborationStatus.waitingForCamera ||
        status == CameraCorroborationStatus.unavailable;
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  _CameraVisual _visualFor(CameraCorroborationStatus status) {
    return switch (status) {
      CameraCorroborationStatus.notRequired => const _CameraVisual(
        icon: Icons.check_circle,
        color: Colors.green,
        title: 'Attendance verified',
        message: 'No additional on-site verification is required.',
      ),
      CameraCorroborationStatus.alreadyCorroborated => const _CameraVisual(
        icon: Icons.verified,
        color: Colors.green,
        title: 'Attendance verified',
        message: 'Your recent on-site verification was confirmed.',
      ),
      CameraCorroborationStatus.challengeRequired ||
      CameraCorroborationStatus.waitingForCamera => const _CameraVisual(
        icon: Icons.videocam_outlined,
        color: Colors.blue,
        title: 'Additional Verification Required',
        message:
            'For security, please pass through a registered attendance '
            'camera within the time shown below.',
      ),
      CameraCorroborationStatus.verified => const _CameraVisual(
        icon: Icons.verified,
        color: Colors.green,
        title: 'Verification complete',
        message: 'The attendance system confirmed your on-site verification.',
      ),
      CameraCorroborationStatus.expired => const _CameraVisual(
        icon: Icons.timer_off_outlined,
        color: Colors.orange,
        title: 'Verification time expired',
        message: 'Return to attendance and start a new secure attempt.',
      ),
      CameraCorroborationStatus.failed => const _CameraVisual(
        icon: Icons.info_outline,
        color: Colors.orange,
        title: 'Verification not completed',
        message: 'Return to attendance for safe retry instructions.',
      ),
      CameraCorroborationStatus.unavailable => const _CameraVisual(
        icon: Icons.sync_problem_outlined,
        color: Colors.orange,
        title: 'Checking verification status',
        message:
            'Status is temporarily unavailable. Continue to follow the '
            'on-site instruction while the app reconnects.',
      ),
    };
  }
}

class _CameraVisual {
  const _CameraVisual({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}
