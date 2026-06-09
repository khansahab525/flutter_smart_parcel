import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/delivery_model.dart';
import '../services/delivery_service.dart';
import '../services/notification_service.dart';
import '../services/tracking_stream_service.dart';

class TrackingProvider extends ChangeNotifier {
  final DeliveryService _deliveryService;
  final TrackingStreamService _streamService;
  final NotificationService? _notificationService;

  TrackingData? _trackingData;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isChatLoading = false;
  bool _isLiveConnected = false;
  String? _error;
  StreamSubscription<StreamEvent>? _streamSubscription;
  int? _trackingDeliveryId;

  TrackingProvider(
    this._deliveryService,
    this._streamService, [
    this._notificationService,
  ]);

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

    if (event.type == 'notification' && _notificationService != null) {
      final message = event.payload['message'] as String?;
      final eventType = event.payload['event_type'] as String?;
      if (message != null) {
        _notificationService.showLocalNotification(
          title: _titleForEvent(eventType),
          body: message,
          payload: _trackingDeliveryId?.toString(),
        );
      }
    }
  }

  String _titleForEvent(String? eventType) {
    const titles = {
      'assigned': 'Driver Assigned',
      'picked_up': 'Order Picked Up',
      'in_transit': 'In Transit',
      'nearby': 'Driver Nearby',
      'delivered': 'Delivered',
      'delayed': 'Delivery Delay',
    };
    return titles[eventType] ?? 'Delivery Update';
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
