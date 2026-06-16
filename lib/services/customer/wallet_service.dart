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
}
