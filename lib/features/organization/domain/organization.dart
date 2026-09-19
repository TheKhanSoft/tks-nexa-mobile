class Organization {
  const Organization({
    required this.code,
    required this.name,
    required this.apiBaseUri,
    this.logoUri,
  });

  final String code;
  final String name;
  final Uri apiBaseUri;
  final Uri? logoUri;

  @override
  bool operator ==(Object other) {
    return other is Organization &&
        other.code == code &&
        other.name == name &&
        other.apiBaseUri == apiBaseUri &&
        other.logoUri == logoUri;
  }

  @override
  int get hashCode => Object.hash(code, name, apiBaseUri, logoUri);
}
