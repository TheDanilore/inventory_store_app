import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceResult {
  final String name;
  final String? city;
  final String? state;
  final String? country;
  final double latitude;
  final double longitude;

  PlaceResult({
    required this.name,
    this.city,
    this.state,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  String get fullAddress {
    final parts =
        [
          name,
          city,
          state,
          country,
        ].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] ?? {};
    final coords = json['geometry']?['coordinates'] as List<dynamic>?;

    return PlaceResult(
      name: props['name'] ?? props['street'] ?? 'Ubicación',
      city: props['city'] ?? props['county'],
      state: props['state'],
      country: props['country'],
      latitude:
          coords != null && coords.length >= 2
              ? (coords[1] as num).toDouble()
              : 0.0,
      longitude:
          coords != null && coords.length >= 2
              ? (coords[0] as num).toDouble()
              : 0.0,
    );
  }
}

class GeocodingService {
  static const String _baseUrl = 'https://photon.komoot.io';

  /// Busca lugares usando Photon (OSM)
  Future<List<PlaceResult>> searchPlaces(
    String query, {
    LatLng? locationBias,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      String url = '$_baseUrl/api/?q=${Uri.encodeComponent(query)}&limit=10';
      if (locationBias != null) {
        url += '&lat=${locationBias.latitude}&lon=${locationBias.longitude}';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        return features
            .map((f) => PlaceResult.fromJson(f as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Realiza Geocodificación inversa
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = '$_baseUrl/reverse?lon=$lng&lat=$lat';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final place = PlaceResult.fromJson(
            features.first as Map<String, dynamic>,
          );
          return place.fullAddress;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
