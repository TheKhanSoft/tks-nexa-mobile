import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    required this.name,
    this.photoUrl,
    this.authToken,
    this.developmentConnectHost,
    this.developmentConnectPort,
    this.size = 88,
    super.key,
  });

  final String name;
  final String? photoUrl;
  final String? authToken;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final source = _authorizedPhotoSource(
      photoUrl,
      authToken,
      developmentConnectHost: developmentConnectHost,
      developmentConnectPort: developmentConnectPort,
    );
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: colorScheme.secondary.withValues(alpha: .14),
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: size * .27,
          fontWeight: FontWeight.w800,
          color: colorScheme.secondary,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: source != null
          ? Image.network(
              source.url,
              headers: source.headers,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              webHtmlElementStrategy: source.webHtmlElementStrategy,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    fallback,
                    const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                );
              },
              errorBuilder: (context, error, stackTrace) => fallback,
            )
          : fallback,
    );
  }
}

_AuthorizedPhotoSource? _authorizedPhotoSource(
  String? rawPhotoUrl,
  String? rawAuthToken, {
  String? developmentConnectHost,
  int? developmentConnectPort,
}) {
  final uri = Uri.tryParse(rawPhotoUrl?.trim() ?? '');
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

  final isSecure = uri.scheme.toLowerCase() == 'https';
  final isLocalDevelopment =
      uri.scheme.toLowerCase() == 'http' &&
      (uri.host == 'localhost' || uri.host.endsWith('.localhost'));
  if (!isSecure && !isLocalDevelopment) return null;

  final useDevelopmentBridge =
      isLocalDevelopment &&
      developmentConnectHost != null &&
      developmentConnectHost.trim().isNotEmpty;
  final requestUri = useDevelopmentBridge
      ? uri.replace(
          host: developmentConnectHost.trim(),
          port: developmentConnectPort ?? uri.port,
        )
      : uri;
  final bridgeHeaders = useDevelopmentBridge
      ? <String, String>{
          if (kIsWeb)
            'X-Development-Host': uri.hasPort
                ? '${uri.host}:${uri.port}'
                : uri.host
          else
            'Host': uri.hasPort ? '${uri.host}:${uri.port}' : uri.host,
        }
      : <String, String>{};

  final signature = uri.queryParameters['signature'];
  final expires = uri.queryParameters['expires'];
  final isSigned =
      signature != null &&
      signature.isNotEmpty &&
      expires != null &&
      int.tryParse(expires) != null;
  if (isSigned) {
    return _AuthorizedPhotoSource(
      url: requestUri.toString(),
      headers: bridgeHeaders.isEmpty ? null : bridgeHeaders,
      webHtmlElementStrategy: useDevelopmentBridge
          ? WebHtmlElementStrategy.never
          : WebHtmlElementStrategy.prefer,
    );
  }

  final authToken = rawAuthToken?.trim();
  if (authToken == null || authToken.isEmpty) return null;

  if (kIsWeb) {
    final queryParameters = Map<String, String>.from(requestUri.queryParameters)
      ..putIfAbsent('auth_token', () => authToken);
    return _AuthorizedPhotoSource(
      url: requestUri.replace(queryParameters: queryParameters).toString(),
      headers: bridgeHeaders.isEmpty ? null : bridgeHeaders,
      webHtmlElementStrategy: useDevelopmentBridge
          ? WebHtmlElementStrategy.never
          : WebHtmlElementStrategy.prefer,
    );
  }

  return _AuthorizedPhotoSource(
    url: requestUri.toString(),
    headers: {...bridgeHeaders, 'Authorization': 'Bearer $authToken'},
    webHtmlElementStrategy: WebHtmlElementStrategy.never,
  );
}

class _AuthorizedPhotoSource {
  const _AuthorizedPhotoSource({
    required this.url,
    required this.webHtmlElementStrategy,
    this.headers,
  });

  final String url;
  final Map<String, String>? headers;
  final WebHtmlElementStrategy webHtmlElementStrategy;
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  final initials = words.map((word) => word[0].toUpperCase()).join();
  return initials.isEmpty ? 'E' : initials;
}
