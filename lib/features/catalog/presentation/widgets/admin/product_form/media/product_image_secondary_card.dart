import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_preview_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/services/product_image_url_resolver.dart';

/// Tarjeta de imagen secundaria individual (82x82 px).
/// Encapsula su propio estado de hover para no reconstruir la sección padre ante eventos de cursor.
class ProductImageSecondaryCard extends StatefulWidget {
  final ProductFormCubit cubit;
  final FormImageItem item;
  final int actualIndex;
  final bool isSaving;

  const ProductImageSecondaryCard({
    super.key,
    required this.cubit,
    required this.item,
    required this.actualIndex,
    required this.isSaving,
  });

  @override
  State<ProductImageSecondaryCard> createState() =>
      _ProductImageSecondaryCardState();
}

class _ProductImageSecondaryCardState extends State<ProductImageSecondaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const cardSize = 82.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: _isHovered ? AppColors.primary : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.8 : 1.0,
          ),
          boxShadow:
              _isHovered
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail con límites de memoria
            ClipRRect(
              borderRadius: BorderRadius.circular(9.5),
              child: GestureDetector(
                onTap:
                    () => ProductImagePreviewDialog.show(context, widget.item),
                child: _buildSecondaryThumbnail(),
              ),
            ),

            // Gradiente superior para visibilidad de controles
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9.5),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Badge número de foto (Top Left)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${widget.actualIndex + 1}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Botón Eliminar (Top Right)
            Positioned(
              top: 4,
              right: 4,
              child: Tooltip(
                message: 'Eliminar',
                child: GestureDetector(
                  onTap:
                      widget.isSaving
                          ? null
                          : () => widget.cubit.removeImage(widget.actualIndex),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Botón Hacer Portada (Bottom Bar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Tooltip(
                message: 'Hacer portada principal',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        widget.isSaving
                            ? null
                            : () => widget.cubit.reorderImages(
                              widget.actualIndex,
                              0,
                            ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(9.5),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(9.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: Color(0xFFFFC107),
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Portada',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryThumbnail() {
    if (widget.item.newBytes != null) {
      return Image.memory(
        widget.item.newBytes!,
        fit: BoxFit.cover,
        // Limita a 200px para miniatura de 82px
        cacheWidth: 200,
        cacheHeight: 200,
      );
    }

    final rawUrl =
        widget.item.isExisting
            ? widget.item.existing!.imageUrl
            : widget.item.externalUrl ?? '';
    final resolvedUrl = ProductImageUrlResolver.resolve(rawUrl);

    if (resolvedUrl.isEmpty) {
      return _buildBrokenFallback('Sin URL');
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.cover,
      // Restricción de memoria para miniaturas
      memCacheWidth: 200,
      memCacheHeight: 200,
      placeholder:
          (context, url) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      errorWidget: (context, url, error) => _buildBrokenFallback('Error'),
    );
  }

  Widget _buildBrokenFallback(String message) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            message,
            style: const TextStyle(
              fontSize: 8.5,
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
