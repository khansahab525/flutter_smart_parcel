import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/api_config.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  final ApiService _api;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _firebaseAvailable = false;
  String? _fcmToken;

  NotificationService(this._api);

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    if (_initialized) return;

    await _initLocalNotifications();

    try {
      await Firebase.initializeApp();
      _firebaseAvailable = true;
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      await _initFirebaseMessaging();
    } catch (e) {
      debugPrint('Firebase not configured: $e');
      _firebaseAvailable = false;
    }

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (Platform.isAndroid) {
      final plugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(const AndroidNotificationChannel(
        'smart_delivery',
        'Delivery Updates',
        description: 'Notifications for delivery status and ETA updates',
        importance: Importance.high,
      ));
    }
  }

  Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _fcmToken = await messaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    messaging.onTokenRefresh.listen((token) async {
      _fcmToken = token;
      await registerTokenWithBackend();
    });
  }

  Future<void> registerTokenWithBackend() async {
    if (!_firebaseAvailable || _fcmToken == null) return;

    try {
      await _api.post(ApiConfig.fcmRegisterEndpoint, body: {
        'token': _fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_name': Platform.operatingSystem,
      });
    } catch (e) {
      debugPrint('FCM registration failed: $e');
    }
  }

  Future<void> unregisterToken() async {
    if (_fcmToken == null) return;
    try {
      await _api.post(ApiConfig.fcmUnregisterEndpoint, body: {
        'token': _fcmToken,
      });
    } catch (_) {}
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_delivery',
          'Delivery Updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['delivery_id'],
    );
  }

  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('Notification opened: ${message.data}');
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_delivery',
          'Delivery Updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
