import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodingResult {
  final String displayName;
  final double latitude;
  final double longitude;

  const GeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

/// Free address search using the OpenStreetMap Nominatim API.
class GeocodingService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  // Nominatim usage policy requires a valid User-Agent identifying the app.
  static const _headers = {
    'User-Agent': 'SmartDeliveryApp/1.0 (FYP project)',
    'Accept': 'application/json',
  };

  Future<List<GeocodingResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': trimmed,
      'format': 'json',
      'limit': '5',
      'addressdetails': '0',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Address search failed (${response.statusCode})');
    }

    final results = json.decode(response.body) as List<dynamic>;
    return results
        .map((e) => e as Map<String, dynamic>)
        .map((e) => GeocodingResult(
              displayName: e['display_name'] as String? ?? '',
              latitude: double.tryParse(e['lat'] as String? ?? '') ?? 0,
              longitude: double.tryParse(e['lon'] as String? ?? '') ?? 0,
            ))
        .where((r) => r.displayName.isNotEmpty)
        .toList();
  }
}
