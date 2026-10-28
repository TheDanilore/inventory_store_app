import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/data/cache/exit_product_cache.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_sheet_helpers.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class ExitSearchSection extends StatefulWidget {
  final String warehouseId;
  final bool autofocus;
  final ProductsRepository repository;
  final ValueChanged<ProductModel> onProductSelected;
  final ValueChanged<ProductVariantModel>? onVariantSelected;

  const ExitSearchSection({
    super.key,
    required this.warehouseId,
    required this.repository,
    required this.onProductSelected,
    this.onVariantSelected,
    this.autofocus = true,
  });

  @override
  State<ExitSearchSection> createState() => _ExitSearchSectionState();
}

class _ExitSearchSectionState extends State<ExitSearchSection> {
  final _searchDebouncer = ExitDebouncer(milliseconds: 500);

  @override
  void dispose() {
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<Iterable<ProductModel>> _searchProducts(String query) async {
    final term = query.trim();
    if (term.isEmpty) return const Iterable<ProductModel>.empty();

    // Comprobar caché local LRU para respuesta instantánea (0 ms)
    final cached = ExitProductCache.instance.getSearchResults(term);
    if (cached != null) {
      return cached;
    }

    return _searchDebouncer.run<Iterable<ProductModel>>(() async {
      final res = await widget.repository.searchProductsForEntry(term);
      return res.fold(
        (l) {
          developer.log('Error de red al buscar productos', error: l.message);
          if (mounted) {
            AppSnackbar.show(
              context,
              message: 'Error de red al buscar productos. Revisa tu conexión.',
              type: SnackbarType.error,
            );
          }
          return const Iterable<ProductModel>.empty();
        },
        (r) {
          final products = r.map((p) => ProductModel.fromJson(p)).toList();
          ExitProductCache.instance.putSearchResults(term, products);
          return products;
        },
      );
    }, const Iterable<ProductModel>.empty());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExitFieldLabel('Producto'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final overlayWidth = constraints.maxWidth;
            return Autocomplete<ProductModel>(
              displayStringForOption: (p) => p.name,
              optionsBuilder:
                  (textEditingValue) => _searchProducts(textEditingValue.text),
              onSelected: (p) {
                AppFeedbackService.lightImpact();
                widget.onProductSelected(p);
              },
              fieldViewBuilder: (
                context,
                textEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  autofocus: widget.autofocus,
                  textInputAction: TextInputAction.search,
                  style: textTheme.bodyLarge,
                  decoration: exitInputDecoration(
                    hint: 'Buscar producto...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'Escanear código (QR / Barras)',
                      splashRadius: 18,
                      onPressed: () async {
                        final res = await PosCameraScannerDialog.show(
                          context,
                          warehouseId: widget.warehouseId,
                        );
                        if (res != null && mounted) {
                          widget.onProductSelected(
                            ProductModel.fromEntity(res.product),
                          );
                          if (res.variant != null &&
                              widget.onVariantSelected != null) {
                            widget.onVariantSelected!(
                              ProductVariantModel.fromEntity(res.variant!),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      surfaceTintColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.surface,
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 280,
                          maxWidth: overlayWidth,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = options.elementAt(index);
                            String? imgUrl;
                            if (p.images.isNotEmpty) {
                              imgUrl =
                                  p.images
                                      .firstWhere(
                                        (img) => img.isMain,
                                        orElse: () => p.images.first,
                                      )
                                      .imageUrl;
                            }
                            final variantCount = p.productVariants.length;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: ExitProductThumbnail(
                                imageUrl: imgUrl,
                                size: 44,
                              ),
                              title: Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle:
                                  variantCount > 1
                                      ? Text(
                                        '$variantCount variantes',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      )
                                      : null,
                              onTap: () {
                                AppFeedbackService.lightImpact();
                                onSelected(p);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const ExitSearchHint(),
      ],
    );
  }
}
