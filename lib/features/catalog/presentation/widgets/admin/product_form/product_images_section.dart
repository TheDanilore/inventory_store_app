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
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: 600,
                    maxHeight: 600,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      maxScale: 3.5,
                      child:
                          item.isExisting
                              ? CachedNetworkImage(
                                imageUrl: _resolveImageUrl(
                                  item.existing!.imageUrl,
                                ),
                                fit: BoxFit.contain,
                                placeholder:
                                    (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => const Center(
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
                                placeholder:
                                    (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => const Center(
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
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
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
              buildWhen:
                  (p, c) =>
                      p.isSaving != c.isSaving ||
                      p.formImages.length != c.formImages.length ||
                      p.formImages != c.formImages,
              builder: (context, state) {
                final count = state.formImages.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con título, contador y botones rápidos
                    Wrap(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    count >= 8
                                        ? AppColors.warning.withValues(
                                          alpha: 0.1,
                                        )
                                        : AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count / 8 fotos',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      count >= 8
                                          ? AppColors.warning
                                          : AppColors.primary,
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
                                icon: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 15,
                                ),
                                label: const Text('Subir foto'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
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
                                        : () =>
                                            _promptForImageUrl(context, cubit),
                                icon: const Icon(Icons.link_rounded, size: 15),
                                label: const Text('Por URL'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  foregroundColor: AppColors.textSecondary,
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
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
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (state.formImages.isEmpty)
                      _buildEmptyDropZone(context, cubit, state)
                    else ...[
                      // Nota informativa de orden
                      Row(
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
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
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
                      const SizedBox(height: 14),

                      // Bento Media Studio Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 540;
                          final hero = state.formImages.first;
                          final secondaries = state.formImages.skip(1).toList();

                          final heroWidget = _buildHeroCoverCard(
                            context,
                            cubit,
                            hero,
                            state.isSaving,
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
                              children: [
                                heroWidget,
                                const SizedBox(height: 16),
                                galleryGrid,
                              ],
                            );
                          }
                        },
                      ),
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

  Widget _buildImageThumbnail(FormImageItem item) {
    if (item.newBytes != null) {
      return Image.memory(item.newBytes!, fit: BoxFit.cover);
    }

    final rawUrl =
        item.isExisting ? item.existing!.imageUrl : item.externalUrl ?? '';
    final resolvedUrl = _resolveImageUrl(rawUrl);

    if (resolvedUrl.isEmpty) {
      return _buildBrokenImageFallback('Sin URL');
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => Container(
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
      errorWidget:
          (context, url, error) => _buildBrokenImageFallback('Error de enlace'),
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
    final isMobile = MediaQuery.sizeOf(context).width < 720;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color:
            _isDragging
                ? AppColors.primary.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
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
                color:
                    _isDragging
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDragging
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
            _isDragging
                ? '¡Suelta los archivos aquí para añadirlos!'
                : (isMobile
                    ? 'Sube fotos del producto'
                    : 'Arrastra imágenes desde tu equipo o súbelas'),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _isDragging ? AppColors.primary : AppColors.textPrimary,
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
                      : () => _promptForImageUrl(context, cubit),
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
        ],
      ),
    );
  }

  Widget _buildHeroCoverCard(
    BuildContext context,
    ProductFormCubit cubit,
    FormImageItem item,
    bool isSaving, {
    required bool isDesktop,
  }) {
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
                  onTap: () => _showImagePreview(context, item),
                  child: _buildImageThumbnail(item),
                ),
              ),

              // Gradiente superior para botones
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
                      onTap: () => _showImagePreview(context, item),
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
              _buildSecondaryCard(
                context,
                cubit,
                secondaries[i],
                actualIndex: i + 1,
                isSaving: isSaving,
              ),
            if (count < 8) _buildAddMoreTile(context, cubit, isSaving),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryCard(
    BuildContext context,
    ProductFormCubit cubit,
    FormImageItem item, {
    required int actualIndex,
    required bool isSaving,
  }) {
    const cardSize = 82.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = actualIndex),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color:
                _hoveredIndex == actualIndex
                    ? AppColors.primary
                    : const Color(0xFFE2E8F0),
            width: _hoveredIndex == actualIndex ? 1.8 : 1.0,
          ),
          boxShadow:
              _hoveredIndex == actualIndex
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
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(9.5),
              child: GestureDetector(
                onTap: () => _showImagePreview(context, item),
                child: _buildImageThumbnail(item),
              ),
            ),

            // Gradiente superior
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
                  '#${actualIndex + 1}',
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
                  onTap: isSaving ? null : () => cubit.removeImage(actualIndex),
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
                        isSaving
                            ? null
                            : () => cubit.reorderImages(actualIndex, 0),
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

  Future<void> _promptForImageUrl(
    BuildContext context,
    ProductFormCubit cubit,
  ) async {
    final isMobile = MediaQuery.of(context).size.width < 600;
    String? url;

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Añadir imagen por URL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'https://ejemplo.com/producto.jpg',
                    labelText: 'Enlace web directo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: (val) {
                    url = val.trim();
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        url = ctrl.text.trim();
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Agregar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
            content: SizedBox(
              width: 440,
              child: TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'https://ejemplo.com/producto.jpg',
                  labelText: 'Enlace web directo',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (val) {
                  url = val.trim();
                  Navigator.pop(ctx);
                },
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
    }

    if (url != null && url!.isNotEmpty) {
      cubit.addImageUrl(url!);
    }
  }
}
