import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;
  static const _userKey = 'smart_delivery_user';

  AuthService(this._api);

  Future<UserModel> login(String username, String password) async {
    return _authenticate(
      endpoint: ApiConfig.loginEndpoint,
      payload: {'login': username, 'password': password},
      fallbackError: 'Login failed',
    );
  }

  Future<UserModel> register({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    return _authenticate(
      endpoint: ApiConfig.registerEndpoint,
      payload: {
        'name': name,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      },
      fallbackError: 'Registration failed',
    );
  }

  Future<String> forgotPassword(String email) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.forgotPasswordEndpoint}',
    );

    final response = await http.post(
      uri,
      headers: ApiConfig.defaultHeaders,
      body: json.encode({'email': email}),
    );

    Map<String, dynamic> body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Invalid server response. Please try again.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400 || body['success'] == false) {
      throw ApiException(
        body['error'] as String? ?? 'Unable to send reset instructions',
        statusCode: response.statusCode,
      );
    }

    final data = body['data'] as Map<String, dynamic>? ?? {};
    return data['message'] as String? ??
        'Password reset instructions have been sent.';
  }

  Future<UserModel> _authenticate({
    required String endpoint,
    required Map<String, dynamic> payload,
    required String fallbackError,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http.post(
      uri,
      headers: ApiConfig.defaultHeaders,
      body: json.encode(payload),
    );

    Map<String, dynamic> body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Invalid server response. Check Odoo URL and database name.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400 || body['success'] == false) {
      throw ApiException(
        body['error'] as String? ?? fallbackError,
        statusCode: response.statusCode,
      );
    }

    final user = UserModel.fromJson(body['data'] as Map<String, dynamic>);
    await _persistUser(user);
    _api.setUserId(user.userId);
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiConfig.logoutEndpoint);
    } catch (_) {}
    await _clearUser();
    _api.setUserId(null);
  }

  Future<UserModel?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson == null) return null;

    final user = UserModel.fromJson(
      json.decode(userJson) as Map<String, dynamic>,
    );
    _api.setUserId(user.userId);
    try {
      final response = await _api.get(ApiConfig.meEndpoint);
      final refreshed = UserModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
      await _persistUser(refreshed);
      return refreshed;
    } catch (_) {
      return user;
    }
  }

  Future<void> _persistUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
  }

  Future<void> _clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
