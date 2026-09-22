class ApiConfig {
  /// Odoo server URL (ngrok tunnel).
  static const String baseUrl =
      'https://protrude-bulgur-juggle.ngrok-free.dev';

  /// Required for ngrok free tier to bypass the browser warning page.
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static const String loginEndpoint = '/api/auth/login';
  static const String registerEndpoint = '/api/auth/register';
  static const String forgotPasswordEndpoint = '/api/auth/forgot-password';
  static const String logoutEndpoint = '/api/auth/logout';
  static const String meEndpoint = '/api/auth/me';
  static const String deliveryListEndpoint = '/api/delivery/list';
  static const String deliveryListPollEndpoint =
      '/api/delivery/list/poll';
  static const String deliveryCreateEndpoint = '/api/delivery/create';
  static const String driverLocationEndpoint = '/api/driver/location/update';
  static const String driverAvailabilityLocationEndpoint =
      '/api/driver/availability/location';
  static const String driverAvailabilityEndpoint =
      '/api/driver/availability';
  static const String availableDriversEndpoint = '/api/drivers/available';
  static const String driverOffersEndpoint = '/api/driver/offers';
  static const String driverOfferPollEndpoint =
      '/api/driver/offers/poll';
  static const String chatEndpoint = '/api/chat';
  static const String trackingEndpoint = '/api/tracking';

  static String deliveryDetail(int id) => '/api/delivery/$id';
  static String deliveryStatus(int id) => '/api/delivery/$id/status';
  static String deliveryComplete(int id) => '/api/delivery/$id/complete';
  static String deliveryCancel(int id) => '/api/delivery/$id/cancel';
  static String deliveryRate(int id) => '/api/delivery/$id/rate';
  static String acceptDriverOffer(int id) =>
      '$driverOffersEndpoint/$id/accept';
  static String rejectDriverOffer(int id) =>
      '$driverOffersEndpoint/$id/reject';
  static String tracking(int id) => '$trackingEndpoint/$id';
  static String trackingStream(int id) => '$trackingEndpoint/$id/stream';
  static String trackingPoll(int id) => '$trackingEndpoint/$id/poll';

  static const Duration locationUpdateInterval = Duration(seconds: 30);
  static const Duration streamReconnectDelay = Duration(seconds: 5);
}
