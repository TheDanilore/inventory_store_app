import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/media/product_image_url_dialog.dart';

/// Zona de arrastre vacía responsive (adaptada a pantallas móviles y de escritorio)
class ProductImageEmptyDropZone extends StatelessWidget {
  final ProductFormCubit cubit;
  final ProductFormState state;
  final bool isDragging;

  const ProductImageEmptyDropZone({
    super.key,
    required this.cubit,
    required this.state,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color:
            isDragging
                ? AppColors.primary.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDragging ? AppColors.primary : const Color(0xFFCBD5E1),
          width: isDragging ? 2.0 : 1.5,
        ),
      ),
      child: Column(
        children: [
          AnimatedScale(
            scale: isDragging ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDragging
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDragging
                    ? Icons.file_download_rounded
                    : (isMobile
                        ? Icons.add_a_photo_outlined
                        : Icons.cloud_upload_outlined),
                size: 32,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isDragging
                ? '¡Suelta los archivos aquí para añadirlos!'
                : (isMobile
                    ? 'Sube fotos del producto'
                    : 'Arrastra imágenes desde tu equipo o súbelas'),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDragging ? AppColors.primary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Formatos JPG, PNG, WEBP o HEIC (máx. 5 MB por foto, hasta 8 fotos).',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: state.isSaving ? null : () => cubit.pickImages(),
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('Tomar Foto / Seleccionar de Galería'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed:
                  state.isSaving
                      ? null
                      : () => ProductImageUrlDialog.prompt(context, cubit),
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text('O ingresar URL web'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: state.isSaving ? null : () => cubit.pickImages(),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                  label: const Text('Subir Archivos'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radius),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed:
                      state.isSaving
                          ? null
                          : () => ProductImageUrlDialog.prompt(context, cubit),
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Por URL'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radius),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

