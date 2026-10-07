import 'package:flutter/material.dart';
import 'package:tks_nexa_attendance/features/attendance/data/location_reverse_geocode_service.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/location_evidence.dart';

class CurrentLocationCard extends StatefulWidget {
  const CurrentLocationCard({
    super.key,
    required this.location,
    required this.capturing,
    required this.isLocationDisabled,
    required this.isPermissionBlocked,
    required this.onRefresh,
    this.onGeocodeResolved,
  });

  final LocationEvidence? location;
  final bool capturing;
  final bool isLocationDisabled;
  final bool isPermissionBlocked;
  final VoidCallback onRefresh;
  final ValueChanged<GeocodedAddress>? onGeocodeResolved;

  @override
  State<CurrentLocationCard> createState() => _CurrentLocationCardState();
}

class _CurrentLocationCardState extends State<CurrentLocationCard> {
  final _service = LocationReverseGeocodeService();
  GeocodedAddress? _geocoded;
  String? _lastLocationKey;

  @override
  void didUpdateWidget(covariant CurrentLocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != null) {
      final key = '${widget.location!.latitude.toStringAsFixed(4)},${widget.location!.longitude.toStringAsFixed(4)}';
      if (key != _lastLocationKey) {
        _lastLocationKey = key;
        _resolveAddress();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.location != null) {
      _lastLocationKey = '${widget.location!.latitude.toStringAsFixed(4)},${widget.location!.longitude.toStringAsFixed(4)}';
      _resolveAddress();
    }
  }

  Future<void> _resolveAddress() async {
    final loc = widget.location;
    if (loc == null) return;
    try {
      final res = await _service.resolve(
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracyMeters: loc.horizontalAccuracyM,
      );
      if (mounted) {
        setState(() {
          _geocoded = res;
        });
        widget.onGeocodeResolved?.call(res);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Disabled / Blocked state
    if (widget.isLocationDisabled || widget.isPermissionBlocked) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFDE68A),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CURRENT LOCATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isLocationDisabled ? 'GPS Disabled' : 'Permission Denied',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.isLocationDisabled
                  ? 'Location services (GPS) are turned off on your device.'
                  : 'Location permission is denied in device settings.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(
                widget.isLocationDisabled ? Icons.location_off_rounded : Icons.settings_rounded,
                size: 18,
              ),
              label: Text(widget.isLocationDisabled ? 'Open Location Settings' : 'Open App Settings'),
            ),
          ],
        ),
      );
    }

    // Acquiring State
    if (widget.location == null || widget.capturing) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CURRENT LOCATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Acquiring GPS…',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(
                  Icons.location_searching_rounded,
                  color: Color(0xFF2563EB),
                  size: 26,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acquiring Satellite Fix…',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Reading device satellite telemetry',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Active Location Resolved (Matching user's screenshots exactly)
    final loc = widget.location!;
    final geocoded = _geocoded;
    final int accInt = loc.horizontalAccuracyM.isFinite ? loc.horizontalAccuracyM.round() : 5;
    final String networkBadge = geocoded?.networkBadge ?? 'GPS (${accInt}m)';
    final String primaryTitle = geocoded?.primaryLocality ?? 'Acquiring Address…';
    final String detailedSubtitle = geocoded?.detailedAddress ??
        '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)} · ±${accInt}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Row: CURRENT LOCATION + Pill Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT LOCATION',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              InkWell(
                onTap: widget.capturing ? null : widget.onRefresh,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        networkBadge,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Location Content Row: Blue Pin + Primary Locality + Administrative Hierarchy
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF2563EB),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryTitle,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailedSubtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
