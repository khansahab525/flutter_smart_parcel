import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

class ApiService {
  int? _userId;

  void setUserId(int? userId) => _userId = userId;
  int? get userId => _userId;

  Map<String, String> get _headers => ApiConfig.defaultHeaders;

  Uri _buildUri(String endpoint) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final params = {
      ...uri.queryParameters,
      if (_userId != null) 'user_id': '$_userId',
    };
    return uri.replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    Map<String, dynamic> body;
    try {
      body = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      final preview = response.body.length > 120
          ? '${response.body.substring(0, 120)}...'
          : response.body;
      throw ApiException(
        'Invalid server response (${response.statusCode}). '
        'Server returned non-JSON. Preview: $preview',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400 || body['success'] == false) {
      throw ApiException(
        body['error'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final payload = {...?body};
    if (_userId != null && !payload.containsKey('user_id')) {
      payload['user_id'] = _userId;
    }

    final response = await http.post(
      _buildUri(endpoint),
      headers: _headers,
      body: json.encode(payload),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      _buildUri(endpoint),
      headers: _headers,
    );
    return _handleResponse(response);
  }
}
