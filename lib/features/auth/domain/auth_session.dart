class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.employeeName,
    this.photoUrl,
  });

  final String accessToken;
  final String? employeeName;
  final String? photoUrl;
}
