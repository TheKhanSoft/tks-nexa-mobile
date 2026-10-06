import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tks_nexa_attendance/features/attendance/data/biometric_photo_crop_helper.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';

void main() {
  test('alignFaceByEyes aligns eyes horizontally to 112x112 canonical format', () {
    final image = img.Image(width: 200, height: 200);
    // Draw two simulated eye points
    const eyeA = FaceLandmarkPoint(x: 80.0, y: 70.0);
    const eyeB = FaceLandmarkPoint(x: 120.0, y: 75.0);

    final aligned = BiometricPhotoCropHelper.alignFaceByEyes(
      image,
      eyeA: eyeA,
      eyeB: eyeB,
      targetEyeDist: 34.5,
      targetEyeY: 36.5,
      targetDim: 112,
    );

    expect(aligned.width, 112);
    expect(aligned.height, 112);
  });

  test('cropFaceOnly with eye landmarks returns 112x112 JPEG bytes', () {
    final image = img.Image(width: 200, height: 200);
    final bytes = img.encodeJpg(image);

    const eyeA = FaceLandmarkPoint(x: 80.0, y: 70.0);
    const eyeB = FaceLandmarkPoint(x: 120.0, y: 75.0);

    final cropped = BiometricPhotoCropHelper.cropFaceOnly(
      bytes,
      null,
      eyeA: eyeA,
      eyeB: eyeB,
    );

    expect(cropped, isNotNull);
    final decoded = img.decodeImage(cropped!);
    expect(decoded?.width, 112);
    expect(decoded?.height, 112);
  });
}
