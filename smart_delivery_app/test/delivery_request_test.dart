import 'package:flutter_test/flutter_test.dart';
import 'package:smart_delivery_app/models/delivery_request.dart';

void main() {
  group('DeliveryEstimate', () {
    test('calculates fare from route, parcel, weight, and handling', () {
      final estimate = DeliveryEstimate.calculate(
        distanceKm: 10,
        parcelSize: ParcelSize.medium,
        weightKg: 4,
        isFragile: true,
      );

      expect(estimate.distanceKm, 10);
      expect(estimate.price, 22.4);
    });

    test('does not add extra weight fee up to two kilograms', () {
      final estimate = DeliveryEstimate.calculate(
        distanceKm: 5,
        parcelSize: ParcelSize.document,
        weightKg: 1,
        isFragile: false,
      );

      expect(estimate.price, 10.5);
    });
  });

  test('DeliveryRequest serializes workflow fields for the API', () {
    final scheduledAt = DateTime.utc(2026, 9, 21, 10, 30);
    final request = DeliveryRequest(
      customerName: 'Test Customer',
      customerPhone: '+10000000000',
      pickupLat: 1,
      pickupLng: 2,
      deliveryLat: 3,
      deliveryLng: 4,
      pickupAddress: 'Pickup',
      deliveryAddress: 'Destination',
      parcelSize: ParcelSize.small,
      weightKg: 1.5,
      parcelDescription: 'Books',
      isFragile: true,
      deliveryNotes: 'Call on arrival',
      scheduledAt: scheduledAt,
      estimatedDistanceKm: 8.2,
      estimatedPrice: 17.84,
    );

    expect(request.toJson(), containsPair('parcel_size', 'small'));
    expect(request.toJson(), containsPair('parcel_weight_kg', 1.5));
    expect(request.toJson(), containsPair('is_fragile', true));
    expect(
      request.toJson(),
      containsPair('scheduled_at', scheduledAt.toIso8601String()),
    );
  });
}
