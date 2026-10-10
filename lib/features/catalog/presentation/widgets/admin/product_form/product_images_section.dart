import 'package:cached_network_image/cached_network_image.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductImagesSection extends StatefulWidget {
  const ProductImagesSection({super.key});

  @override
  State<ProductImagesSection> createState() => _ProductImagesSectionState();
}

class _ProductImagesSectionState extends State<ProductImagesSection> {
  bool _isDragging = false;
  int? _hoveredIndex;

  String _resolveImageUrl(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    try {
      return Supabase.instance.client.storage
          .from('products')
          .getPublicUrl(clean);
    } catch (_) {
      return clean;
    }
  }

  void _showImagePreview(BuildContext context, FormImageItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
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
                  child: item.isExisting
                      ? CachedNetworkImage(
                          imageUrl: _resolveImageUrl(item.existing!.imageUrl),
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 48,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : item.isExternal
                          ? CachedNetworkImage(
                              imageUrl: _resolveImageUrl(item.externalUrl!),
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : Image.memory(
                              item.newBytes!,
                              fit: BoxFit.contain,
                            ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                tooltip: 'Cerrar vista previa',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          color: _isDragging
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(
            color: _isDragging ? AppColors.primary : AppColors.border,
            width: _isDragging ? 2.0 : 1.0,
          ),
          boxShadow: _isDragging
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                      _isDragging ? 'Suelta las imágenes aquí' : 'Multimedia del Producto',
                      style: const TextStyle(
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
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: count >= 8
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
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            BlocBuilder<ProductFormCubit, ProductFormState>(
              buildWhen: (p, c) =>
                  p.isSaving != c.isSaving || p.formImages != c.formImages,
              builder: (context, state) {
                if (state.formImages.isEmpty) {
                  return _buildEmptyDropZone(context, cubit, state);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Arrastra desde tu equipo o reordena. La primera foto es la portada principal.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ),
                        if (_isDragging)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
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
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 124,
                      child: Row(
                        children: [
                          // Botón Subir Archivo
                          Tooltip(
                            message: 'Seleccionar archivos de imagen',
                            waitDuration: const Duration(milliseconds: 300),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: state.isSaving ? null : () => cubit.pickImages(),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 74,
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
                                        size: 24,
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
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Botón Pegar URL
                          Tooltip(
                            message: 'Añadir imagen por enlace web (URL)',
                            waitDuration: const Duration(milliseconds: 300),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: state.isSaving
                                    ? null
                                    : () => _promptForImageUrl(context, cubit),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 74,
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
                                        size: 24,
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
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Lista horizontal interactiva y reordenable
                          Expanded(
                            child: ReorderableListView.builder(
                              scrollDirection: Axis.horizontal,
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) {
                                return Material(
                                  color: Colors.transparent,
                                  elevation: 12,
                                  shadowColor: Colors.black.withValues(alpha: 0.5),
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
                                final isHovered = _hoveredIndex == index;

                                return MouseRegion(
                                  key: ValueKey(item.id),
                                  onEnter: (_) => setState(() => _hoveredIndex = index),
                                  onExit: (_) => setState(() => _hoveredIndex = null),
                                  cursor: SystemMouseCursors.click,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 104,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isMain
                                            ? AppColors.primary
                                            : isHovered
                                                ? AppColors.primary.withValues(alpha: 0.5)
                                                : Colors.grey.shade300,
                                        width: isMain ? 2.5 : 1,
                                      ),
                                      boxShadow: isHovered
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ReorderableDelayedDragStartListener(
                                      index: index,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: GestureDetector(
                                              onTap: () => _showImagePreview(context, item),
                                              child: _buildImageThumbnail(item),
                                            ),
                                          ),

                                          // Gradiente superior para contraste de botones
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 36,
                                              decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.vertical(
                                                  top: Radius.circular(10),
                                                ),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.black.withValues(alpha: 0.45),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Drag Handle superior izquierdo
                                          Positioned(
                                            top: 4,
                                            left: 4,
                                            child: ReorderableDragStartListener(
                                              index: index,
                                              child: Tooltip(
                                                message: 'Arrastrar para reordenar',
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.4),
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
                                          ),

                                          // Indicador Portada Inferior
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
                                                    alpha: 0.92,
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
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Botón eliminar superior derecho
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Tooltip(
                                              message: 'Eliminar imagen',
                                              child: GestureDetector(
                                                onTap: state.isSaving
                                                    ? null
                                                    : () => cubit.removeImage(index),
                                                child: Container(
                                                  padding: const EdgeInsets.all(3.5),
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
                                                    size: 13,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
      ),
    );
  }

  Widget _buildImageThumbnail(FormImageItem item) {
    if (item.newBytes != null) {
      return Image.memory(
        item.newBytes!,
        fit: BoxFit.cover,
      );
    }

    final rawUrl = item.isExisting
        ? item.existing!.imageUrl
        : item.externalUrl ?? '';
    final resolvedUrl = _resolveImageUrl(rawUrl);

    if (resolvedUrl.isEmpty) {
      return _buildBrokenImageFallback('Sin URL');
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => _buildBrokenImageFallback('Error de enlace'),
    );
  }

  Widget _buildBrokenImageFallback(String message) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFF94A3B8),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 9.5,
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

  Widget _buildEmptyDropZone(
    BuildContext context,
    ProductFormCubit cubit,
    ProductFormState state,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 26,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: _isDragging
            ? AppColors.primary.withValues(alpha: 0.08)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDragging ? AppColors.primary : const Color(0xFFCBD5E1),
          width: _isDragging ? 2.0 : 1.5,
        ),
      ),
      child: Column(
        children: [
          AnimatedScale(
            scale: _isDragging ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDragging
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDragging
                    ? Icons.file_download_rounded
                    : Icons.cloud_upload_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isDragging
                ? '¡Suelta los archivos aquí para añadirlos!'
                : 'Arrastra imágenes desde tu equipo o súbelas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _isDragging ? AppColors.primary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Formatos JPG, PNG o WEBP (hasta 8 fotos). La primera foto será la portada.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: state.isSaving ? null : () => cubit.pickImages(),
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 16,
                ),
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
                onPressed: state.isSaving
                    ? null
                    : () => _promptForImageUrl(context, cubit),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.link_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Pegar URL de Imagen',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://ejemplo.com/producto.jpg',
              labelText: 'Enlace web directo',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                url = ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
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
