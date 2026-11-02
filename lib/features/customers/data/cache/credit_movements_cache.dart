import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

/// Almacén de caché en memoria de alta velocidad para movimientos de crédito.
/// Implementa Stale-While-Revalidate (SWR): Permite mostrar instantáneamente
/// los movimientos previos al reingresar a la pantalla (0 ms, sin parpadeo/shimmer),
/// mientras se valida de forma no bloqueante con el servidor.
class CreditMovementsCacheEntry {
  final List<CreditMovementEntity> items;
  final int totalCount;
  final double totalCharged;
  final double totalPaid;
  final int chargeCount;
  final int paymentCount;
  final double? currentDebt;
  final double? creditLimit;
  final DateTime timestamp;

  CreditMovementsCacheEntry({
    required this.items,
    required this.totalCount,
    required this.totalCharged,
    required this.totalPaid,
    required this.chargeCount,
    required this.paymentCount,
    this.currentDebt,
    this.creditLimit,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Determina si la entrada de caché aún es fresca (TTL por defecto: 5 minutos).
  bool isFresh({Duration ttl = const Duration(minutes: 5)}) {
    return DateTime.now().difference(timestamp) < ttl;
  }
}

class CreditMovementsCache {
  // Singleton en memoria accesible entre recreaciones de pantallas/cubits
  static final CreditMovementsCache _instance =
      CreditMovementsCache._internal();
  factory CreditMovementsCache() => _instance;
  CreditMovementsCache._internal();

  final Map<String, CreditMovementsCacheEntry> _cache = {};

  static String buildKey({
    required String creditId,
    required String dateFilter,
    required String typeFilter,
    required int page,
  }) {
    return '${creditId}_${dateFilter}_${typeFilter}_$page';
  }

  /// Obtiene la entrada en caché si existe y no ha expirado el TTL estricto (15 min)
  CreditMovementsCacheEntry? get({
    required String creditId,
    required String dateFilter,
    required String typeFilter,
    required int page,
  }) {
    final key = buildKey(
      creditId: creditId,
      dateFilter: dateFilter,
      typeFilter: typeFilter,
      page: page,
    );
    final entry = _cache[key];
    if (entry == null) return null;

    // Si ha pasado más de 15 minutos, consideramos la entrada obsoleta
    if (!entry.isFresh(ttl: const Duration(minutes: 15))) {
      _cache.remove(key);
      return null;
    }

    return entry;
  }

  /// Guarda una entrada en el caché
  void put({
    required String creditId,
    required String dateFilter,
    required String typeFilter,
    required int page,
    required CreditMovementsCacheEntry entry,
  }) {
    final key = buildKey(
      creditId: creditId,
      dateFilter: dateFilter,
      typeFilter: typeFilter,
      page: page,
    );
    _cache[key] = entry;
  }

  /// Invalida todas las páginas y filtros de un crédito específico
  /// (Se ejecuta al registrar un nuevo abono o cargo para garantizar consistencia)
  void invalidate(String creditId) {
    _cache.removeWhere((key, _) => key.startsWith('${creditId}_'));
  }

  /// Limpia todo el caché (ej. al cerrar sesión)
  void clear() {
    _cache.clear();
  }
}
