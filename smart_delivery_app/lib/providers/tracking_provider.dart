import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';
import '../services/tracking_stream_service.dart';

class TrackingProvider extends ChangeNotifier {
  final DeliveryService _deliveryService;
  final TrackingStreamService _streamService;

  TrackingData? _trackingData;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isChatLoading = false;
  bool _isLiveConnected = false;
  String? _error;
  StreamSubscription<StreamEvent>? _streamSubscription;
  int? _trackingDeliveryId;

  TrackingProvider(this._deliveryService, this._streamService);

  TrackingData? get trackingData => _trackingData;
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;
  bool get isLiveConnected => _isLiveConnected;
  String? get error => _error;

  DeliveryModel? get delivery => _trackingData?.delivery;

  Future<void> startTracking(int deliveryId) async {
    _trackingDeliveryId = deliveryId;
    _isLoading = true;
    notifyListeners();

    try {
      _trackingData = await _deliveryService.getTracking(deliveryId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();

    _streamSubscription?.cancel();
    _streamService.start(deliveryId);
    _streamSubscription = _streamService.events.listen(_onStreamEvent);
  }

  void _onStreamEvent(StreamEvent event) {
    if (event.type == 'connected') {
      _isLiveConnected = true;
      notifyListeners();
      return;
    }

    if (event.type == 'stream_end') {
      _isLiveConnected = false;
      notifyListeners();
      return;
    }

    _isLiveConnected = true;
    final updatedDelivery = event.delivery;

    if (updatedDelivery != null && _trackingData != null) {
      final driverLoc = event.payload['driver_location'] as Map<String, dynamic>?;
      _trackingData = TrackingData(
        delivery: updatedDelivery,
        driverLat: driverLoc != null
            ? (driverLoc['latitude'] as num?)?.toDouble()
            : _trackingData!.driverLat,
        driverLng: driverLoc != null
            ? (driverLoc['longitude'] as num?)?.toDouble()
            : _trackingData!.driverLng,
        destLat: _trackingData!.destLat,
        destLng: _trackingData!.destLng,
        pickupLat: _trackingData!.pickupLat,
        pickupLng: _trackingData!.pickupLng,
        routeHistory: _trackingData!.routeHistory,
        notifications: _trackingData!.notifications,
      );
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (_trackingDeliveryId == null || text.trim().isEmpty) return;

    _messages.add(ChatMessage.user(text));
    _isChatLoading = true;
    notifyListeners();

    try {
      final response = await _deliveryService.sendChatMessage(
        _trackingDeliveryId!,
        text,
      );
      _messages.add(ChatMessage.assistant(response));
      _isChatLoading = false;
      notifyListeners();
    } catch (e) {
      _messages.add(ChatMessage.assistant(
        'Sorry, I could not process your request. Please try again.',
      ));
      _isChatLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitRating(int rating, String? feedback) async {
    if (_trackingDeliveryId == null) return false;

    try {
      final updated = await _deliveryService.rateDelivery(
        id: _trackingDeliveryId!,
        rating: rating,
        feedback: feedback,
      );
      if (_trackingData != null) {
        _trackingData = TrackingData(
          delivery: updated,
          driverLat: _trackingData!.driverLat,
          driverLng: _trackingData!.driverLng,
          destLat: _trackingData!.destLat,
          destLng: _trackingData!.destLng,
          pickupLat: _trackingData!.pickupLat,
          pickupLng: _trackingData!.pickupLng,
          routeHistory: _trackingData!.routeHistory,
          notifications: _trackingData!.notifications,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void stopTracking() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamService.stop();
    _trackingDeliveryId = null;
    _trackingData = null;
    _messages = [];
    _isLiveConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
