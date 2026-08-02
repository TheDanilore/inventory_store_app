import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_state.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'dart:developer' as developer;

class AddEntryProductSheet extends StatefulWidget {
  final String? warehouseId;

  const AddEntryProductSheet({super.key, this.warehouseId});

  @override
  State<AddEntryProductSheet> createState() => _AddEntryProductSheetState();
}

class _AddEntryProductSheetState extends State<AddEntryProductSheet> {
  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  double _quantity = 1;
  final _costCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _batchSearchCtrl = TextEditingController(); // Controlador extraído para no forzar rebuilds de Autocomplete
  DateTime? _expiryDate;
  
  final _searchDebouncer = _Debouncer(milliseconds: 500);

  late final AddEntryProductCubit _cubit;
  late final ProductsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = GetIt.I<ProductsRepository>();
    _cubit = AddEntryProductCubit(_repository);
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _costCtrl.dispose();
    _batchCtrl.dispose();
    _batchSearchCtrl.dispose();
    _cubit.close();
    super.dispose();
  }

  /// Devuelve el costo unitario efectivo: primero el de la variante
  /// (si es > 0), luego el del producto como fallback.
  double _effectiveCost({ProductVariantModel? variant, ProductModel? product}) {
    final variantCost = variant?.unitCost ?? 0;
    if (variantCost > 0) return variantCost;
    return product?.defaultVariant?.unitCost ?? 0;
  }

  Future<void> _onProductChanged(ProductModel? val) async {
    setState(() {
      _selectedProduct = val;
      _selectedVariant = null;
      _quantity = 1;
      _batchCtrl.clear();
      _batchSearchCtrl.clear();
      _expiryDate = null;
      if (val != null) {
        _costCtrl.text = (val.defaultVariant?.unitCost ?? 0).toStringAsFixed(2);
      } else {
        _costCtrl.clear();
      }
    });

    if (val != null) {
      _cubit.loadVariantsAndBatches(
        val.id,
        val.usesBatches,
        widget.warehouseId,
      );
    }
  }

  void _onVariantChanged(ProductVariantModel? val) {
    setState(() {
      _selectedVariant = val;
      final cost = _effectiveCost(variant: val, product: _selectedProduct);
      _costCtrl.text = cost.toStringAsFixed(2);
      _batchCtrl.clear();
      _batchSearchCtrl.clear();
    });

    if (val != null &&
        _selectedProduct?.usesBatches == true &&
        widget.warehouseId != null) {
      _cubit.loadBatches(val.id, widget.warehouseId!);
    }
  }

  Future<void> _showQuantityDialog() async {
    final qtyCtrl = TextEditingController(text: _quantity.toStringAsFixed(0));
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() => _quantity = newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
    qtyCtrl.dispose();
  }

  void _submit(AddEntryProductState state) {
    final sanitizedCost = _costCtrl.text.trim().replaceAll(',', '.');
    final cost = double.tryParse(sanitizedCost);
    final availableVariants = state.availableVariants;

    if (_selectedProduct == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un producto',
        type: SnackbarType.error,
      );
      return;
    }
    if (_quantity <= 0) {
      AppSnackbar.show(
        context,
        message: 'La cantidad debe ser mayor a 0',
        type: SnackbarType.error,
      );
      return;
    }
    if (cost == null || cost < 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un costo válido (positivo)',
        type: SnackbarType.error,
      );
      return;
    }
    if (availableVariants.length > 1 && _selectedVariant == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona una variante obligatoriamente',
        type: SnackbarType.warning,
      );
      return;
    }

    final bool usesBatches = _selectedProduct?.usesBatches == true;
    if (usesBatches && _batchCtrl.text.trim().isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El número de lote es obligatorio para este producto.',
        type: SnackbarType.error,
      );
      return;
    }

    final variantToUse =
        _selectedVariant ??
        ProductVariantModel(
          id: '',
          productId: _selectedProduct!.id,
          sku: null,
          salePrice: null,
        );

    Navigator.pop(
      context,
      InventoryEntryItemEntity(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        variantId: variantToUse.id,
        variantLabel: _selectedVariant?.label ?? 'Variante Única',
        imageUrl: _resolveCurrentImageUrl(),
        usesBatches: usesBatches,
        quantity: _quantity,
        unitCost: cost,
        batchNumber: usesBatches ? _batchCtrl.text.trim() : 'DEFAULT',
        expiryDate: usesBatches ? _expiryDate : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<AddEntryProductCubit, AddEntryProductState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            AppSnackbar.show(context, message: state.errorMessage!, type: SnackbarType.error);
          }
        },
        builder: (context, state) {
          final availableVariants = state.availableVariants;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final mediaQuery = MediaQuery.of(context);

          // Calcular el ancho del Autocomplete para que coincida con el espacio disponible
          double overlayWidth =
              mediaQuery.size.width - 48; // 24 padding por lado
          if (overlayWidth > 492) {
            overlayWidth = 492; // Max width de 540 - 48
          }

          final bool usesBatches = _selectedProduct?.usesBatches == true;
          final currentImageUrl = _resolveCurrentImageUrl();

          return SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    mediaQuery.viewInsets.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 14),
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        Text(
                          'Añadir Producto',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // ── BUSCADOR DE PRODUCTO (AUTOCOMPLETE) ──
                        const _FieldLabel('Producto'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Autocomplete<ProductModel>(
                            displayStringForOption: (p) => p.name,
                            optionsBuilder: (textEditingValue) async {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<ProductModel>.empty();
                              }
                              return _searchDebouncer.run<Iterable<ProductModel>>(() async {
                                final res = await _repository.searchProductsForEntry(
                                  textEditingValue.text,
                                );
                                return res.fold(
                                  (l) {
                                    developer.log('Error de red al buscar', error: l.message);
                                    if (mounted) {
                                      AppSnackbar.show(
                                        context,
                                        message: 'Error de red al buscar productos. Revisa tu conexión.',
                                        type: SnackbarType.error,
                                      );
                                    }
                                    return const Iterable<ProductModel>.empty();
                                  },
                                  (r) => r.map((p) => ProductModel.fromJson(p)),
                                );
                              }, const Iterable<ProductModel>.empty());
                            },
                            onSelected: _onProductChanged,
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (_selectedProduct != null &&
                                  textEditingController.text !=
                                      _selectedProduct!.name) {
                                textEditingController.text =
                                    _selectedProduct!.name;
                              }
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Buscar producto...',
                                  hintStyle: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: AppColors.textMuted,
                                  ),
                                  suffixIcon:
                                      _selectedProduct != null
                                          ? GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              textEditingController.clear();
                                              _onProductChanged(null);
                                            },
                                            behavior: HitTestBehavior.opaque,
                                            child: const SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: Icon(
                                                Icons.clear_rounded,
                                                size: 20,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          )
                                          : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  shadowColor: Colors.black.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: colorScheme.surface,
                                  clipBehavior: Clip.antiAlias,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: 250,
                                      maxWidth: overlayWidth,
                                    ),
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      separatorBuilder:
                                          (_, _) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final p = options.elementAt(index);
                                        String? imgUrl;
                                        if (p.images.isNotEmpty) {
                                          imgUrl =
                                              p.images
                                                  .firstWhere(
                                                    (img) => img.isMain,
                                                    orElse:
                                                        () => p.images.first,
                                                  )
                                                  .imageUrl;
                                        }
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 4,
                                              ),
                                          leading: _ProductThumbnail(
                                            imageUrl: imgUrl,
                                            size: 40,
                                          ),
                                          title: Text(
                                            p.name,
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            onSelected(p);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Selector de variante (solo si tiene 2 o más variantes)
                        if (state.isLoadingVariants) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ] else if (availableVariants.length > 1) ...[
                          DropdownButtonFormField<ProductVariantModel>(
                            initialValue: _selectedVariant,
                            isExpanded: true,
                            icon: const Icon(Icons.expand_more_rounded),
                            decoration: _dropdownDecoration(
                              'Selecciona la Variante (Obligatorio)',
                            ),
                            items:
                                availableVariants
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                          v.label,
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              _onVariantChanged(val);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (_selectedProduct != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _ProductThumbnail(
                                imageUrl: currentImageUrl,
                                size: 64,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final cost =
                                        double.tryParse(
                                          _costCtrl.text.trim(),
                                        ) ??
                                        0.0;
                                    final isZeroCost = cost == 0.0;
                                    return TextField(
                                      controller: _costCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}'),
                                        ),
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Costo de Compra (S/)',
                                        labelStyle: textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  isZeroCost
                                                      ? AppColors.warning
                                                      : AppColors.textSecondary,
                                            ),
                                        helperText:
                                            isZeroCost
                                                ? '⚠ Verifica el costo — está en S/ 0.00'
                                                : null,
                                        helperStyle: textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.warning,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        filled: true,
                                        fillColor: AppColors.background,
                                        prefixText: 'S/ ',
                                        prefixStyle: textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                isZeroCost
                                                    ? AppColors.warning
                                                    : AppColors.border,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                isZeroCost
                                                    ? AppColors.warning
                                                    : AppColors.border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide(
                                            color:
                                                isZeroCost
                                                    ? AppColors.warning
                                                    : AppColors.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          const _FieldLabel('Cantidad'),
                          const SizedBox(height: 8),
                          _HorizontalStepper(
                            value: _quantity,
                            onAdd: () {
                              HapticFeedback.lightImpact();
                              setState(() => _quantity++);
                            },
                            onRemove:
                                _quantity > 1
                                    ? () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _quantity--);
                                    }
                                    : null,
                            onTapValue: _showQuantityDialog,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Lote (solo si el producto lo requiere)
                        if (usesBatches) ...[
                          if (state.isLoadingBatches)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            Autocomplete<WarehouseStockBatchModel>(
                              optionsBuilder: (
                                TextEditingValue textEditingValue,
                              ) {
                                final batches =
                                    state.availableBatches
                                        .map(
                                          (e) =>
                                              WarehouseStockBatchModel.fromJson(
                                                e,
                                              ),
                                        )
                                        .toList();
                                if (textEditingValue.text.isEmpty) {
                                  return batches;
                                }
                                return batches.where(
                                  (option) =>
                                      option.batchNumber.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                );
                              },
                              displayStringForOption:
                                  (option) => option.batchNumber,
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                if (textEditingController != _batchSearchCtrl) {
                                   textEditingController.text = _batchSearchCtrl.text;
                                   textEditingController.addListener(() {
                                     _batchSearchCtrl.text = textEditingController.text;
                                     _batchCtrl.text = textEditingController.text;
                                   });
                                }
                                
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  onChanged: (value) => _batchCtrl.text = value,
                                  decoration: InputDecoration(
                                    labelText: 'Nº de Lote (Obligatorio)',
                                    labelStyle: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    hintText:
                                        state.availableBatches.isEmpty
                                            ? 'Ej: LOTE-2024-001'
                                            : 'Escribe o toca para ver lotes existentes...',
                                    filled: true,
                                    fillColor: AppColors.background,
                                    prefixIcon: const Icon(
                                      Icons.qr_code_scanner,
                                      color: AppColors.textMuted,
                                    ),
                                    suffixIcon:
                                        state.availableBatches.isNotEmpty
                                            ? Tooltip(
                                              message:
                                                  '${state.availableBatches.length} lote(s) existente(s) en este almacén',
                                              child: Icon(
                                                Icons.layers_rounded,
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.7),
                                                size: 20,
                                              ),
                                            )
                                            : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              optionsViewBuilder: (
                                context,
                                onSelected,
                                options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 8.0,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    color: colorScheme.surface,
                                    clipBehavior: Clip.antiAlias,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 260,
                                        maxWidth: overlayWidth,
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder:
                                            (_, _) => const Divider(height: 1),
                                        itemBuilder: (
                                          BuildContext context,
                                          int index,
                                        ) {
                                          final option = options.elementAt(
                                            index,
                                          );
                                          final dateStr =
                                              option.expiryDate != null
                                                  ? '${option.expiryDate!.day.toString().padLeft(2, '0')}/${option.expiryDate!.month.toString().padLeft(2, '0')}/${option.expiryDate!.year}'
                                                  : 'Sin vencimiento';
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                            leading: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.tag,
                                                color: AppColors.primary,
                                                size: 20,
                                              ),
                                            ),
                                            title: Text(
                                              option.batchNumber,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            subtitle: Text(
                                              'Vence: $dateStr',
                                              style: textTheme.bodySmall,
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Stock',
                                                  style: textTheme.labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                ),
                                                Text(
                                                  option.availableQuantity
                                                      .toStringAsFixed(0),
                                                  style: textTheme.titleSmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              onSelected(option);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onSelected: (WarehouseStockBatchModel selection) {
                                setState(() {
                                  _batchCtrl.text = selection.batchNumber;
                                  _expiryDate = selection.expiryDate;
                                });
                              },
                            ),
                          const SizedBox(height: 16),
                          _DatePickerField(
                            label: 'Fecha de Vencimiento (Opcional)',
                            value: _expiryDate,
                            onPick: (d) => setState(() => _expiryDate = d),
                            onClear: () {
                              HapticFeedback.lightImpact();
                              setState(() => _expiryDate = null);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                state.isLoadingVariants ||
                                        state.isLoadingBatches
                                    ? null
                                    : () {
                                      HapticFeedback.mediumImpact();
                                      _submit(state);
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Agregar a la lista',
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _resolveCurrentImageUrl() {
    if (_selectedVariant?.images.isNotEmpty == true) {
      return _selectedVariant!.images.first.imageUrl;
    }
    if (_selectedProduct?.images.isNotEmpty == true) {
      return _selectedProduct!.images
          .firstWhere(
            (img) => img.isMain,
            orElse: () => _selectedProduct!.images.first,
          )
          .imageUrl;
    }
    return null;
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    ),
  );
}

class _HorizontalStepper extends StatelessWidget {
  final double value;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback onTapValue;
  const _HorizontalStepper({
    required this.value,
    required this.onAdd,
    this.onRemove,
    required this.onTapValue,
  });

  /// Muestra la cantidad con decimales solo si no es entera.
  String get _displayValue =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Disminuir cantidad',
            button: true,
            child: _QtyButton(
              icon: Icons.remove_rounded,
              enabled: onRemove != null,
              onTap: onRemove ?? () {},
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTapValue();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  // AnimatedSwitcher con curva elástica para feedback visual al cambiar valor
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder:
                        (child, animation) => ScaleTransition(
                          scale: CurvedAnimation(
                            parent: animation,
                            curve: Curves.elasticOut,
                          ),
                          child: child,
                        ),
                    child: Text(
                      _displayValue,
                      key: ValueKey(_displayValue),
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: 'Aumentar cantidad',
            button: true,
            child: _QtyButton(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onClear;
  const _DatePickerField({
    required this.label,
    this.value,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          HapticFeedback.lightImpact();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            helpText: 'Fecha de Vencimiento',
          );
          if (picked != null) onPick(picked);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: value != null ? 0 : 16,
            top: 10,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value == null
                      ? label
                      : 'Vence: ${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                  style: textTheme.bodyMedium?.copyWith(
                    color:
                        value == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                    fontWeight:
                        value == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withValues(alpha: 0.18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48, // mínimo 48dp según Material Design
          height: 48,
          decoration: BoxDecoration(
            color:
                enabled
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.primary : AppColors.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}

InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

class _ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _ProductThumbnail({this.imageUrl, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child:
            imageUrl != null
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textMuted,
                      ),
                )
                : const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.textMuted,
                  size: 28,
                ),
      ),
    );
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  Completer? _completer;
  
  _Debouncer({required this.milliseconds});
  
  Future<T> run<T>(Future<T> Function() action, T fallbackValue) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _completer?.complete(fallbackValue);
    }
    
    _completer = Completer<T>();
    _timer = Timer(Duration(milliseconds: milliseconds), () async {
      try {
        final result = await action();
        if (!_completer!.isCompleted) _completer!.complete(result);
      } catch (e, st) {
        developer.log('Debouncer error', error: e, stackTrace: st);
        if (!_completer!.isCompleted) _completer!.complete(fallbackValue);
      }
    });
    
    return _completer!.future as Future<T>;
  }
  
  void dispose() {
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
       _completer!.completeError('disposed');
    }
  }
}
