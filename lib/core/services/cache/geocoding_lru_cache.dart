import 'package:inventory_store_app/core/services/geocoding_service.dart';

/// Caché LRU en memoria para geocodificación inversa y búsqueda de lugares.
/// Previene peticiones HTTP redundantes a servidores externos (Photon / OpenStreetMap),
/// optimizando el consumo de datos móviles y garantizando respuestas instantáneas (0ms RTT).
class GeocodingLruCache {
  static final GeocodingLruCache instance = GeocodingLruCache._();
  GeocodingLruCache._();

  static const int _maxReverseEntries = 60;
  static const int _maxSearchEntries = 40;

  final Map<String, String> _reverseCache = {};
  final Map<String, List<PlaceResult>> _searchCache = {};

  /// Redondea a 4 decimales (~11 metros de precisión en el ecuador),
  /// permitiendo que micro-movimientos del mapa reutilicen la misma dirección resuelta.
  String _buildReverseKey(double lat, double lng) {
    return '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
  }

  String? getReverse(double lat, double lng) {
    final key = _buildReverseKey(lat, lng);
    final value = _reverseCache.remove(key);
    if (value != null) {
      _reverseCache[key] = value; // Actualizar LRU (más reciente al final)
      return value;
    }
    return null;
  }

  void putReverse(double lat, double lng, String address) {
    final key = _buildReverseKey(lat, lng);
    if (_reverseCache.containsKey(key)) {
      _reverseCache.remove(key);
    } else if (_reverseCache.length >= _maxReverseEntries) {
      _reverseCache.remove(_reverseCache.keys.first);
    }
    _reverseCache[key] = address;
  }

  List<PlaceResult>? getSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final value = _searchCache.remove(clean);
    if (value != null) {
      _searchCache[clean] = value;
      return value;
    }
    return null;
  }

  void putSearch(String query, List<PlaceResult> results) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;
    if (_searchCache.containsKey(clean)) {
      _searchCache.remove(clean);
    } else if (_searchCache.length >= _maxSearchEntries) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[clean] = results;
  }

  void clear() {
    _reverseCache.clear();
    _searchCache.clear();
  }
}
