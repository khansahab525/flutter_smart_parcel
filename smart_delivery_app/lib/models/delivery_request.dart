enum ParcelSize {
  document(
    apiValue: 'document',
    label: 'Document',
    description: 'Letters and documents',
    surcharge: 0,
  ),
  small(
    apiValue: 'small',
    label: 'Small parcel',
    description: 'Fits in a small bag',
    surcharge: 1.5,
  ),
  medium(
    apiValue: 'medium',
    label: 'Medium box',
    description: 'Standard delivery box',
    surcharge: 3,
  ),
  large(
    apiValue: 'large',
    label: 'Large parcel',
    description: 'Bulky or oversized item',
    surcharge: 6,
  );

  final String apiValue;
  final String label;
  final String description;
  final double surcharge;

  const ParcelSize({
    required this.apiValue,
    required this.label,
    required this.description,
    required this.surcharge,
  });

  static ParcelSize? fromApiValue(String? value) {
    for (final size in values) {
      if (size.apiValue == value) return size;
    }
    return null;
  }
}

class DeliveryRequest {
  final String customerName;
  final String? customerPhone;
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;
  final String pickupAddress;
  final String deliveryAddress;
  final ParcelSize parcelSize;
  final double weightKg;
  final String? parcelDescription;
  final bool isFragile;
  final String? deliveryNotes;
  final DateTime? scheduledAt;
  final double estimatedDistanceKm;
  final double estimatedPrice;
  final int? preferredDriverId;

  const DeliveryRequest({
    required this.customerName,
    this.customerPhone,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.parcelSize,
    required this.weightKg,
    this.parcelDescription,
    this.isFragile = false,
    this.deliveryNotes,
    this.scheduledAt,
    required this.estimatedDistanceKm,
    required this.estimatedPrice,
    this.preferredDriverId,
  });

  Map<String, dynamic> toJson() => {
    'customer_name': customerName,
    if (customerPhone != null && customerPhone!.isNotEmpty)
      'customer_phone': customerPhone,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'delivery_lat': deliveryLat,
    'delivery_lng': deliveryLng,
    'pickup_address': pickupAddress,
    'delivery_address': deliveryAddress,
    'parcel_size': parcelSize.apiValue,
    'parcel_weight_kg': weightKg,
    if (parcelDescription != null && parcelDescription!.isNotEmpty)
      'parcel_description': parcelDescription,
    'is_fragile': isFragile,
    if (deliveryNotes != null && deliveryNotes!.isNotEmpty)
      'delivery_notes': deliveryNotes,
    if (scheduledAt != null)
      'scheduled_at': scheduledAt!.toUtc().toIso8601String(),
    'estimated_distance_km': estimatedDistanceKm,
    'estimated_price': estimatedPrice,
    if (preferredDriverId != null)
      'preferred_driver_id': preferredDriverId,
  };
}

class DeliveryEstimate {
  final double distanceKm;
  final double price;

  const DeliveryEstimate({required this.distanceKm, required this.price});

  factory DeliveryEstimate.calculate({
    required double distanceKm,
    required ParcelSize parcelSize,
    required double weightKg,
    required bool isFragile,
  }) {
    const baseFare = 4.5;
    const perKilometer = 1.2;
    final extraWeight = weightKg > 2 ? (weightKg - 2) * 0.45 : 0.0;
    final fragileFee = isFragile ? 2.0 : 0.0;
    final price =
        baseFare +
        (distanceKm * perKilometer) +
        parcelSize.surcharge +
        extraWeight +
        fragileFee;

    return DeliveryEstimate(
      distanceKm: distanceKm,
      price: double.parse(price.toStringAsFixed(2)),
    );
  }
}
