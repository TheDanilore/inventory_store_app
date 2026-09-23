import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

class ProductVariantMatrix extends StatefulWidget {
  final List<ProductVariantEntity> variants;
  final String? selectedVariantId;
  final String? fallbackImageUrl;
  final String? Function(ProductVariantEntity) variantImageUrl;
  final ValueChanged<ProductVariantEntity> onVariantSelected;
  final VoidCallback? onOpenSelectorModal;
  final bool isDesktop;
  final int Function(String variantId)? variantStock;

  const ProductVariantMatrix({
    super.key,
    required this.variants,
    required this.selectedVariantId,
    required this.fallbackImageUrl,
    required this.variantImageUrl,
    required this.onVariantSelected,
    this.onOpenSelectorModal,
    this.isDesktop = true,
    this.variantStock,
  });

  @override
  State<ProductVariantMatrix> createState() => _ProductVariantMatrixState();
}

class _ProductVariantMatrixState extends State<ProductVariantMatrix> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ProductVariantEntity> get _filteredVariants {
    if (_searchQuery.trim().isEmpty) return widget.variants;
    final q = _searchQuery.trim().toLowerCase();
    return widget.variants.where((v) {
      final labelMatches = v.label.toLowerCase().contains(q);
      final skuMatches = v.sku?.toLowerCase().contains(q) ?? false;
      return labelMatches || skuMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variants.isEmpty) return const SizedBox.shrink();

    if (widget.isDesktop) {
      return _buildDesktopMatrix(context);
    }
    return _buildMobileChips(context);
  }

  Widget _buildDesktopMatrix(BuildContext context) {
    final filtered = _filteredVariants;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.view_in_ar_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Matriz de Variantes y Presentaciones',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _searchQuery.isEmpty
                            ? '${widget.variants.length} disponibles'
                            : '${filtered.length} de ${widget.variants.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.variants.length > 5 &&
                    widget.onOpenSelectorModal != null)
                  TextButton.icon(
                    onPressed: widget.onOpenSelectorModal,
                    icon: const Icon(Icons.fullscreen_rounded, size: 16),
                    label: const Text(
                      'Expandir Matriz',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Inline Quick Search Field if >= 4 variants
          if (widget.variants.length >= 4) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                height: 34,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Filtrar por modelo, presentación o SKU...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                            : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: AppColors.divider),

          // Matrix Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'PRESENTACIÓN / ATRIBUTO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'SKU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STOCK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'P. VENTA',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'P. MAYOREO',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 44),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Variants List Rows with Height Constraints to prevent asymmetric layout
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 28,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay variantes que coincidan con "$_searchQuery"',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: filtered.length > 5,
                child: ListView.separated(
                  controller: _scrollController,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder:
                      (context, index) =>
                          const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final v = filtered[index];
                    final isSelected = v.id == widget.selectedVariantId;
                    final imgUrl =
                        widget.variantImageUrl(v) ?? widget.fallbackImageUrl;

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () => widget.onVariantSelected(v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color:
                              isSelected
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : Colors.white,
                          child: Row(
                            children: [
                              // Presentation / Label with avatar
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child:
                                          imgUrl != null && imgUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                imageUrl: imgUrl,
                                                width: 34,
                                                height: 34,
                                                fit: BoxFit.cover,
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Container(
                                                          width: 34,
                                                          height: 34,
                                                          color:
                                                              AppColors
                                                                  .background,
                                                          child: const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            size: 14,
                                                            color:
                                                                AppColors
                                                                    .textMuted,
                                                          ),
                                                        ),
                                              )
                                              : Container(
                                                width: 34,
                                                height: 34,
                                                color: AppColors.background,
                                                child: const Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 14,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        v.label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                          color:
                                              isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // SKU
                              Expanded(
                                flex: 3,
                                child: Text(
                                  v.sku ?? '—',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),

                              // Stock Badge
                              Expanded(
                                flex: 2,
                                child:
                                    widget.variantStock != null
                                        ? Align(
                                          alignment: Alignment.centerLeft,
                                          child: _buildStockPill(
                                            widget.variantStock!(v.id),
                                          ),
                                        )
                                        : const Text(
                                          '—',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                              ),

                              // Sale Price
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'S/ ${(v.salePrice ?? 0.0).toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),

                              // Wholesale Price
                              Expanded(
                                flex: 3,
                                child: Text(
                                  v.wholesalePrice != null
                                      ? 'S/ ${v.wholesalePrice!.toStringAsFixed(2)}'
                                      : '—',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),

                              // Select indicator
                              SizedBox(
                                width: 44,
                                child: Center(
                                  child:
                                      isSelected
                                          ? Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.border,
                                                width: 1.5,
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
            ),
        ],
      ),
    );
  }

  Widget _buildStockPill(int stock) {
    if (stock > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Text(
          '$stock unds',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.successDark,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.slateLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Agotado',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildMobileChips(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Presentaciones y Variantes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.onOpenSelectorModal != null)
              GestureDetector(
                onTap: widget.onOpenSelectorModal,
                child: const Text(
                  'Ver todas >',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children:
                widget.variants.map((v) {
                  final isSelected = v.id == widget.selectedVariantId;
                  final imgUrl =
                      widget.variantImageUrl(v) ?? widget.fallbackImageUrl;
                  final stock = widget.variantStock?.call(v.id);

                  return GestureDetector(
                    onTap: () => widget.onVariantSelected(v),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (imgUrl != null && imgUrl.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: imgUrl,
                                width: 26,
                                height: 26,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                v.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'S/ ${(v.salePrice ?? 0.0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (stock != null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      stock > 0 ? '· $stock unds' : '· Agotado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            stock > 0
                                                ? AppColors.successDark
                                                : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}
