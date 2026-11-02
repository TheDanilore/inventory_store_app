import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_preview_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/services/product_image_url_resolver.dart';

/// Tarjeta de la imagen de portada principal (*Hero Cover Card*).
/// Optimizado con restricciones de memoria de bitmap (400px) para eliminar OOM.
class ProductImageHeroCard extends StatelessWidget {
  final ProductFormCubit cubit;
  final FormImageItem item;
  final bool isSaving;
  final bool isDesktop;

  const ProductImageHeroCard({
    super.key,
    required this.cubit,
    required this.item,
    required this.isSaving,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = isDesktop ? 170.0 : 160.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen con Clip
              ClipRRect(
                borderRadius: BorderRadius.circular(11.8),
                child: GestureDetector(
                  onTap: () => ProductImagePreviewDialog.show(context, item),
                  child: _buildHeroThumbnail(),
                ),
              ),

              // Gradiente superior para contraste de botones
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11.8),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Badge Portada Principal (Top Left)
              Positioned(
                top: 7,
                left: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'PORTADA',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Botón Eliminar (Top Right)
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: 'Eliminar portada',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isSaving ? null : () => cubit.removeImage(0),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Botón Zoom / Previsualizar (Bottom Right)
              Positioned(
                bottom: 6,
                right: 6,
                child: Tooltip(
                  message: 'Ver en pantalla completa',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap:
                          () => ProductImagePreviewDialog.show(context, item),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.fullscreen_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size,
          child: const Text(
            'Foto principal visible en tienda y catálogos',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroThumbnail() {
    if (item.newBytes != null) {
      return Image.memory(
        item.newBytes!,
        fit: BoxFit.cover,
        // Restricción de memoria para evitar OOM con fotos de cámara
        cacheWidth: 400,
        cacheHeight: 400,
      );
    }

    final rawUrl =
        item.isExisting ? item.existing!.imageUrl : item.externalUrl ?? '';
    final resolvedUrl = ProductImageUrlResolver.resolve(rawUrl);

    if (resolvedUrl.isEmpty) {
      return _buildBrokenFallback('Sin URL');
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.cover,
      // Restricción de buffer en RAM (evita decodificar 48MB por imagen)
      memCacheWidth: 400,
      memCacheHeight: 400,
      placeholder:
          (context, url) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      errorWidget:
          (context, url, error) => _buildBrokenFallback('Error enlace'),
    );
  }

  Widget _buildBrokenFallback(String message) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFF94A3B8),
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
