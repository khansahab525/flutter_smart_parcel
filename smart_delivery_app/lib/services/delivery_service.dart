import '../config/api_config.dart';
import '../models/delivery_model.dart';
import 'api_service.dart';

class DeliveryService {
  final ApiService _api;

  DeliveryService(this._api);

  Future<List<DeliveryModel>> getDeliveries({String? status}) async {
    var endpoint = ApiConfig.deliveryListEndpoint;
    if (status != null) endpoint += '?status=$status';

    final response = await _api.get(endpoint);
    final raw = response['data'];

    if (raw == null) return [];
    if (raw is! List) {
      throw ApiException('Expected list from server, got ${raw.runtimeType}');
    }

    final deliveries = <DeliveryModel>[];
    for (final item in raw) {
      try {
        deliveries.add(
          DeliveryModel.fromJson(item as Map<String, dynamic>),
        );
      } catch (e) {
        throw ApiException('Failed to parse delivery: $e');
      }
    }
    return deliveries;
  }

  Future<DeliveryModel> getDelivery(int id) async {
    final response = await _api.get(ApiConfig.deliveryDetail(id));
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DeliveryModel> updateStatus(int id, String status) async {
    final response = await _api.post(
      ApiConfig.deliveryStatus(id),
      body: {'status': status},
    );
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DeliveryModel> createDelivery({
    required String customerName,
    String? customerPhone,
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    String? pickupAddress,
    String? deliveryAddress,
  }) async {
    final response = await _api.post(
      ApiConfig.deliveryCreateEndpoint,
      body: {
        'customer_name': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customer_phone': customerPhone,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'delivery_lat': deliveryLat,
        'delivery_lng': deliveryLng,
        if (pickupAddress != null) 'pickup_address': pickupAddress,
        if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        if (_api.userId != null) 'customer_user_id': _api.userId,
      },
    );
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DeliveryModel> completeDelivery({
    required int id,
    required String pin,
    String? podImageBase64,
    String? podSignatureBase64,
  }) async {
    final response = await _api.post(
      ApiConfig.deliveryComplete(id),
      body: {
        'pin': pin,
        if (podImageBase64 != null) 'pod_image': podImageBase64,
        if (podSignatureBase64 != null) 'pod_signature': podSignatureBase64,
      },
    );
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DeliveryModel> rateDelivery({
    required int id,
    required int rating,
    String? feedback,
  }) async {
    final response = await _api.post(
      ApiConfig.deliveryRate(id),
      body: {
        'rating': rating,
        if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
      },
    );
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DeliveryModel> updateLocation({
    required int driverId,
    required int deliveryId,
    required double latitude,
    required double longitude,
    double? speed,
  }) async {
    final response = await _api.post(
      ApiConfig.driverLocationEndpoint,
      body: {
        'driver_id': driverId,
        'delivery_id': deliveryId,
        'latitude': latitude,
        'longitude': longitude,
        if (speed != null) 'speed': speed,
      },
    );
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<TrackingData> getTracking(int deliveryId) async {
    final response = await _api.get(ApiConfig.tracking(deliveryId));
    return TrackingData.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<String> sendChatMessage(int deliveryId, String message) async {
    final response = await _api.post(
      ApiConfig.chatEndpoint,
      body: {'delivery_id': deliveryId, 'message': message},
    );
    final data = response['data'] as Map<String, dynamic>;
    return data['response'] as String? ?? 'No response';
  }
}
