import 'dart:typed_data';

class FaceCaptureEvidence {
  FaceCaptureEvidence({
    required this.bytes,
    required this.contentType,
    required this.capturedAt,
    this.livenessPassed = false,
    this.livenessChallenge = 'not_performed',
    this.faceBounds,
  });

  final Uint8List bytes;
  final String contentType;
  final DateTime capturedAt;
  final bool livenessPassed;
  final String livenessChallenge;
  final FaceBounds? faceBounds;

  void clear() => bytes.fillRange(0, bytes.length, 0);
}

class FaceBounds {
  const FaceBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}
