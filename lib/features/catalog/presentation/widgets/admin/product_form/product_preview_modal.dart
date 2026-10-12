import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';

class ProductPreviewModal extends StatefulWidget {
  final ProductFormState state;
  final String productName;
  final String productDesc;

  const ProductPreviewModal({
    super.key,
    required this.state,
    required this.productName,
    required this.productDesc,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductFormState state,
    required String productName,
    required String productDesc,
  }) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    if (isDesktop) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ProductPreviewModal(
            state: state,
            productName: productName,
            productDesc: productDesc,
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: ProductPreviewModal(
            state: state,
            productName: productName,
            productDesc: productDesc,
          ),
        ),
      );
    }
  }

  @override
  State<ProductPreviewModal> createState() => _ProductPreviewModalState();
}

class _ProductPreviewModalState extends State<ProductPreviewModal> {
  int _selectedImageIndex = 0;
  int _selectedVariantIndex = 0;
  int _quantity = 1;

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

  Widget _buildImageWidget(FormImageItem item) {
    if (item.newBytes != null) {
      return Image.memory(item.newBytes!, fit: BoxFit.cover);
    }
    final rawUrl = item.isExisting
        ? item.existing!.imageUrl
        : item.externalUrl ?? '';
    final resolvedUrl = _resolveImageUrl(rawUrl);

    if (resolvedUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
      );
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    final name = widget.productName.trim().isNotEmpty
        ? widget.productName.trim()
        : 'Audífonos Nova Pro Wireless';

    final desc = widget.productDesc.trim().isNotEmpty
        ? widget.productDesc.trim()
        : 'Audífonos inalámbricos de alta definición con cancelación activa de ruido (ANC) híbrida y transductores de neodimio de 40 mm.';

    final images = widget.state.formImages;
    final variants = widget.state.variantDrafts;

    final currentVariant = (variants.isNotEmpty &&
            _selectedVariantIndex < variants.length)
        ? variants[_selectedVariantIndex]
        : null;

    final currentPrice = currentVariant != null &&
            currentVariant.price.trim().isNotEmpty
        ? '\$${currentVariant.price}'
        : '\$279.00';

    final currentSku = currentVariant != null &&
            currentVariant.sku.trim().isNotEmpty
        ? currentVariant.sku
        : 'NOVA-PRO-WRL';

    return Container(
      constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Vista Previa en Vivo · Storefront',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.state.publicationStatus == 'active'
                      ? '🟢 Visible en tienda'
                      : '⚪ Borrador interno',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 22),
                tooltip: 'Cerrar vista previa',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Galería Izquierda
                      Expanded(
                        flex: 5,
                        child: _buildGallery(images, isDark),
                      ),
                      const SizedBox(width: 32),
                      // Ficha Comercial Derecha
                      Expanded(
                        flex: 6,
                        child: _buildCommerceDetails(
                          name,
                          desc,
                          currentPrice,
                          currentSku,
                          variants,
                          isDark,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGallery(images, isDark),
                      const SizedBox(height: 24),
                      _buildCommerceDetails(
                        name,
                        desc,
                        currentPrice,
                        currentSku,
                        variants,
                        isDark,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGallery(List<FormImageItem> images, bool isDark) {
    final hasImages = images.isNotEmpty;
    final activeItem = hasImages && _selectedImageIndex < images.length
        ? images[_selectedImageIndex]
        : null;

    return Column(
      children: [
        // Hero Image
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: activeItem != null
                  ? _buildImageWidget(activeItem)
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sin fotos cargadas',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 14),
          // Thumbnails
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedImageIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(images[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCommerceDetails(
    String name,
    String desc,
    String currentPrice,
    String currentSku,
    List<VariantDraftFormModel> variants,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand & Category
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'TIENDA OFICIAL',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6366F1),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SKU: $currentSku',
              style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Product Title
        Text(
          name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),

        // Reviews Rating (simulated)
        const Row(
          children: [
            Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
            Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
            Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
            Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
            Icon(Icons.star_half_rounded, size: 18, color: Color(0xFFF59E0B)),
            SizedBox(width: 6),
            Text(
              '4.9 (38 opiniones)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Price
        Text(
          currentPrice,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),

        // Stock status
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'En stock · Envío express disponible',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),

        // Selector de variantes (si existen)
        if (variants.length > 1) ...[
          const Text(
            'Elige una opción:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(variants.length, (idx) {
              final isSelected = idx == _selectedVariantIndex;
              final v = variants[idx];
              final label = v.selectedAttributes.isNotEmpty
                  ? (v.selectedAttributes.first['value_name']?.toString() ?? 'Opción #${idx + 1}')
                  : 'Opción #${idx + 1}';

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedVariantIndex = idx);
                },
                selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
        ],

        // Cantidad y Botón Comprar
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    icon: const Icon(Icons.remove, size: 16),
                    splashRadius: 16,
                  ),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add, size: 16),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulación: ¡Producto añadido al carrito con éxito!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Añadir al Carrito'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text(
          'Descripción del producto',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
