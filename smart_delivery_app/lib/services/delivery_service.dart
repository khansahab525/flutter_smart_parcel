import '../config/api_config.dart';
import '../models/delivery_model.dart';
import '../models/delivery_request.dart';
import '../models/driver_assignment.dart';
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
        deliveries.add(DeliveryModel.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        throw ApiException('Failed to parse delivery: $e');
      }
    }
    return deliveries;
  }

  Future<List<DeliveryModel>?> pollDeliveries(
    List<DeliveryModel> current,
  ) async {
    final knownState = current
        .map((item) => '${item.id}:${item.status}:${item.driver?.id ?? 0}')
        .join(',');
    final query = Uri(
      queryParameters: {
        'known_state': knownState,
        'timeout': '25',
      },
    ).query;
    final response = await _api.get(
      '${ApiConfig.deliveryListPollEndpoint}?$query',
    );
    final data = response['data'] as Map<String, dynamic>;
    if (data['changed'] != true) return null;

    final raw = data['deliveries'] as List<dynamic>? ?? [];
    return raw
        .map((item) => DeliveryModel.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
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

  Future<DeliveryModel> createDelivery(DeliveryRequest request) async {
    final response = await _api.post(
      ApiConfig.deliveryCreateEndpoint,
      body: {
        ...request.toJson(),
        if (_api.userId != null) 'customer_user_id': _api.userId,
      },
    );
    return DeliveryModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<AvailableDriver>> getAvailableDrivers({
    String? search,
    double? pickupLat,
    double? pickupLng,
  }) async {
    final query = Uri(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
        if (pickupLat != null) 'pickup_lat': '$pickupLat',
        if (pickupLng != null) 'pickup_lng': '$pickupLng',
      },
    ).query;
    final endpoint = query.isEmpty
        ? ApiConfig.availableDriversEndpoint
        : '${ApiConfig.availableDriversEndpoint}?$query';
    final response = await _api.get(endpoint);
    final raw = response['data'] as List<dynamic>? ?? [];
    return raw
        .map((item) => AvailableDriver.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<List<DeliveryOffer>> getDriverOffers() async {
    final response = await _api.get(ApiConfig.driverOffersEndpoint);
    final raw = response['data'] as List<dynamic>? ?? [];
    return raw
        .map((item) => DeliveryOffer.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<List<DeliveryOffer>> pollDriverOffers(
    List<int> knownOfferIds,
  ) async {
    final query = Uri(
      queryParameters: {
        'known_offer_ids': knownOfferIds.join(','),
        'timeout': '25',
      },
    ).query;
    final response = await _api.get(
      '${ApiConfig.driverOfferPollEndpoint}?$query',
    );
    final data = response['data'] as Map<String, dynamic>;
    final raw = data['offers'] as List<dynamic>? ?? [];
    return raw
        .map((item) => DeliveryOffer.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<DeliveryModel> acceptDriverOffer(int offerId) async {
    final response = await _api.post(ApiConfig.acceptDriverOffer(offerId));
    return DeliveryModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<DeliveryModel> rejectDriverOffer(int offerId) async {
    final response = await _api.post(ApiConfig.rejectDriverOffer(offerId));
    return DeliveryModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<void> updateAvailabilityLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _api.post(
      ApiConfig.driverAvailabilityLocationEndpoint,
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<AvailableDriver> setDriverConnection(bool connected) async {
    final response = await _api.post(
      ApiConfig.driverAvailabilityEndpoint,
      body: {'connected': connected},
    );
    return AvailableDriver.fromJson(
      response['data'] as Map<String, dynamic>,
    );
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

  Future<DeliveryModel> cancelDelivery(int id) async {
    final response = await _api.post(ApiConfig.deliveryCancel(id));
    return DeliveryModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
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
