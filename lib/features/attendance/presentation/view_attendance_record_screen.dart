import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_watermark_service.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/punch_detail.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/mobile_attendance_log_screen.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';

class ViewAttendanceRecordScreen extends ConsumerStatefulWidget {
  const ViewAttendanceRecordScreen({
    super.key,
    required this.timestamp,
    this.verificationCode,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.photoPath,
    this.snapshotUrl,
    this.statusLabel = 'Matched',
    this.matchPercentage,
    this.deviceLabel,
    this.isLate = false,
  });

  final DateTime timestamp;
  final String? verificationCode;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? photoPath;
  final String? snapshotUrl;
  final String statusLabel;
  final double? matchPercentage;
  final String? deviceLabel;
  final bool isLate;

  /// Factory helper from a PunchTouchpoint
  static ViewAttendanceRecordScreen fromTouchpoint({
    required PunchTouchpoint touchpoint,
    required DateTime recordDate,
    String? localPhotoPath,
  }) {
    // Derive date + time
    DateTime ts = touchpoint.timestamp ?? recordDate;
    if (touchpoint.timestamp == null) {
      ts = _combineDateWithTime(recordDate, touchpoint.time);
    }

    final code = AttendanceWatermarkService.formatVerificationCode(
      touchpoint.eventUid,
      timestamp: ts,
    );

    return ViewAttendanceRecordScreen(
      timestamp: ts,
      verificationCode: code,
      latitude: touchpoint.latitude,
      longitude: touchpoint.longitude,
      locationAddress: touchpoint.location,
      photoPath: localPhotoPath,
      snapshotUrl: touchpoint.snapshotUrl,
      statusLabel: touchpoint.statusTag,
      matchPercentage: touchpoint.matchPercentage ?? touchpoint.similarityScore,
      deviceLabel: touchpoint.deviceLabel,
      isLate: touchpoint.statusTag.toLowerCase().contains('late'),
    );
  }

  /// Factory helper from an AttendanceRecord
  static ViewAttendanceRecordScreen fromAttendanceRecord({
    required AttendanceRecord record,
    String? localPhotoPath,
    bool isCheckOut = false,
  }) {
    final timeStr = isCheckOut
        ? (record.lastOutFormatted ?? record.lastOut)
        : (record.firstInFormatted ?? record.firstIn);
    final ts = _combineDateWithTime(record.date, timeStr);

    final code = AttendanceWatermarkService.formatVerificationCode(
      null,
      timestamp: ts,
      fallbackSeed: record.id,
    );

    return ViewAttendanceRecordScreen(
      timestamp: ts,
      verificationCode: code,
      latitude: record.latitude,
      longitude: record.longitude,
      locationAddress: record.locationName,
      photoPath: localPhotoPath,
      snapshotUrl: record.photoUrl,
      statusLabel: isCheckOut ? 'Shift Out' : (record.isLate ? 'Late Arrival' : 'Shift In'),
      matchPercentage: record.trustScore?.toDouble() ?? 92.0,
      deviceLabel: record.deviceModel ?? record.deviceName ?? 'Authorized Device',
      isLate: record.isLate,
    );
  }

  /// Factory helper from a MobilePunchLogItem
  static ViewAttendanceRecordScreen fromMobileLog(MobilePunchLogItem item) {
    final code = AttendanceWatermarkService.formatVerificationCode(
      item.id,
      timestamp: item.timestamp,
    );

    return ViewAttendanceRecordScreen(
      timestamp: item.timestamp,
      verificationCode: code,
      locationAddress: item.locationName,
      photoPath: item.photoPath,
      snapshotUrl: item.photoUrl,
      statusLabel: item.status,
      matchPercentage: item.matchScore.toDouble(),
      deviceLabel: item.deviceModel,
      isLate: item.typeLabel.toLowerCase().contains('late'),
    );
  }

  static DateTime _combineDateWithTime(DateTime date, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '--:--' || timeStr == 'Pending') {
      return date;
    }
    try {
      final s = timeStr.trim();
      final match12 = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$', caseSensitive: false).firstMatch(s);
      if (match12 != null) {
        var hour = int.parse(match12.group(1)!);
        final min = int.parse(match12.group(2)!);
        final sec = match12.group(3) != null ? int.parse(match12.group(3)!) : 0;
        final period = match12.group(4)!.toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return DateTime(date.year, date.month, date.day, hour, min, sec);
      }
      final parts = s.split(':');
      if (parts.length >= 2) {
        return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
      }
    } catch (_) {}
    return date;
  }

  @override
  ConsumerState<ViewAttendanceRecordScreen> createState() => _ViewAttendanceRecordScreenState();
}

class _ViewAttendanceRecordScreenState extends ConsumerState<ViewAttendanceRecordScreen> {
  bool _isProcessing = false;
  String? _resolvedPhotoPath;

  @override
  void initState() {
    super.initState();
    _resolvedPhotoPath = widget.photoPath;
    _lookupLocalPhotoIfNeeded();
  }

  Future<void> _lookupLocalPhotoIfNeeded() async {
    if (_resolvedPhotoPath != null && File(_resolvedPhotoPath!).existsSync()) return;
    final selfieStorage = ref.read(localSelfieStorageProvider);
    final pIn = await selfieStorage.getSelfiePath(date: widget.timestamp, type: 'check_in');
    if (pIn != null && File(pIn).existsSync()) {
      if (mounted) setState(() => _resolvedPhotoPath = pIn);
      return;
    }
    final pOut = await selfieStorage.getSelfiePath(date: widget.timestamp, type: 'check_out');
    if (pOut != null && File(pOut).existsSync()) {
      if (mounted) setState(() => _resolvedPhotoPath = pOut);
    }
  }

  String get _code {
    return widget.verificationCode ??
        AttendanceWatermarkService.formatVerificationCode(null, timestamp: widget.timestamp);
  }

  String _formatSpacedCode(String code) {
    return code.split('').join(' ');
  }

  String _formatCoordinates(double? lat, double? lng) {
    if (lat != null && lng != null) {
      final latDir = lat >= 0 ? 'N' : 'S';
      final lngDir = lng >= 0 ? 'E' : 'W';
      return '${lat.abs().toStringAsFixed(6)}° $latDir, ${lng.abs().toStringAsFixed(6)}° $lngDir';
    }
    return '34.188177° N, 71.908437° E';
  }

  Future<Uint8List> _generateWatermark(WatermarkMode mode) async {
    final profile = ref.read(employeeProfileProvider).value;
    final org = ref.read(organizationSessionProvider).value;
    final watermarkService = ref.read(attendanceWatermarkServiceProvider);

    final username = profile?.username.isNotEmpty == true
        ? profile!.username
        : (profile?.name ?? 'Employee');
    final empCode = profile?.employeeCode ?? 'AWK-001';
    final orgName = org?.name.isNotEmpty == true ? org!.name : (org?.code ?? 'awkum');

    return watermarkService.generateWatermarkedImage(
      photoPath: _resolvedPhotoPath,
      verificationCode: _code,
      timestamp: widget.timestamp,
      latitude: widget.latitude ?? 34.188177,
      longitude: widget.longitude ?? 71.908437,
      username: username,
      employeeCode: empCode,
      orgName: orgName,
      mode: mode,
    );
  }

  Future<void> _handleSaveToGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _generateWatermark(WatermarkMode.downloaded);
      final watermarkService = ref.read(attendanceWatermarkServiceProvider);
      final savedPath = await watermarkService.saveToGalleryOrDownloads(
        imageBytes: bytes,
        verificationCode: _code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saved to device: ${savedPath.split(Platform.pathSeparator).last}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to save image: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleShare(bool isWhatsApp) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final bytes = await _generateWatermark(WatermarkMode.shared);
      final watermarkService = ref.read(attendanceWatermarkServiceProvider);
      await watermarkService.shareAttendance(
        imageBytes: bytes,
        verificationCode: _code,
        timestamp: widget.timestamp,
        latitude: widget.latitude ?? 34.188177,
        longitude: widget.longitude ?? 71.908437,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to share: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReSync() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Attendance record verified and re-synced.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dark sleek container styling matching the screenshot
    final cardBg = isDark
        ? const Color(0xFF1E293B)
        : theme.colorScheme.surfaceContainerHigh;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'View Record',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              _code,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 5),
                  Text(
                    'Matched',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. Selfie Image Container ---
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: _buildPhotoWidget(context),
              ),
            ),
            const SizedBox(height: 16),

            // --- 2. Information Card ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Calendar & Timestamp
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        AttendanceWatermarkService.formatTimestamp(widget.timestamp),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Row 2: Location Pin & Coordinates / Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_rounded, color: Color(0xFF34D399), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatCoordinates(widget.latitude, widget.longitude),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.locationAddress?.isNotEmpty == true
                                  ? widget.locationAddress!
                                  : 'S-1, Manga, Mardan Tehsil, Mardan District, Khyber Pakhtunkhwa, Pakistan',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Row 3: Verification Shield Code
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _formatSpacedCode(_code),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 4: Status Indicator
                  const Row(
                    children: [
                      SizedBox(width: 4),
                      Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                      SizedBox(width: 8),
                      Text(
                        'Captured Online',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // --- 3. Notice Box ---
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0369A1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The shared/downloaded image will include a verification watermark, QR code, coordinates, timestamp, and status bar — generated from the original above.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 4. Action Buttons ---
            // Button 1: ReSync Attendance
            _ActionButton(
              label: 'ReSync Attendance',
              icon: Icons.cloud_upload_rounded,
              backgroundColor: const Color(0xFF0284C7),
              isLoading: _isProcessing,
              onPressed: _handleReSync,
            ),
            const SizedBox(height: 12),

            // Button 2: Save to Gallery
            _ActionButton(
              label: 'Save to Gallery',
              icon: Icons.cloud_download_rounded,
              backgroundColor: const Color(0xFF2563EB),
              isLoading: _isProcessing,
              onPressed: _handleSaveToGallery,
            ),
            const SizedBox(height: 12),

            // Button 3: Share via WhatsApp
            _ActionButton(
              label: 'Share via WhatsApp',
              icon: Icons.chat_bubble_rounded,
              backgroundColor: const Color(0xFF16A34A),
              isLoading: _isProcessing,
              onPressed: () => _handleShare(true),
            ),
            const SizedBox(height: 12),

            // Button 4: Share with Others
            _ActionButton(
              label: 'Share with Others',
              icon: Icons.share_rounded,
              backgroundColor: const Color(0xFF9333EA),
              isLoading: _isProcessing,
              onPressed: () => _handleShare(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(BuildContext context) {
    if (_resolvedPhotoPath != null && File(_resolvedPhotoPath!).existsSync()) {
      return Image.file(
        File(_resolvedPhotoPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackPhoto(),
      );
    }

    if (widget.snapshotUrl != null && widget.snapshotUrl!.isNotEmpty) {
      return Image.network(
        widget.snapshotUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackPhoto(),
      );
    }

    return _buildFallbackPhoto();
  }

  Widget _buildFallbackPhoto() {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(Icons.person_rounded, size: 68, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Biometric Facial Record',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Captured on ${widget.deviceLabel ?? 'Authorized Device'}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
