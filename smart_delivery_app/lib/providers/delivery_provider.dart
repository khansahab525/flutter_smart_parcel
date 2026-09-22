import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/delivery_model.dart';
import '../models/delivery_request.dart';
import '../models/driver_assignment.dart';
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
  List<AvailableDriver> _availableDrivers = [];
  List<DeliveryOffer> _driverOffers = [];
  bool _isLoadingDrivers = false;
  bool _isLoadingOffers = false;
  bool _isPollingOffers = false;
  bool _isFetchingDeliveries = false;
  bool _isPollingDeliveries = false;
  bool _isDriverConnected = false;

  DeliveryProvider(this._deliveryService, this._locationService);

  List<DeliveryModel> get deliveries => _deliveries;
  DeliveryModel? get activeDelivery => _activeDelivery;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTrackingLocation => _isTrackingLocation;
  List<AvailableDriver> get availableDrivers => _availableDrivers;
  List<DeliveryOffer> get driverOffers => _driverOffers;
  bool get isLoadingDrivers => _isLoadingDrivers;
  bool get isLoadingOffers => _isLoadingOffers;
  bool get isDriverConnected => _isDriverConnected;

  List<DeliveryModel> get activeDeliveries =>
      _deliveries.where((d) => d.isActive).toList();

  Future<void> loadDeliveries({
    String? status,
    bool showLoading = true,
  }) async {
    if (_isFetchingDeliveries) return;
    _isFetchingDeliveries = true;
    if (showLoading) _isLoading = true;
    _error = null;
    if (showLoading) notifyListeners();

    try {
      _deliveries = await _deliveryService.getDeliveries(status: status);
      final activeId = _activeDelivery?.id;
      if (activeId != null) {
        final matches = _deliveries.where((item) => item.id == activeId);
        if (matches.isNotEmpty) _activeDelivery = matches.first;
      }
      _isLoading = false;
      _isFetchingDeliveries = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isFetchingDeliveries = false;
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

  Future<bool> pollDeliveries() async {
    if (_isPollingDeliveries) return false;
    _isPollingDeliveries = true;
    try {
      final updated = await _deliveryService.pollDeliveries(_deliveries);
      if (updated != null) {
        _deliveries = updated;
        final activeId = _activeDelivery?.id;
        if (activeId != null) {
          final matches = updated.where((item) => item.id == activeId);
          if (matches.isNotEmpty) _activeDelivery = matches.first;
        }
      }
      _error = null;
      return true;
    } catch (e) {
      return false;
    } finally {
      _isPollingDeliveries = false;
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

  Future<bool> cancelDelivery(int id) async {
    try {
      final updated = await _deliveryService.cancelDelivery(id);
      final index = _deliveries.indexWhere((item) => item.id == id);
      if (index >= 0) _deliveries[index] = updated;
      if (_activeDelivery?.id == id) _activeDelivery = updated;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<DeliveryModel?> createDelivery(DeliveryRequest request) async {
    _error = null;
    try {
      final created = await _deliveryService.createDelivery(request);
      _deliveries = [created, ..._deliveries];
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> searchAvailableDrivers({
    String? search,
    double? pickupLat,
    double? pickupLng,
  }) async {
    _isLoadingDrivers = true;
    notifyListeners();
    try {
      _availableDrivers = await _deliveryService.getAvailableDrivers(
        search: search,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
      );
      _error = null;
    } catch (e) {
      _availableDrivers = [];
      _error = e.toString();
    }
    _isLoadingDrivers = false;
    notifyListeners();
  }

  void clearAvailableDrivers() {
    _availableDrivers = [];
    notifyListeners();
  }

  Future<void> loadDriverOffers() async {
    if (_isLoadingOffers) return;
    _isLoadingOffers = true;
    notifyListeners();
    try {
      _driverOffers = await _deliveryService.getDriverOffers();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoadingOffers = false;
    notifyListeners();
  }

  Future<bool> pollDriverOffers() async {
    if (_isPollingOffers) return false;
    _isPollingOffers = true;
    try {
      _driverOffers = await _deliveryService.pollDriverOffers(
        _driverOffers.map((offer) => offer.id).toList(),
      );
      _error = null;
      return true;
    } catch (e) {
      return false;
    } finally {
      _isPollingOffers = false;
      notifyListeners();
    }
  }

  Future<bool> acceptDriverOffer(int offerId) async {
    try {
      final delivery = await _deliveryService.acceptDriverOffer(offerId);
      _driverOffers.removeWhere((offer) => offer.id == offerId);
      final index = _deliveries.indexWhere((item) => item.id == delivery.id);
      if (index >= 0) {
        _deliveries[index] = delivery;
      } else {
        _deliveries = [delivery, ..._deliveries];
      }
      _error = null;
      _isDriverConnected = false;
      try {
        await _deliveryService.setDriverConnection(false);
      } catch (_) {
        // The order is already accepted; local availability remains offline.
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectDriverOffer(int offerId) async {
    try {
      await _deliveryService.rejectDriverOffer(offerId);
      _driverOffers.removeWhere((offer) => offer.id == offerId);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> connectDriver() async {
    final hasLocation = await updateDriverAvailabilityLocation();
    if (!hasLocation) return false;
    try {
      await _deliveryService.setDriverConnection(true);
      _isDriverConnected = true;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> disconnectDriver() async {
    try {
      await _deliveryService.setDriverConnection(false);
      _isDriverConnected = false;
      _driverOffers = [];
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDriverAvailabilityLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      _error = 'Location permission is required to receive nearby orders';
      notifyListeners();
      return false;
    }
    try {
      await _deliveryService.updateAvailabilityLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> completeDelivery({
    required int id,
    required String pin,
    String? podImageBase64,
    String? podSignatureBase64,
  }) async {
    try {
      final updated = await _deliveryService.completeDelivery(
        id: id,
        pin: pin,
        podImageBase64: podImageBase64,
        podSignatureBase64: podSignatureBase64,
      );
      final index = _deliveries.indexWhere((d) => d.id == id);
      if (index >= 0) _deliveries[index] = updated;
      if (_activeDelivery?.id == id) _activeDelivery = updated;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
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

    Future<void> onLocationUpdate(Position position) async {
      await _sendLocationUpdate(driverId, deliveryId, position);
    }

    _locationService.startPeriodicUpdates(onLocationUpdate);
    await _locationService.startStreamUpdates(onLocationUpdate);
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
