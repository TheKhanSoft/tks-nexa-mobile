import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tks_nexa_attendance/features/attendance/data/face_observation_service_factory.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';

/// Utilities for ICAO 9303 / NVR-standard biometric portrait cropping and
/// attendance punch face-isolation cropping.
class BiometricPhotoCropHelper {
  const BiometricPhotoCropHelper._();

  static const int standardDimension = 640;
  static const int standardQuality = 92;

  /// Crops strictly the face region (face bounding box + ~22% margin)
  /// from an arbitrary image for attendance punch vectorization and server snapshot.
  static Uint8List? cropFaceOnly(Uint8List imageBytes, FaceBounds? bounds) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;
      final oriented = img.bakeOrientation(decoded);

      img.Image cropped;
      if (bounds != null) {
        final padding = math.max(bounds.width, bounds.height) * 0.22;
        final left = math.max(0, (bounds.left - padding).floor());
        final top = math.max(0, (bounds.top - padding).floor());
        final right = math.min(
          oriented.width,
          (bounds.left + bounds.width + padding).ceil(),
        );
        final bottom = math.min(
          oriented.height,
          (bounds.top + bounds.height + padding).ceil(),
        );
        final width = right - left;
        final height = bottom - top;

        if (width >= 32 && height >= 32) {
          cropped = img.copyCrop(
            oriented,
            x: left,
            y: top,
            width: width,
            height: height,
          );
        } else {
          final side = math.min(oriented.width, oriented.height);
          cropped = img.copyCrop(
            oriented,
            x: (oriented.width - side) ~/ 2,
            y: (oriented.height - side) ~/ 2,
            width: side,
            height: side,
          );
        }
      } else {
        final side = math.min(oriented.width, oriented.height);
        cropped = img.copyCrop(
          oriented,
          x: (oriented.width - side) ~/ 2,
          y: (oriented.height - side) ~/ 2,
          width: side,
          height: side,
        );
      }

      return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
    } catch (_) {
      return null;
    }
  }

  /// Automatically crops an employee photo to an ICAO 9303 / NVR compliant 1:1 portrait
  /// (encompassing upper crown and collarbone/shoulders) and resamples to targetDimension (640x640 px).
  ///
  /// If [bounds] is null, attempts on-device ML Kit face detection first before falling
  /// back to golden-ratio portrait framing.
  static Future<Uint8List> cropToStandardPortrait(
    Uint8List imageBytes, {
    FaceBounds? bounds,
    int targetDimension = standardDimension,
  }) async {
    FaceBounds? detectedBounds = bounds;

    detectedBounds ??= await _detectFaceBoundsSilently(imageBytes);

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return imageBytes;
    }
    final oriented = img.bakeOrientation(decoded);

    img.Image cropped;
    if (detectedBounds != null) {
      final faceW = detectedBounds.width;
      final faceH = detectedBounds.height;
      // Head and upper shoulders framing (ICAO 9303 / ISO 19794-5 standard)
      final faceCenterX = detectedBounds.left + (faceW * 0.50);
      final faceCenterY = detectedBounds.top + (faceH * 0.45);
      final targetSquare = math.max(faceH * 1.85, faceW * 1.85);

      final cropX = math.max(
        0,
        math.min(oriented.width - targetSquare, faceCenterX - (targetSquare / 2)),
      ).floor();
      final cropY = math.max(
        0,
        math.min(oriented.height - targetSquare, faceCenterY - (targetSquare * 0.42)),
      ).floor();
      final cropW = math.min(oriented.width - cropX, targetSquare).floor();
      final cropH = math.min(oriented.height - cropY, targetSquare).floor();
      final side = math.min(cropW, cropH);

      cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: side,
        height: side,
      );
    } else {
      // Golden-ratio human portrait fallback
      int cropW;
      int cropH;
      int cropX;
      int cropY;

      if (oriented.height > oriented.width) {
        cropW = oriented.width;
        cropH = oriented.width;
        cropX = 0;
        cropY = math.min(
          oriented.height - oriented.width,
          (oriented.height * 0.08).round(),
        );
      } else if (oriented.width > oriented.height) {
        cropW = oriented.height;
        cropH = oriented.height;
        cropX = ((oriented.width - oriented.height) / 2).round();
        cropY = 0;
      } else {
        cropW = oriented.width;
        cropH = oriented.height;
        cropX = 0;
        cropY = 0;
      }

      cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );
    }

    final resized = img.copyResize(
      cropped,
      width: targetDimension,
      height: targetDimension,
      interpolation: img.Interpolation.linear,
    );

    return Uint8List.fromList(img.encodeJpg(resized, quality: standardQuality));
  }

  static Future<FaceBounds?> _detectFaceBoundsSilently(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/face_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      final service = createFaceObservationService();
      try {
        final observation = await service.observe(tempFile.path);
        return observation.bounds;
      } finally {
        await service.dispose();
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (_) {
      return null;
    }
  }
}
