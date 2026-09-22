import 'delivery_model.dart';

class AvailableDriver {
  final int id;
  final String name;
  final String? phone;
  final String? profileImageBase64;
  final double? distanceKm;
  final int activeDeliveryCount;
  final DateTime? lastLocationTime;
  final bool isOnline;

  const AvailableDriver({
    required this.id,
    required this.name,
    this.phone,
    this.profileImageBase64,
    this.distanceKm,
    this.activeDeliveryCount = 0,
    this.lastLocationTime,
    this.isOnline = false,
  });

  factory AvailableDriver.fromJson(Map<String, dynamic> json) {
    return AvailableDriver(
      id: _toInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      phone: _toString(json['phone']),
      profileImageBase64: _toString(json['profile_image']),
      distanceKm: _toDouble(json['distance_km']),
      activeDeliveryCount: _toInt(json['active_delivery_count']) ?? 0,
      lastLocationTime: _toDateTime(json['last_location_time']),
      isOnline: json['is_online'] == true,
    );
  }
}

class DeliveryOffer {
  final int id;
  final String source;
  final String status;
  final double? distanceKm;
  final DateTime offeredAt;
  final DateTime expiresAt;
  final DeliveryModel delivery;

  const DeliveryOffer({
    required this.id,
    required this.source,
    required this.status,
    this.distanceKm,
    required this.offeredAt,
    required this.expiresAt,
    required this.delivery,
  });

  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  bool get isExpired => timeRemaining.inMilliseconds <= 0;

  factory DeliveryOffer.fromJson(Map<String, dynamic> json) {
    final expiresInSeconds = _toInt(json['expires_in_seconds']);
    return DeliveryOffer(
      id: _toInt(json['id']) ?? 0,
      source: json['source'] as String? ?? 'nearby',
      status: json['status'] as String? ?? 'pending',
      distanceKm: _toDouble(json['distance_km']),
      offeredAt: _toDateTime(json['offered_at']) ?? DateTime.now(),
      expiresAt: expiresInSeconds == null
          ? _toDateTime(json['expires_at']) ?? DateTime.now()
          : DateTime.now().add(Duration(seconds: expiresInSeconds)),
      delivery: DeliveryModel.fromJson(
        json['delivery'] as Map<String, dynamic>,
      ),
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _toString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

DateTime? _toDateTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
