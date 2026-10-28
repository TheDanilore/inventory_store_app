import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_common_widgets.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_formatters.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class EntryProductSearchBar extends StatefulWidget {
  final String? warehouseId;
  final bool autofocus;
  final ValueChanged<ProductModel> onProductSelected;
  final ValueChanged<ProductVariantModel?> onVariantSelected;

  const EntryProductSearchBar({
    super.key,
    this.warehouseId,
    this.autofocus = true,
    required this.onProductSelected,
    required this.onVariantSelected,
  });

  @override
  State<EntryProductSearchBar> createState() => _EntryProductSearchBarState();
}

class _EntryProductSearchBarState extends State<EntryProductSearchBar> {
  Timer? _debounceTimer;
  Completer<Iterable<ProductModel>>? _searchCompleter;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (_searchCompleter != null && !_searchCompleter!.isCompleted) {
      _searchCompleter!.complete(const Iterable<ProductModel>.empty());
    }
    super.dispose();
  }

  Future<Iterable<ProductModel>> _debouncedSearch(
    BuildContext context,
    String query,
  ) {
    _debounceTimer?.cancel();
    if (_searchCompleter != null && !_searchCompleter!.isCompleted) {
      _searchCompleter!.complete(const Iterable<ProductModel>.empty());
    }

    _searchCompleter = Completer<Iterable<ProductModel>>();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) {
        if (!_searchCompleter!.isCompleted) {
          _searchCompleter!.complete(const Iterable<ProductModel>.empty());
        }
        return;
      }
      try {
        final cubit = context.read<AddEntryProductCubit>();
        final results = await cubit.searchProducts(query);
        if (!_searchCompleter!.isCompleted) {
          _searchCompleter!.complete(results);
        }
      } catch (_) {
        if (!_searchCompleter!.isCompleted) {
          _searchCompleter!.complete(const Iterable<ProductModel>.empty());
        }
      }
    });

    return _searchCompleter!.future;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayWidth = constraints.maxWidth;
        return Autocomplete<ProductModel>(
          displayStringForOption: (p) => p.name,
          optionsBuilder: (textEditingValue) {
            final text = textEditingValue.text.trim();
            if (text.isEmpty) {
              return const Iterable<ProductModel>.empty();
            }
            return _debouncedSearch(context, text);
          },
          onSelected: widget.onProductSelected,
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
              decoration: entryInputDecoration(
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
                      if (res.variant != null) {
                        widget.onVariantSelected(
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
                          leading: EntryProductThumbnail(
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
    );
  }
}
