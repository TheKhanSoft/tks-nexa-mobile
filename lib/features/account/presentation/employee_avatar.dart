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
    this.onUploadTap,
    super.key,
  });

  final String name;
  final String? photoUrl;
  final String? authToken;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final double size;
  final VoidCallback? onUploadTap;

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
      color: colorScheme.secondaryContainer,
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: size * .32,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: source != null
                ? Image.network(
                    source.url,
                    headers: source.headers,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    width: size,
                    height: size,
                    gaplessPlayback: true,
                    webHtmlElementStrategy: source.webHtmlElementStrategy,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
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
          ),
        ),
        if (source == null && onUploadTap != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: InkWell(
              onTap: onUploadTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.add_a_photo_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
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
    final queryParameters =
        Map<String, String>.from(requestUri.queryParameters)
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
