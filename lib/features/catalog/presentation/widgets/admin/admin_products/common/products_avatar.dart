import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

/// Utilidad para obtener el monograma (1 o 2 iniciales) del nombre del producto.
String getProductMonogram(String name) {
  final clean = name.trim();
  if (clean.isEmpty) return 'PR';
  final parts = clean.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return clean.length >= 2
      ? clean.substring(0, 2).toUpperCase()
      : clean[0].toUpperCase();
}

/// Avatar de producto con soporte para imagen de red, shimmer y fallback a monograma.
class ProductAvatar extends StatelessWidget {
  final ProductEntity product;
  final double size;

  const ProductAvatar({super.key, required this.product, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        product.images.isNotEmpty
            ? product.images
                .firstWhere(
                  (img) => img.isMain,
                  orElse: () => product.images.first,
                )
                .imageUrl
            : null;

    final borderRadius = BorderRadius.circular(size > 44 ? 14 : 8);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  ProductMonogramAvatar(name: product.name, size: size),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: AppColors.background,
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    }

    return ProductMonogramAvatar(name: product.name, size: size);
  }
}

/// Monograma estético con las iniciales del producto.
class ProductMonogramAvatar extends StatelessWidget {
  final String name;
  final double size;

  const ProductMonogramAvatar({
    super.key,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final monogram = getProductMonogram(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size > 44 ? 14 : 8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      alignment: Alignment.center,
      child: Text(
        monogram,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
