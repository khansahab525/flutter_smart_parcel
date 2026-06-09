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

  Future<UserModel> login(String email, String password) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}',
    ).replace(queryParameters: {'db': ApiConfig.defaultDatabase});

    final response = await http.post(
      uri,
      headers: ApiConfig.defaultHeaders,
      body: json.encode({
        'login': email,
        'password': password,
        'db': ApiConfig.defaultDatabase,
      }),
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
        body['error'] as String? ?? 'Login failed',
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
    return user;
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
