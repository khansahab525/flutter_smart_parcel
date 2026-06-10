import 'dart:math';

const double _earthRadiusKm = 6371.0;

/// Distance in kilometers between two GPS coordinates (Haversine formula).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  final lat1Rad = _toRadians(lat1);
  final lat2Rad = _toRadians(lat2);
  final deltaLat = _toRadians(lat2 - lat1);
  final deltaLng = _toRadians(lng2 - lng1);

  final a = pow(sin(deltaLat / 2), 2) +
      cos(lat1Rad) * cos(lat2Rad) * pow(sin(deltaLng / 2), 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return _earthRadiusKm * c;
}

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

double _toRadians(double degrees) => degrees * pi / 180;
