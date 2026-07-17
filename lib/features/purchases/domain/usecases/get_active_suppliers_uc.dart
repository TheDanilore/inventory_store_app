import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@injectable
@lazySingleton
class GetActiveSuppliersUseCase {
  final SupabaseClient _supabase;

  GetActiveSuppliersUseCase(this._supabase);

  Future<List<Map<String, dynamic>>> call() async {
    final response = await _supabase
        .from('suppliers')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }
}


