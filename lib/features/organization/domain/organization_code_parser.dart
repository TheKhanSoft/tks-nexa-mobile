import 'dart:convert';

import 'package:tks_nexa_attendance/core/errors/app_failure.dart';

class OrganizationCodeParser {
  const OrganizationCodeParser();

  static final RegExp _validCode = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{2,63}$');

  String parse(String input) {
    var candidate = input.trim();
    if (candidate.startsWith('{')) {
      try {
        final json = jsonDecode(candidate);
        if (json is Map<String, dynamic> &&
            json['organization_code'] is String) {
          candidate = (json['organization_code'] as String).trim();
        }
      } on FormatException {
        throw _invalidCodeFailure;
      }
    }

    if (!_validCode.hasMatch(candidate)) {
      throw _invalidCodeFailure;
    }
    return candidate.toUpperCase();
  }

  AppFailure get _invalidCodeFailure => const AppFailure(
    code: FailureCode.invalidInput,
    message: 'Enter a valid organization code.',
    diagnosticCode: 'ORG_CODE_INVALID',
  );
}
