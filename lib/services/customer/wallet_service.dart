import 'package:supabase_flutter/supabase_flutter.dart';

class WalletService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<int> fetchBalance(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('wallet_balance')
        .eq('auth_user_id', userId)
        .single();
    
    return (response['wallet_balance'] as num?)?.toInt() ?? 0;
  }

  Future<void> addReward({
    required String profileId,
    required int points,
    required String movementType,
    required String description,
  }) async {
    // Actualizamos el saldo manualmente, ya que no hay trigger en la BD
    final profileResp = await _supabase
        .from('profiles')
        .select('wallet_balance')
        .eq('id', profileId)
        .single();
    
    final currentBalance = (profileResp['wallet_balance'] as num?)?.toInt() ?? 0;
    
    await _supabase.from('profiles').update({
      'wallet_balance': currentBalance + points,
    }).eq('id', profileId);

    // Inserta un registro en wallet_movements.
    await _supabase.from('wallet_movements').insert({
      'profile_id': profileId,
      'points': points,
      'movement_type': movementType,
      'description': description,
    });
  }
}
