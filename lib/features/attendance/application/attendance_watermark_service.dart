import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

final attendanceWatermarkServiceProvider = Provider<AttendanceWatermarkService>((ref) {
  return const AttendanceWatermarkService();
});

enum WatermarkMode {
  shared,
  downloaded,
}

class AttendanceWatermarkService {
  const AttendanceWatermarkService();

  static const MethodChannel _platformChannel = MethodChannel('com.tksnexa.thekhansoft/device_security');

  /// Format a DateTime as 'YYYY-MM-DD HH:mm:ss'
  static String formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  /// Generate a consistent 8-character verification code like '4E7D5140'
  static String formatVerificationCode(String? rawUid, {DateTime? timestamp, String? fallbackSeed}) {
    if (rawUid != null && rawUid.trim().isNotEmpty) {
      final sanitized = rawUid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (sanitized.length >= 8) {
        return sanitized.substring(0, 8).toUpperCase();
      }
    }

    final seed = '${timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}_${fallbackSeed ?? 'nexa'}';
    final digest = md5.convert(utf8.encode(seed)).bytes;
    return digest.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  /// Generate a watermarked image as PNG bytes.
  Future<Uint8List> generateWatermarkedImage({
    Uint8List? originalPhotoBytes,
    String? photoPath,
    required String verificationCode,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
    required String username,
    required String employeeCode,
    required String orgName,
    required WatermarkMode mode,
  }) async {
    // 1. Resolve photo bytes or fallback to generated card
    Uint8List? rawBytes = originalPhotoBytes;
    if ((rawBytes == null || rawBytes.isEmpty) && photoPath != null) {
      final file = File(photoPath);
      if (file.existsSync()) {
        try {
          rawBytes = await file.readAsBytes();
        } catch (_) {}
      }
    }

    ui.Image baseImage;
    if (rawBytes != null && rawBytes.isNotEmpty) {
      try {
        final codec = await ui.instantiateImageCodec(rawBytes);
        final frame = await codec.getNextFrame();
        baseImage = frame.image;
      } catch (_) {
        baseImage = await _createFallbackImage();
      }
    } else {
      baseImage = await _createFallbackImage();
    }

    final imgW = baseImage.width.toDouble();
    final imgH = baseImage.height.toDouble();
    final scale = (imgW / 450.0).clamp(0.75, 3.5);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw original photo
    canvas.drawImage(baseImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    // Subtle dark gradient vignette at the top and bottom to ensure text readability
    final topVignette = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, 110.0 * scale),
        [const Color(0x99000000), const Color(0x00000000)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, imgW, 110.0 * scale), topVignette);

    // --- Top-Left Overlay Info ---
    final latLngStr = (latitude != null && longitude != null)
        ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
        : '34.188177, 71.908437';
    final timeStr = formatTimestamp(timestamp);
    final codeStr = verificationCode.toUpperCase();

    final textSpan = TextSpan(
      style: TextStyle(
        color: Colors.white,
        fontSize: 10.5 * scale,
        fontFamily: 'monospace',
        height: 1.35,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 4 * scale,
            offset: Offset(1 * scale, 1 * scale),
          ),
        ],
      ),
      children: [
        TextSpan(text: '📍 $latLngStr\n', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: '🕒 $timeStr\n', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: '🔐 $codeStr', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pad = 8.0 * scale;
    final infoBoxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(10.0 * scale, 10.0 * scale, tp.width + pad * 2, tp.height + pad * 2),
      Radius.circular(8.0 * scale),
    );
    canvas.drawRRect(
      infoBoxRect,
      Paint()..color = const Color(0x95000000),
    );
    tp.paint(canvas, Offset(10.0 * scale + pad, 10.0 * scale + pad));

    // --- Top-Right QR Code Overlay ---
    final qrBoxSize = 62.0 * scale;
    final qrRight = imgW - 10.0 * scale - qrBoxSize;
    final qrTop = 10.0 * scale;

    final qrBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(qrRight, qrTop, qrBoxSize, qrBoxSize),
      Radius.circular(7.0 * scale),
    );
    canvas.drawRRect(
      qrBgRect,
      Paint()..color = Colors.white,
    );

    final qrPayload = '$codeStr | $timeStr | $latLngStr | $username';
    final qrPainter = QrPainter(
      data: qrPayload,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final qrInnerPad = 4.5 * scale;
    final qrInnerSize = qrBoxSize - qrInnerPad * 2;
    canvas.save();
    canvas.translate(qrRight + qrInnerPad, qrTop + qrInnerPad);
    qrPainter.paint(canvas, Size(qrInnerSize, qrInnerSize));
    canvas.restore();

    // --- Bottom Bar Overlay ---
    final barHeight = 44.0 * scale;
    final barRect = Rect.fromLTWH(0, imgH - barHeight, imgW, barHeight);
    canvas.drawRect(
      barRect,
      Paint()..color = const Color(0xF2111827), // Deep dark slate background
    );

    // Bottom-Left text: 'Shared by:' or 'Downloaded by:'
    final isDownloaded = mode == WatermarkMode.downloaded;
    final actorPrefix = isDownloaded ? 'Downloaded by' : 'Shared by';
    final actorName = username.isNotEmpty ? username : employeeCode;

    final bottomTextSpan = TextSpan(
      children: [
        TextSpan(
          text: '$actorPrefix: $actorName ($employeeCode)\n',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 9.5 * scale,
            height: 1.25,
          ),
        ),
        TextSpan(
          text: orgName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
            fontSize: 8.5 * scale,
            height: 1.2,
          ),
        ),
      ],
    );

    final rightBadgeEstimatedWidth = 115.0 * scale;
    final btp = TextPainter(
      text: bottomTextSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: imgW - rightBadgeEstimatedWidth);

    btp.paint(
      canvas,
      Offset(12.0 * scale, imgH - barHeight + (barHeight - btp.height) / 2),
    );

    // Bottom-Right: '● TKS Nexa Mobile' badge
    const badgeColor = Color(0xFF10B981);
    final dotRadius = 3.0 * scale;
    final rightMargin = 12.0 * scale;

    final mobileTextSpan = TextSpan(
      text: 'TKS Nexa Mobile',
      style: TextStyle(
        color: badgeColor,
        fontWeight: FontWeight.w900,
        fontSize: 9.2 * scale,
        letterSpacing: 0.4 * scale,
      ),
    );

    final mtp = TextPainter(
      text: mobileTextSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final dotX = imgW - rightMargin - mtp.width - 6.0 * scale;
    final dotY = imgH - (barHeight / 2);

    canvas.drawCircle(
      Offset(dotX, dotY),
      dotRadius,
      Paint()..color = badgeColor,
    );

    mtp.paint(
      canvas,
      Offset(imgW - rightMargin - mtp.width, dotY - mtp.height / 2),
    );

    final picture = recorder.endRecording();
    final resultImg = await picture.toImage(imgW.toInt(), imgH.toInt());
    final byteData = await resultImg.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Create a high-quality fallback image if no selfie exists
  Future<ui.Image> _createFallbackImage() async {
    const double width = 640;
    const double height = 850;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Gradient background
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, height),
        [const Color(0xFF1E293B), const Color(0xFF0F172A)],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Decorative center avatar outline
    final avatarPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(width / 2, height / 2 - 40), 90, avatarPaint);

    final bodyPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(width / 2 - 120, height / 2 + 70, 240, 160),
      const Radius.circular(50),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Center icon text
    final labelSpan = TextSpan(
      text: 'BIOMETRIC PUNCH RECORD',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontWeight: FontWeight.bold,
        fontSize: 14,
        letterSpacing: 2,
      ),
    );
    final ltp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();
    ltp.paint(canvas, Offset((width - ltp.width) / 2, height / 2 + 250));

    final pic = recorder.endRecording();
    return pic.toImage(width.toInt(), height.toInt());
  }

  /// Format caption for WhatsApp & messaging
  static String formatShareCaption({
    required DateTime timestamp,
    double? latitude,
    double? longitude,
    required String verificationCode,
  }) {
    final latLng = (latitude != null && longitude != null)
        ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
        : '34.188177, 71.908437';
    final timeStr = formatTimestamp(timestamp);
    return '📅 $timeStr\n📌 $latLng\n🔐 $verificationCode';
  }

  /// Save the watermarked image to local downloads/pictures directory
  Future<String> saveToGalleryOrDownloads({
    required Uint8List imageBytes,
    required String verificationCode,
  }) async {
    Directory? targetDir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        targetDir = downloadDir;
      }
    }

    if (targetDir == null) {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final fileName = 'Attendance_${verificationCode.toUpperCase()}.png';
    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(imageBytes);
    return file.path;
  }

  /// Share the attendance record image with standard platform share sheet
  Future<void> shareAttendance({
    required Uint8List imageBytes,
    required String verificationCode,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory('${tempDir.path}/share_plus');
    if (!shareDir.existsSync()) {
      shareDir.createSync(recursive: true);
    }
    final tempFile = File('${shareDir.path}/Attendance_${verificationCode.toUpperCase()}.png');
    await tempFile.writeAsBytes(imageBytes);

    final caption = formatShareCaption(
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      verificationCode: verificationCode,
    );

    await Share.shareXFiles(
      [XFile(tempFile.path, mimeType: 'image/png')],
      text: caption,
    );
  }

  /// Directly open WhatsApp with the watermarked image and details
  Future<void> shareDirectToWhatsApp({
    required Uint8List imageBytes,
    required String verificationCode,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory('${tempDir.path}/share_plus');
    if (!shareDir.existsSync()) {
      shareDir.createSync(recursive: true);
    }
    final tempFile = File('${shareDir.path}/Attendance_${verificationCode.toUpperCase()}.png');
    await tempFile.writeAsBytes(imageBytes);

    final caption = formatShareCaption(
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      verificationCode: verificationCode,
    );

    if (Platform.isAndroid) {
      try {
        final success = await _platformChannel.invokeMethod<bool>('shareToWhatsApp', {
          'filePath': tempFile.path,
          'caption': caption,
        });
        if (success == true) return;
      } catch (e) {
        debugPrint('Direct WhatsApp share invocation failed: $e. Falling back to SharePlus.');
      }
    }

    // Fallback if WhatsApp is not directly launched or on non-Android platform
    await Share.shareXFiles(
      [XFile(tempFile.path, mimeType: 'image/png')],
      text: caption,
    );
  }
}
