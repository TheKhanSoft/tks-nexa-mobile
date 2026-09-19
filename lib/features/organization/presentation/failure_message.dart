import 'package:flutter/foundation.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';

String safeFailureMessage(Object error) {
  if (error is AppFailure) {
    if (kDebugMode && error.diagnosticCode != null) {
      return '${error.message}\nDiagnostic: ${error.diagnosticCode}';
    }
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}
