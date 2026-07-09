import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductImagesSection extends StatelessWidget {
  const ProductImagesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Imágenes del Producto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mantén presionada una imagen para moverla, o arrástrala rápidamente usando el ícono de las rayas.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                InkWell(
                  onTap:
                      context.watch<ProductFormCubit>().isSaving
                          ? null
                          : () => context
                              .read<ProductFormCubit>()
                              .pickImages(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 100,
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
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Agregar',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BlocBuilder<ProductFormCubit, ProductFormState>(
                    builder: (context, state) {
        final cubit = context.read<ProductFormCubit>();
                      return ReorderableListView.builder(
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
                                              : () => cubit.removeImage(
                                                context,
                                                index,
                                              ),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
