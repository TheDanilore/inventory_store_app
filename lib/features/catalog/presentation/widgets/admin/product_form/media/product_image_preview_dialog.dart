import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/services/product_image_url_resolver.dart';

/// Diálogo modal con visor interactivo (zoom y paneo) para vista previa a pantalla completa
class ProductImagePreviewDialog extends StatelessWidget {
  final FormImageItem item;

  const ProductImagePreviewDialog({super.key, required this.item});

  static Future<void> show(BuildContext context, FormImageItem item) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProductImagePreviewDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                maxScale: 3.5,
                child: _buildPreviewContent(),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 24,
              ),
              tooltip: 'Cerrar vista previa',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (item.newBytes != null) {
      return Image.memory(
        item.newBytes!,
        fit: BoxFit.contain,
        // Limita el buffer a 1000px en preview para no saturar memoria en pantallas de alta densidad
        cacheWidth: 1000,
      );
    }

    final rawUrl =
        item.isExisting ? item.existing!.imageUrl : item.externalUrl ?? '';
    final resolvedUrl = ProductImageUrlResolver.resolve(rawUrl);

    if (resolvedUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.broken_image_rounded,
          size: 48,
          color: Colors.white70,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.contain,
      memCacheWidth: 1000,
      placeholder:
          (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
      errorWidget:
          (context, url, error) => const Center(
            child: Icon(
              Icons.broken_image_rounded,
              size: 48,
              color: Colors.white70,
            ),
          ),
    );
  }
}
