import 'package:flutter_test/flutter_test.dart';
import 'package:tks_nexa_attendance/core/errors/app_failure.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization_code_parser.dart';

void main() {
  const parser = OrganizationCodeParser();

  test('normalizes a manually entered organization code', () {
    expect(parser.parse(' abc-123 '), 'ABC-123');
  });

  test('extracts a code from a trusted QR payload shape', () {
    expect(parser.parse('{"organization_code":"abc123"}'), 'ABC123');
  });

  test('does not accept a URL from a QR code', () {
    expect(
      () => parser.parse('https://attacker.example/ABC123'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          FailureCode.invalidInput,
        ),
      ),
    );
  });
}
