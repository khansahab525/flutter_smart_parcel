import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/delivery_model.dart';
import '../services/delivery_service.dart';
import '../services/location_service.dart';

class DeliveryProvider extends ChangeNotifier {
  final DeliveryService _deliveryService;
  final LocationService _locationService;

  List<DeliveryModel> _deliveries = [];
  DeliveryModel? _activeDelivery;
  bool _isLoading = false;
  String? _error;
  bool _isTrackingLocation = false;

  DeliveryProvider(this._deliveryService, this._locationService);

  List<DeliveryModel> get deliveries => _deliveries;
  DeliveryModel? get activeDelivery => _activeDelivery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTrackingLocation => _isTrackingLocation;

  List<DeliveryModel> get activeDeliveries =>
      _deliveries.where((d) => d.isActive).toList();

  Future<void> loadDeliveries({String? status}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _deliveries = await _deliveryService.getDeliveries(status: status);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDelivery(int id) async {
    try {
      final updated = await _deliveryService.getDelivery(id);
      final index = _deliveries.indexWhere((d) => d.id == id);
      if (index >= 0) _deliveries[index] = updated;
      if (_activeDelivery?.id == id) _activeDelivery = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void setActiveDelivery(DeliveryModel delivery) {
    _activeDelivery = delivery;
    notifyListeners();
  }

  Future<bool> updateStatus(int id, String status) async {
    try {
      final updated = await _deliveryService.updateStatus(id, status);
      final index = _deliveries.indexWhere((d) => d.id == id);
      if (index >= 0) _deliveries[index] = updated;
      if (_activeDelivery?.id == id) _activeDelivery = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> startLocationTracking({
    required int driverId,
    required int deliveryId,
  }) async {
    if (_isTrackingLocation) return;

    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) {
      _error = 'Location permission denied';
      notifyListeners();
      return;
    }

    _isTrackingLocation = true;
    notifyListeners();

    _locationService.startPeriodicUpdates((position) async {
      await _sendLocationUpdate(driverId, deliveryId, position);
    });
  }

  void stopLocationTracking() {
    _locationService.stopUpdates();
    _isTrackingLocation = false;
    notifyListeners();
  }

  Future<void> _sendLocationUpdate(
    int driverId,
    int deliveryId,
    Position position,
  ) async {
    try {
      final speed = _locationService.speedKmh(position);
      final updated = await _deliveryService.updateLocation(
        driverId: driverId,
        deliveryId: deliveryId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: speed,
      );
      final index = _deliveries.indexWhere((d) => d.id == deliveryId);
      if (index >= 0) _deliveries[index] = updated;
      if (_activeDelivery?.id == deliveryId) _activeDelivery = updated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
