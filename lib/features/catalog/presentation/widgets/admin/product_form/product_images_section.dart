import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductImagesSection extends StatelessWidget {
  const ProductImagesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Multimedia del Producto',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              BlocBuilder<ProductFormCubit, ProductFormState>(
                buildWhen: (p, c) => p.formImages.length != c.formImages.length,
                builder: (context, state) {
                  final count = state.formImages.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count / 8 fotos',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          BlocBuilder<ProductFormCubit, ProductFormState>(
            buildWhen:
                (p, c) =>
                    p.isSaving != c.isSaving || p.formImages != c.formImages,
            builder: (context, state) {
              final cubit = context.read<ProductFormCubit>();
              if (state.formImages.isEmpty) {
                return _buildEmptyDropZone(context, cubit, state);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mantén presionada una imagen para moverla. La primera foto es la portada principal.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: Row(
                      children: [
                    // Botón Subir
                    InkWell(
                      onTap: state.isSaving ? null : () => cubit.pickImages(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 72,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Subir',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón URL
                    InkWell(
                      onTap:
                          state.isSaving
                              ? null
                              : () => _promptForImageUrl(context, cubit),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 72,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blueGrey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.link_rounded,
                              color: Colors.blueGrey,
                              size: 26,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'URL',
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        buildDefaultDragHandles: false,
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 12,
                            shadowColor: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            child: child,
                          );
                        },
                        itemCount: state.formImages.length,
                        onReorderItem: (oldIndex, newIndex) {
                          if (state.isSaving) return;
                          cubit.reorderImages(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final item = state.formImages[index];
                          final isMain = index == 0;

                          return Container(
                            key: ValueKey(item.id),
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isMain
                                        ? AppColors.primary
                                        : Colors.grey.shade300,
                                width: isMain ? 2.5 : 1,
                              ),
                            ),
                            child: ReorderableDelayedDragStartListener(
                              index: index,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child:
                                        item.isExisting
                                            ? CachedNetworkImage(
                                              imageUrl: item.existing!.imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder:
                                                  (
                                                    context,
                                                    url,
                                                  ) => const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(Icons.error),
                                            )
                                            : item.isExternal
                                                ? CachedNetworkImage(
                                                  imageUrl: item.externalUrl!,
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      (
                                                        context,
                                                        url,
                                                      ) => const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.red,
                                                          ),
                                                )
                                                : Image.memory(
                                                  item.newBytes!,
                                                  fit: BoxFit.cover,
                                                ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 35,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.4),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: ReorderableDragStartListener(
                                      index: index,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.drag_indicator_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isMain)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.9,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(9),
                                            bottomRight: Radius.circular(9),
                                          ),
                                        ),
                                        child: const Text(
                                          'PORTADA',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap:
                                          state.isSaving
                                              ? null
                                              : () => cubit.removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  ),
);
}

  Widget _buildEmptyDropZone(
    BuildContext context,
    ProductFormCubit cubit,
    ProductFormState state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 24,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Arrastra o sube imágenes del producto',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'JPG, PNG o WEBP. La primera foto será la portada.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed:
                    state.isSaving ? null : () => cubit.pickImages(),
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 16,
                ),
                label: const Text('Subir Archivos'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppColors.radius,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed:
                    state.isSaving
                        ? null
                        : () => _promptForImageUrl(context, cubit),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Por URL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppColors.radius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _promptForImageUrl(
    BuildContext context,
    ProductFormCubit cubit,
  ) async {
    String? url;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Pegar URL de Imagen'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                url = ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
    if (url != null && url!.isNotEmpty) {
      cubit.addImageUrl(url!);
    }
  }
}
