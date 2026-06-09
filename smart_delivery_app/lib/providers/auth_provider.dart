import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final NotificationService? _notificationService;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(ApiService apiService, [NotificationService? notificationService])
      : _authService = AuthService(apiService),
        _notificationService = notificationService;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isDriver => _user?.isDriver ?? false;
  bool get isCustomer => _user?.isCustomer ?? false;

  Future<void> init() async {
    _user = await _authService.getStoredUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      await _notificationService?.registerTokenWithBackend();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _notificationService?.unregisterToken();
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
