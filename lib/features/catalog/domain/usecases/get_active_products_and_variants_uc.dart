import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@injectable
class GetActiveProductsAndVariantsUseCase {
  final SupabaseClient _supabase;

  GetActiveProductsAndVariantsUseCase(this._supabase);

  Future<Map<String, dynamic>> call() async {
    final response = await _supabase
        .from('products')
        .select('*, product_variants(*)')
        .eq('is_active', true)
        .eq('product_variants.is_active', true);
        
    final products = <Map<String, dynamic>>[];
    final variants = <Map<String, dynamic>>[];

    for (var product in response) {
      final pVariants = product['product_variants'] as List<dynamic>? ?? [];
      products.add({
        ...product,
        'product_variants': null, // Remueve los anidados para limpiar el modelo de producto
      });
      variants.addAll(pVariants.map((v) => Map<String, dynamic>.from(v)));
    }

    return {'products': products, 'variants': variants};
  }
}
