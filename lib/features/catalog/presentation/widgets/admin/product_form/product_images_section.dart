import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_empty_drop_zone.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_hero_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_secondary_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_url_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';

/// Sección multimedia del formulario de productos.
/// Soporta Drag & Drop interactivo, optimización de memoria (0 OOM en low-end) y rebuilds aislados.
class ProductImagesSection extends StatefulWidget {
  const ProductImagesSection({super.key});

  @override
  State<ProductImagesSection> createState() => _ProductImagesSectionState();
}

class _ProductImagesSectionState extends State<ProductImagesSection> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

    return DropTarget(
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        final files = detail.files;
        if (files.isNotEmpty) {
          cubit.addDroppedFiles(files);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              _isDragging
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(
            color: _isDragging ? AppColors.primary : AppColors.border,
            width: _isDragging ? 2.0 : 1.0,
          ),
          boxShadow:
              _isDragging
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ]
                  : AppColors.cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlocBuilder<ProductFormCubit, ProductFormState>(
              // Optimización crítica: Comparación profunda de contenido en lugar de referencia de lista
              // para evitar reconstrucciones parásitas mientras el usuario teclea en el formulario.
              buildWhen:
                  (p, c) =>
                      p.isSaving != c.isSaving ||
                      !listEquals(p.formImages, c.formImages),
              builder: (context, state) {
                final count = state.formImages.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con título, contador y botones rápidos
                    _buildHeader(context, cubit, state, count),
                    const SizedBox(height: 14),

                    if (state.formImages.isEmpty)
                      ProductImageEmptyDropZone(
                        cubit: cubit,
                        state: state,
                        isDragging: _isDragging,
                      )
                    else ...[
                      // Nota informativa de orden
                      _buildOrderingNote(),
                      const SizedBox(height: 14),

                      // Bento Media Studio Grid
                      _buildMediaGrid(context, cubit, state, count),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProductFormCubit cubit,
    ProductFormState state,
    int count,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isDragging
                  ? Icons.file_download_rounded
                  : Icons.photo_library_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              _isDragging
                  ? 'Suelta las imágenes aquí'
                  : 'Multimedia del Producto',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    count >= 8
                        ? AppColors.warning.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count / 8 fotos',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: count >= 8 ? AppColors.warning : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        if (state.formImages.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed:
                    (state.isSaving || count >= 8)
                        ? null
                        : () => cubit.pickImages(),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 15),
                label: const Text('Subir foto'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed:
                    (state.isSaving || count >= 8)
                        ? null
                        : () => ProductImageUrlDialog.prompt(context, cubit),
                icon: const Icon(Icons.link_rounded, size: 15),
                label: const Text('Por URL'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOrderingNote() {
    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'La primera foto es la portada principal. Haz clic en "Portada" para promocionar cualquier foto.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ),
        if (_isDragging)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Soltar para añadir',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMediaGrid(
    BuildContext context,
    ProductFormCubit cubit,
    ProductFormState state,
    int count,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 540;
        final hero = state.formImages.first;
        final secondaries = state.formImages.skip(1).toList();

        final heroWidget = ProductImageHeroCard(
          cubit: cubit,
          item: hero,
          isSaving: state.isSaving,
          isDesktop: isDesktop,
        );

        final galleryGrid = _buildSecondaryGallery(
          context,
          cubit,
          secondaries,
          state.isSaving,
          count: count,
        );

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heroWidget,
              const SizedBox(width: 18),
              Expanded(child: galleryGrid),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heroWidget, const SizedBox(height: 16), galleryGrid],
          );
        }
      },
    );
  }

  Widget _buildSecondaryGallery(
    BuildContext context,
    ProductFormCubit cubit,
    List<FormImageItem> secondaries,
    bool isSaving, {
    required int count,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < secondaries.length; i++)
              ProductImageSecondaryCard(
                cubit: cubit,
                item: secondaries[i],
                actualIndex: i + 1,
                isSaving: isSaving,
              ),
            if (count < 8) _buildAddMoreTile(context, cubit, isSaving),
          ],
        ),
      ],
    );
  }

  Widget _buildAddMoreTile(
    BuildContext context,
    ProductFormCubit cubit,
    bool isSaving,
  ) {
    const cardSize = 82.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSaving ? null : () => cubit.pickImages(),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: cardSize,
          height: cardSize,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              style: BorderStyle.solid,
              width: 1.2,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              SizedBox(height: 4),
              Text(
                '+ Añadir',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
