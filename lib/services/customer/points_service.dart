import 'package:supabase_flutter/supabase_flutter.dart';

class PointsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Retorna un mapa con `id` y `wallet_balance` del perfil.
  Future<Map<String, dynamic>?> fetchProfileSummary(String authUserId) async {
    return await _supabase
        .from('profiles')
        .select('id, wallet_balance')
        .eq('auth_user_id', authUserId)
        .maybeSingle();
  }

  /// Retorna el check-in de hoy, si existe.
  Future<Map<String, dynamic>?> fetchTodayCheckin(
    String profileId,
    String todayDate,
  ) async {
    return await _supabase
        .from('daily_checkins')
        .select('id')
        .eq('profile_id', profileId)
        .eq('checkin_date', todayDate)
        .maybeSingle();
  }

  /// Retorna el último check-in para calcular rachas.
  Future<Map<String, dynamic>?> fetchLatestCheckin(String profileId) async {
    return await _supabase
        .from('daily_checkins')
        .select('checkin_date, streak_day, points_received, created_at')
        .eq('profile_id', profileId)
        .order('checkin_date', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  /// Retorna todos los mini juegos jugados hoy para calcular los límites diarios.
  Future<List<Map<String, dynamic>>> fetchTodayMiniGames(
    String profileId,
    String currentDayUtcIso,
  ) async {
    final response = await _supabase
        .from('wallet_movements')
        .select('movement_type, points, created_at')
        .eq('profile_id', profileId)
        .like('movement_type', 'MINI_GAME_%')
        .gte('created_at', currentDayUtcIso);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Retorna el historial de movimientos paginado (Para ahorrar Egress)
  Future<List<Map<String, dynamic>>> fetchMovementsPaginated(
    String profileId,
    int offset,
    int limit,
  ) async {
    final response = await _supabase
        .from('wallet_movements')
        // Extraemos solo lo necesario. Para órdenes solo requerimos el ID para saber si es un pedido.
        .select('*, orders(id)')
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Registra el checkin diario usando funciones de tiempo del servidor donde es posible
  Future<void> claimDailyCheckin({
    required String profileId,
    required String todayDate,
    required int reward,
    required int streakDay,
    required String description,
  }) async {
    // Insert en daily_checkins
    await _supabase.from('daily_checkins').insert({
      'profile_id': profileId,
      'checkin_date': todayDate,
      'points_received': reward,
      'streak_day': streakDay,
      // Dejamos que Supabase asigne el 'created_at' automáticamente (now() in DB)
    });

    // Insert en wallet_movements
    await _supabase.from('wallet_movements').insert({
      'profile_id': profileId,
      'points': reward,
      'movement_type': 'DAILY_CHECKIN',
      'description': description,
    });
  }

  /// Registra un mini juego
  Future<void> recordMiniGamePlay({
    required String profileId,
    required int reward,
    required String movementType,
    required String description,
  }) async {
    await _supabase.from('wallet_movements').insert({
      'profile_id': profileId,
      'points': reward,
      'movement_type': movementType,
      'description': description,
    });
  }
}
