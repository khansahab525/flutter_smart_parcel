class DriverInfo {
  final int? id;
  final String? name;
  final String? phone;
  final double? currentLat;
  final double? currentLng;

  const DriverInfo({
    this.id,
    this.name,
    this.phone,
    this.currentLat,
    this.currentLng,
  });

  factory DriverInfo.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const DriverInfo();
    }
    return DriverInfo(
      id: _toInt(json['id']),
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      currentLat: _toDouble(json['current_lat']),
      currentLng: _toDouble(json['current_lng']),
    );
  }
}

class DeliveryModel {
  final int id;
  final String name;
  final String customerName;
  final String? customerPhone;
  final String status;
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;
  final double? currentLat;
  final double? currentLng;
  final DriverInfo? driver;
  final String? pickupAddress;
  final String? deliveryAddress;
  final String? confirmationPin;
  final bool hasPod;
  final int? rating;
  final String? feedback;

  const DeliveryModel({
    required this.id,
    required this.name,
    required this.customerName,
    this.customerPhone,
    required this.status,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.currentLat,
    this.currentLng,
    this.driver,
    this.pickupAddress,
    this.deliveryAddress,
    this.confirmationPin,
    this.hasPod = false,
    this.rating,
    this.feedback,
  });

  bool get isActive =>
      !['delivered', 'cancelled'].contains(status);

  String get statusLabel {
    const labels = {
      'created': 'Created',
      'assigned': 'Assigned',
      'picked_up': 'Picked Up',
      'in_transit': 'In Transit',
      'out_for_delivery': 'Out for Delivery',
      'delivered': 'Delivered',
      'cancelled': 'Cancelled',
    };
    return labels[status] ?? status;
  }

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      id: _toInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String?,
      status: json['status'] as String? ?? 'created',
      pickupLat: _toDouble(json['pickup_lat']) ?? 0,
      pickupLng: _toDouble(json['pickup_lng']) ?? 0,
      deliveryLat: _toDouble(json['delivery_lat']) ?? 0,
      deliveryLng: _toDouble(json['delivery_lng']) ?? 0,
      currentLat: _toDouble(json['current_lat']),
      currentLng: _toDouble(json['current_lng']),
      driver: DriverInfo.fromJson(json['driver']),
      pickupAddress: _toNonEmptyString(json['pickup_address']),
      deliveryAddress: _toNonEmptyString(json['delivery_address']),
      confirmationPin: _toNonEmptyString(json['confirmation_pin']),
      hasPod: json['has_pod'] == true,
      rating: _toInt(json['rating']),
      feedback: _toNonEmptyString(json['feedback']),
    );
  }
}

class TrackingData {
  final DeliveryModel delivery;
  final double? driverLat;
  final double? driverLng;
  final double destLat;
  final double destLng;
  final double pickupLat;
  final double pickupLng;
  final List<GpsPoint> routeHistory;
  final List<String> notifications;

  const TrackingData({
    required this.delivery,
    this.driverLat,
    this.driverLng,
    required this.destLat,
    required this.destLng,
    required this.pickupLat,
    required this.pickupLng,
    this.routeHistory = const [],
    this.notifications = const [],
  });

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    final driverLoc = json['driver_location'] as Map<String, dynamic>? ?? {};
    final dest = json['destination'] as Map<String, dynamic>? ?? {};
    final pickup = json['pickup'] as Map<String, dynamic>? ?? {};
    final history = (json['route_history'] as List<dynamic>? ?? [])
        .map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return TrackingData(
      delivery: DeliveryModel.fromJson(
        json['delivery'] as Map<String, dynamic>,
      ),
      driverLat: _toDouble(driverLoc['latitude']),
      driverLng: _toDouble(driverLoc['longitude']),
      destLat: _toDouble(dest['latitude']) ?? 0,
      destLng: _toDouble(dest['longitude']) ?? 0,
      pickupLat: _toDouble(pickup['latitude']) ?? 0,
      pickupLng: _toDouble(pickup['longitude']) ?? 0,
      routeHistory: history,
      notifications: (json['notifications'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

class GpsPoint {
  final double latitude;
  final double longitude;
  final double? speed;
  final String? timestamp;

  const GpsPoint({
    required this.latitude,
    required this.longitude,
    this.speed,
    this.timestamp,
  });

  factory GpsPoint.fromJson(Map<String, dynamic> json) {
    return GpsPoint(
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      speed: _toDouble(json['speed']),
      timestamp: json['timestamp'] as String?,
    );
  }
}

String? _toNonEmptyString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

int? _toInt(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null || value == false) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
