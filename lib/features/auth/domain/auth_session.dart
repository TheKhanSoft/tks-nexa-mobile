import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.employeeName,
    this.photoUrl,
    this.mustChangePassword = false,
    this.hasPhoto = true,
    this.actionRequired,
    this.actionMessage,
    this.passwordChangeMessage,
    this.photoWarningMessage,
    this.redirectTarget,
  });

  final String accessToken;
  final String? employeeName;
  final String? photoUrl;
  final bool mustChangePassword;
  final bool hasPhoto;
  final String? actionRequired;
  final String? actionMessage;
  final String? passwordChangeMessage;
  final String? photoWarningMessage;
  final String? redirectTarget;

  AuthSession copyWith({
    String? accessToken,
    String? employeeName,
    String? photoUrl,
    bool? mustChangePassword,
    bool? hasPhoto,
    String? actionRequired,
    String? actionMessage,
    String? passwordChangeMessage,
    String? photoWarningMessage,
    String? redirectTarget,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      employeeName: employeeName ?? this.employeeName,
      photoUrl: photoUrl ?? this.photoUrl,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      actionRequired: actionRequired ?? this.actionRequired,
      actionMessage: actionMessage ?? this.actionMessage,
      passwordChangeMessage: passwordChangeMessage ?? this.passwordChangeMessage,
      photoWarningMessage: photoWarningMessage ?? this.photoWarningMessage,
      redirectTarget: redirectTarget ?? this.redirectTarget,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'employee_name': employeeName,
        'photo_url': photoUrl,
        'must_change_password': mustChangePassword,
        'has_photo': hasPhoto,
        'action_required': actionRequired,
        'action_message': actionMessage,
        'password_change_message': passwordChangeMessage,
        'photo_warning_message': photoWarningMessage,
        'redirect_target': redirectTarget,
      };

  String encode() => jsonEncode(toJson());

  static AuthSession? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final token = map['access_token'] ?? map['accessToken'];
      if (token is! String || token.trim().isEmpty) return null;
      return AuthSession(
        accessToken: token.trim(),
        employeeName: map['employee_name'] as String?,
        photoUrl: map['photo_url'] as String?,
        mustChangePassword: map['must_change_password'] == true,
        hasPhoto: map['has_photo'] != false,
        actionRequired: map['action_required'] as String?,
        actionMessage: map['action_message'] as String?,
        passwordChangeMessage: map['password_change_message'] as String?,
        photoWarningMessage: map['photo_warning_message'] as String?,
        redirectTarget: map['redirect_target'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
