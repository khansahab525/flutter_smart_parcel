import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config/api_config.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicTimer;
  void Function(Position position)? _onLocationUpdate;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  /// Start periodic location updates every 5 minutes for driver background tracking.
  void startPeriodicUpdates(void Function(Position) onUpdate) {
    _onLocationUpdate = onUpdate;
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      ApiConfig.locationUpdateInterval,
      (_) => _fetchAndNotify(),
    );
    _fetchAndNotify();
  }

  /// Also listen to continuous position stream for more responsive updates.
  Future<void> startStreamUpdates(void Function(Position) onUpdate) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _onLocationUpdate = onUpdate;
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen(onUpdate);
  }

  Future<void> _fetchAndNotify() async {
    final position = await getCurrentPosition();
    if (position != null && _onLocationUpdate != null) {
      _onLocationUpdate!(position);
    }
  }

  void stopUpdates() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _onLocationUpdate = null;
  }

  double speedKmh(Position position) {
    return (position.speed * 3.6).clamp(0, 200);
  }
}
