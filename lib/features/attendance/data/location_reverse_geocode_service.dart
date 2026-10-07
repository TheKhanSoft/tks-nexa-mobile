import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GeocodedAddress {
  const GeocodedAddress({
    required this.primaryLocality,
    required this.detailedAddress,
    required this.networkBadge,
    required this.isWifi,
  });

  final String primaryLocality;
  final String detailedAddress;
  final String networkBadge;
  final bool isWifi;
}

class LocationReverseGeocodeService {
  LocationReverseGeocodeService({Dio? dio}) : _dio = dio ?? Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {
        'User-Agent': 'TKS-Nexa-Attendance/1.0',
        'Accept': 'application/json',
      },
    ),
  );

  final Dio _dio;
  static final Map<String, GeocodedAddress> _cache = {};

  Future<GeocodedAddress> resolve({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    // 1. Determine Network Type (WiFi vs Mobile Data)
    bool isWifi = false;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      isWifi = connectivityResult.contains(ConnectivityResult.wifi);
    } catch (_) {
      isWifi = false;
    }

    final int accInt = accuracyMeters.isFinite ? accuracyMeters.round() : 5;
    final String networkBadge = isWifi ? 'GPS (WiFi)' : 'GPS (${accInt}m)';

    final cacheKey = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      return GeocodedAddress(
        primaryLocality: cached.primaryLocality,
        detailedAddress: cached.detailedAddress,
        networkBadge: networkBadge,
        isWifi: isWifi,
      );
    }

    // 2. Perform Reverse Geocoding via OpenStreetMap Nominatim
    String primaryLocality = 'Current Location';
    String detailedAddress = '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
          'accept-language': 'en',
        },
      );

      final data = response.data;
      if (data != null && data['address'] is Map) {
        final address = Map<String, dynamic>.from(data['address'] as Map);

        // Pick most specific locality name
        final candidateName = (address['village'] ??
                address['suburb'] ??
                address['neighbourhood'] ??
                address['residential'] ??
                address['town'] ??
                address['city_district'] ??
                address['city'] ??
                address['municipality'] ??
                address['county'] ??
                '')
            .toString()
            .trim();

        if (candidateName.isNotEmpty) {
          primaryLocality = candidateName;
        }

        // Build administrative hierarchy
        final parts = <String>[];
        for (final key in [
          'suburb',
          'municipality',
          'county',
          'state_district',
          'state',
          'country',
        ]) {
          final val = address[key]?.toString().trim();
          if (val != null &&
              val.isNotEmpty &&
              val.toLowerCase() != primaryLocality.toLowerCase() &&
              !parts.contains(val)) {
            parts.add(val);
          }
        }

        if (parts.isNotEmpty) {
          detailedAddress = parts.join(', ');
        } else if (data['display_name'] != null) {
          detailedAddress = data['display_name'].toString();
        }
      }
    } catch (e) {
      debugPrint('[LocationGeocode] Reverse geocode fallback: $e');
    }

    final resolved = GeocodedAddress(
      primaryLocality: primaryLocality,
      detailedAddress: detailedAddress,
      networkBadge: networkBadge,
      isWifi: isWifi,
    );

    _cache[cacheKey] = resolved;
    return resolved;
  }
}
