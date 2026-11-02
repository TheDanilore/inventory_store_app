import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio desacoplado para resolver URLs de imágenes de productos (Supabase Storage y URLs externas)
class ProductImageUrlResolver {
  const ProductImageUrlResolver._();

  static const String productBucket = 'products';

  /// Resuelve una URL relativa a su URL pública canónica en Supabase Storage
  static String resolve(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    try {
      return Supabase.instance.client.storage
          .from(productBucket)
          .getPublicUrl(clean);
    } catch (_) {
      return clean;
    }
  }
}

