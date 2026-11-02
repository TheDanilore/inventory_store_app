/// Helper especializado en normalización de texto, generación de slugs y SEO
/// para el formulario de catálogo de productos.
class ProductFormSeoHelper {
  const ProductFormSeoHelper._();

  /// Genera un slug apto para URL a partir de un texto en español.
  static String slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Limpia un slug ingresado manualmente para asegurar caracteres válidos.
  static String cleanSlug(String slug) {
    return slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-]'), '-');
  }

  /// Genera título SEO por defecto.
  static String defaultSeoTitle(String name) {
    final clean = name.trim();
    return clean.isNotEmpty ? '$clean | Tienda Oficial' : '';
  }

  /// Genera descripción SEO recortada a 155 caracteres.
  static String defaultSeoDescription(String description) {
    final desc = description.trim();
    if (desc.length > 155) {
      return '${desc.substring(0, 152)}...';
    }
    return desc;
  }
}
