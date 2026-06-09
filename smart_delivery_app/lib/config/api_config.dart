class ApiConfig {
  /// Odoo server URL (ngrok tunnel).
  static const String baseUrl =
      'https://25e6-2a02-cb80-4144-6f81-571e-8ae5-f864-a297.ngrok-free.app';

  /// Odoo database name — must match your database exactly.
  static const String defaultDatabase = 'smart_delivery';

  /// Required for ngrok free tier to bypass the browser warning page.
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static const String loginEndpoint = '/api/auth/login';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String meEndpoint = '/api/auth/me';
  static const String deliveryListEndpoint = '/api/delivery/list';
  static const String deliveryCreateEndpoint = '/api/delivery/create';
  static const String driverLocationEndpoint = '/api/driver/location/update';
  static const String chatEndpoint = '/api/chat';
  static const String trackingEndpoint = '/api/tracking';
  static const String fcmRegisterEndpoint = '/api/fcm/register';
  static const String fcmUnregisterEndpoint = '/api/fcm/unregister';

  static String deliveryDetail(int id) => '/api/delivery/$id';
  static String deliveryStatus(int id) => '/api/delivery/$id/status';
  static String tracking(int id) => '$trackingEndpoint/$id';
  static String trackingStream(int id) => '$trackingEndpoint/$id/stream';
  static String trackingPoll(int id) => '$trackingEndpoint/$id/poll';

  static const Duration locationUpdateInterval = Duration(minutes: 5);
  static const Duration trackingPollInterval = Duration(seconds: 8);
  static const Duration streamReconnectDelay = Duration(seconds: 5);
}
