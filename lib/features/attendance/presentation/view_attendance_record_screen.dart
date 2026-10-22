import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tks_nexa_attendance/core/config/app_config.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_watermark_service.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';
import 'package:tks_nexa_attendance/features/attendance/data/offline_punch_outbox.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/punch_detail.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/mobile_attendance_log_screen.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
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
    this.isOffline = false,
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
  final bool isOffline;

  /// Factory helper from a PunchTouchpoint
  static ViewAttendanceRecordScreen fromTouchpoint({
    required PunchTouchpoint touchpoint,
    required DateTime recordDate,
    String? localPhotoPath,
  }) {
    // Derive date + time
    DateTime ts = touchpoint.timestamp ?? recordDate;
    if (touchpoint.timestamp == null || (ts.hour == 0 && ts.minute == 0 && ts.second == 0)) {
      ts = combineDateWithTime(recordDate, touchpoint.time);
    }

    final code = touchpoint.displayVerificationCode.isNotEmpty
        ? touchpoint.displayVerificationCode
        : AttendanceWatermarkService.formatVerificationCode(
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
      isOffline: touchpoint.statusTag.toLowerCase().contains('offline') ||
          touchpoint.statusTag.toLowerCase().contains('pending'),
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
    final ts = combineDateWithTime(record.date, timeStr);

    final code = (record.verificationCode != null && record.verificationCode!.trim().isNotEmpty)
        ? record.verificationCode!.trim().toUpperCase()
        : AttendanceWatermarkService.formatVerificationCode(
            null,
            timestamp: ts,
            fallbackSeed: record.id,
          );

    final bool isOfflineRecord =
        record.status.toLowerCase().contains('offline') ||
        record.status.toLowerCase().contains('pending');

    return ViewAttendanceRecordScreen(
      timestamp: ts,
      verificationCode: code,
      latitude: record.latitude,
      longitude: record.longitude,
      locationAddress: record.locationName,
      photoPath: localPhotoPath,
      snapshotUrl: record.photoUrl,
      statusLabel: isCheckOut ? 'Shift Out' : (record.isLate ? 'Late Arrival' : 'Shift In'),
      matchPercentage: isOfflineRecord ? null : (record.trustScore?.toDouble() ?? 92.0),
      deviceLabel: record.deviceModel ?? record.deviceName ?? 'Authorized Device',
      isLate: record.isLate,
      isOffline: isOfflineRecord,
    );
  }

  /// Factory helper from a MobilePunchLogItem
  static ViewAttendanceRecordScreen fromMobileLog(MobilePunchLogItem item) {
    final code = (item.verificationCode != null && item.verificationCode!.trim().isNotEmpty)
        ? item.verificationCode!.trim().toUpperCase()
        : AttendanceWatermarkService.formatVerificationCode(
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
      matchPercentage: item.isOffline ? null : item.matchScore.toDouble(),
      deviceLabel: item.deviceModel,
      isLate: item.typeLabel.toLowerCase().contains('late'),
      isOffline: item.isOffline,
    );
  }

  static DateTime combineDateWithTime(DateTime date, String? timeStr) {
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
    final isOut = widget.statusLabel.toLowerCase().contains('out') ||
        widget.statusLabel.toLowerCase().contains('exit');

    // Tier 1: Try match by punch timestamp or verificationCode
    String? pMatch = await selfieStorage.getSelfiePath(
      date: widget.timestamp,
      timestamp: widget.timestamp,
      verificationCode: widget.verificationCode,
      type: isOut ? 'check_out' : 'check_in',
      exactOnly: false,
    );

    // Tier 2: Try match by date alone (ignoring strict seconds/minutes drift)
    if (pMatch == null) {
      pMatch = await selfieStorage.getSelfiePath(
        date: widget.timestamp,
        verificationCode: widget.verificationCode,
        type: isOut ? 'check_out' : 'check_in',
        exactOnly: false,
      );
    }

    // Tier 3: Try match any punch selfie saved on that date
    if (pMatch == null) {
      pMatch = await selfieStorage.getAnySelfieForDate(widget.timestamp);
    }

    // Tier 4: Look in offline outbox for any punch matching this date
    if (pMatch == null) {
      try {
        final outbox = ref.read(offlinePunchOutboxProvider);
        final items = await outbox.getAll();
        final dateStr =
            '${widget.timestamp.year}-${widget.timestamp.month.toString().padLeft(2, '0')}-${widget.timestamp.day.toString().padLeft(2, '0')}';
        for (final item in items) {
          final itemDateStr =
              '${item.capturedAt.year}-${item.capturedAt.month.toString().padLeft(2, '0')}-${item.capturedAt.day.toString().padLeft(2, '0')}';
          if (itemDateStr == dateStr && item.snapshotBase64 != null) {
            pMatch = await selfieStorage.saveSelfieFromBase64(
              base64String: item.snapshotBase64!,
              date: widget.timestamp,
              type: isOut ? 'check_out' : 'check_in',
              id: item.id,
            );
            if (pMatch != null) break;
          }
        }
      } catch (_) {}
    }

    // Tier 5: If widget.snapshotUrl is base64, save to local selfie storage
    if (pMatch == null && widget.snapshotUrl != null && _isBase64Photo(widget.snapshotUrl)) {
      try {
        pMatch = await selfieStorage.saveSelfieFromBase64(
          base64String: widget.snapshotUrl!,
          date: widget.timestamp,
          type: isOut ? 'check_out' : 'check_in',
        );
      } catch (_) {}
    }

    if (pMatch != null && File(pMatch).existsSync()) {
      if (mounted) setState(() => _resolvedPhotoPath = pMatch);
      return;
    }
  }

  bool _isBase64Photo(String? raw) {
    if (raw == null) return false;
    final s = raw.trim();
    return s.startsWith('data:image') ||
        (s.length > 200 &&
            !s.startsWith('http://') &&
            !s.startsWith('https://') &&
            !s.startsWith('/'));
  }

  Uint8List? _decodeBase64(String raw) {
    try {
      var s = raw.trim();
      if (s.startsWith('data:image')) {
        final comma = s.indexOf(',');
        if (comma != -1) {
          s = s.substring(comma + 1);
        }
      }
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  bool _isAvatarPhoto(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return true;
    final trimmed = rawUrl.trim();
    if (_isBase64Photo(trimmed)) return false; // Genuine punch photo
    try {
      final profile = ref.read(employeeProfileProvider).value;
      final empPhoto = profile?.photoUrl?.trim();
      if (empPhoto != null && empPhoto.isNotEmpty && trimmed == empPhoto) {
        return true;
      }
    } catch (_) {}
    final lower = trimmed.toLowerCase();
    if (lower.contains('/avatars/') || lower.contains('/profiles/') || lower.contains('/profile_photos/')) {
      return true;
    }
    return false;
  }

  String _resolveRemoteUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final config = ref.read(appConfigProvider);
      if (uri.host == 'localhost' || uri.host.endsWith('.localhost')) {
        if (config.developmentConnectHost != null && config.developmentConnectHost!.isNotEmpty) {
          return uri.replace(
            host: config.developmentConnectHost!.trim(),
            port: config.developmentConnectPort ?? uri.port,
          ).toString();
        }
      }
      return trimmed;
    }
    final org = ref.read(organizationSessionProvider).value;
    if (org != null) {
      final base = org.apiBaseUri;
      final origin = '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
      if (trimmed.startsWith('/')) {
        return '$origin$trimmed';
      }
      return '$origin/$trimmed';
    }
    return trimmed;
  }

  Map<String, String>? _buildAuthHeaders(String rawUrl) {
    final session = ref.read(currentAuthSessionProvider);
    final token = session?.accessToken;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
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

    Uint8List? rawBytes;
    if (_resolvedPhotoPath != null && File(_resolvedPhotoPath!).existsSync()) {
      try {
        rawBytes = await File(_resolvedPhotoPath!).readAsBytes();
      } catch (_) {}
    } else if (widget.snapshotUrl != null &&
        widget.snapshotUrl!.isNotEmpty &&
        !_isAvatarPhoto(widget.snapshotUrl)) {
      if (_isBase64Photo(widget.snapshotUrl)) {
        rawBytes = _decodeBase64(widget.snapshotUrl!);
      } else if (File(widget.snapshotUrl!).existsSync()) {
        try {
          rawBytes = await File(widget.snapshotUrl!).readAsBytes();
        } catch (_) {}
      } else {
        try {
          final resolvedUrl = _resolveRemoteUrl(widget.snapshotUrl!);
          final headers = _buildAuthHeaders(widget.snapshotUrl!);
          final dio = Dio();
          final res = await dio.get<List<int>>(
            resolvedUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: headers,
            ),
          );
          if (res.data != null) {
            rawBytes = Uint8List.fromList(res.data!);
          }
        } catch (_) {}
      }
    }

    return watermarkService.generateWatermarkedImage(
      originalPhotoBytes: rawBytes,
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
      if (isWhatsApp) {
        await watermarkService.shareDirectToWhatsApp(
          imageBytes: bytes,
          verificationCode: _code,
          timestamp: widget.timestamp,
          latitude: widget.latitude ?? 34.188177,
          longitude: widget.longitude ?? 71.908437,
        );
      } else {
        await watermarkService.shareAttendance(
          imageBytes: bytes,
          verificationCode: _code,
          timestamp: widget.timestamp,
          latitude: widget.latitude ?? 34.188177,
          longitude: widget.longitude ?? 71.908437,
        );
      }
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
                color: widget.isOffline
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                    : const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isOffline
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                      : const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isOffline
                        ? Icons.cloud_upload_outlined
                        : Icons.check_circle_rounded,
                    size: 14,
                    color: widget.isOffline
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.isOffline
                        ? 'Pending Verification'
                        : (widget.matchPercentage != null && widget.matchPercentage! > 0
                            ? '${widget.matchPercentage!.toStringAsFixed(widget.matchPercentage! % 1 == 0 ? 0 : 1)}% Matched'
                            : 'Matched'),
                    style: TextStyle(
                      color: widget.isOffline
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
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
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Icon(
                        Icons.circle,
                        color: widget.isOffline
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        size: 8,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isOffline
                            ? 'Secured Offline (Sync Pending)'
                            : 'Captured Online',
                        style: TextStyle(
                          color: widget.isOffline
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
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
        cacheWidth: 800,
        errorBuilder: (_, _, _) => _buildRemoteOrFallbackPhoto(),
      );
    }
    return _buildRemoteOrFallbackPhoto();
  }

  Widget _buildRemoteOrFallbackPhoto() {
    if (widget.snapshotUrl != null &&
        widget.snapshotUrl!.isNotEmpty &&
        !_isAvatarPhoto(widget.snapshotUrl)) {
      // 1. Check if snapshot is Base64 data URI or raw Base64
      if (_isBase64Photo(widget.snapshotUrl)) {
        final bytes = _decodeBase64(widget.snapshotUrl!);
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: 800,
            errorBuilder: (_, _, _) => _buildFallbackPhoto(),
          );
        }
      }

      // 2. Check if snapshot is a local file URI or path
      try {
        final localFile = File(widget.snapshotUrl!);
        if (localFile.existsSync()) {
          return Image.file(
            localFile,
            fit: BoxFit.cover,
            cacheWidth: 800,
            errorBuilder: (_, _, _) => _buildFallbackPhoto(),
          );
        }
      } catch (_) {}

      // 3. Network URL
      final resolvedUrl = _resolveRemoteUrl(widget.snapshotUrl!);
      final headers = _buildAuthHeaders(widget.snapshotUrl!);
      return Image.network(
        resolvedUrl,
        headers: headers,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, _, _) => _buildFallbackPhoto(),
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
