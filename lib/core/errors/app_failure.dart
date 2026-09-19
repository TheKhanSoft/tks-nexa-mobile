enum FailureCode {
  invalidInput,
  notFound,
  rateLimited,
  unauthorized,
  unavailable,
  invalidResponse,
  untrustedEndpoint,
  storage,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    required this.message,
    this.diagnosticCode,
  });

  final FailureCode code;
  final String message;
  final String? diagnosticCode;

  @override
  String toString() => 'AppFailure($code, $diagnosticCode)';
}
