import 'package:tks_nexa_attendance/features/auth/domain/auth_session.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';

abstract interface class AuthenticationService {
  Future<AuthSession> login({
    required LoginMethod method,
    required String identifier,
    required String password,
  });
}
