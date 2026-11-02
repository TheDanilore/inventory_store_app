import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:inventory_store_app/core/services/cache/geocoding_lru_cache.dart';
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

  // Cabeceras obligatorias para evitar bloqueo (HTTP 403 / 429) en servidores OSM/Photon al ejecutarse como APK en Android
  static const Map<String, String> _headers = {
    'User-Agent':
        'InventoryStoreApp/1.0 (com.inventorystore.app; contact@inventorystore.app)',
    'Accept': 'application/json',
    'Accept-Language': 'es,es-ES;q=0.9,es-419;q=0.8',
  };

  /// Busca lugares usando Photon (OSM) con caché LRU en memoria.
  Future<List<PlaceResult>> searchPlaces(
    String query, {
    LatLng? locationBias,
  }) async {
    try {
      final clean = query.trim();
      if (clean.isEmpty) return [];

      // Si no hay bias o para búsquedas idénticas, consultar el caché LRU
      final cached = GeocodingLruCache.instance.getSearch(clean);
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      String url = '$_baseUrl/api/?q=${Uri.encodeComponent(clean)}&limit=10';
      if (locationBias != null) {
        url += '&lat=${locationBias.latitude}&lon=${locationBias.longitude}';
      }

      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        final results =
            features
                .map((f) => PlaceResult.fromJson(f as Map<String, dynamic>))
                .toList();

        if (results.isNotEmpty) {
          GeocodingLruCache.instance.putSearch(clean, results);
        }
        return results;
      } else {
        developer.log(
          '[GeocodingService] searchPlaces devolvió código HTTP ${response.statusCode}: ${response.body}',
          name: 'GeocodingService',
        );
      }
      return [];
    } catch (e, st) {
      developer.log(
        '[GeocodingService] Error al buscar lugares: $e',
        error: e,
        stackTrace: st,
        name: 'GeocodingService',
      );
      return [];
    }
  }

  /// Realiza Geocodificación inversa con caché LRU de ~11 metros de radio.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      // 1. Consultar caché LRU en memoria (0ms RTT)
      final cached = GeocodingLruCache.instance.getReverse(lat, lng);
      if (cached != null) {
        return cached;
      }

      final url = '$_baseUrl/reverse?lon=$lng&lat=$lat';
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final place = PlaceResult.fromJson(
            features.first as Map<String, dynamic>,
          );
          final fullAddress = place.fullAddress;
          GeocodingLruCache.instance.putReverse(lat, lng, fullAddress);
          return fullAddress;
        }
      } else {
        developer.log(
          '[GeocodingService] reverseGeocode devolvió código HTTP ${response.statusCode}: ${response.body}',
          name: 'GeocodingService',
        );
      }
      return null;
    } catch (e, st) {
      developer.log(
        '[GeocodingService] Error en reverseGeocode: $e',
        error: e,
        stackTrace: st,
        name: 'GeocodingService',
      );
      return null;
    }
  }
}
