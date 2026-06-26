// ─── Bottom Sheet: Añadir Producto ───────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/warehouse_stock_batch_model.dart';
import 'package:inventory_store_app/models/entry_item_ui.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/services/admin/purchase_orders_service.dart';

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
  DateTime? _expiryDate;
  List<WarehouseStockBatchModel> _existingBatches = [];
  List<ProductVariantModel> _availableVariants = [];
  // Clave única para forzar la reconstrucción del widget Autocomplete de lotes
  // cuando cambia el producto/variante, reseteando su controller interno.
  Key _batchAutocompleteKey = UniqueKey();

  final PurchaseOrdersService _service = PurchaseOrdersService();

  Future<void> _fetchExistingBatches(String variantId) async {
    if (widget.warehouseId == null) {
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('warehouse_stock_batches')
          .select('*')
          .eq('variant_id', variantId)
          .eq('warehouse_id', widget.warehouseId!)
          .order('expiry_date', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _existingBatches = response
              .map((e) => WarehouseStockBatchModel.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[Batches] Error al obtener lotes: $e');
    }
  }

  @override
  void dispose() {
    _costCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  /// Devuelve el costo unitario efectivo: primero el de la variante
  /// (si es > 0), luego el del producto como fallback.
  double _effectiveCost({ProductVariantModel? variant, ProductModel? product}) {
    final variantCost = variant?.unitCost ?? 0;
    if (variantCost > 0) return variantCost;
    return product?.unitCost ?? 0;
  }

  Future<void> _onProductChanged(ProductModel? val) async {
    setState(() {
      _selectedProduct = val;
      _selectedVariant = null;
      _quantity = 1;
      _batchCtrl.clear();
      _expiryDate = null;
      _existingBatches = [];
      _availableVariants = [];
      // Resetear el Autocomplete de lotes al cambiar de producto
      _batchAutocompleteKey = UniqueKey();
      if (val != null) {
        _costCtrl.text = val.unitCost.toStringAsFixed(2);
      } else {
        _costCtrl.clear();
      }
    });

    if (val != null) {
      try {
        final variantsData = await _service.getProductVariants(val.id);
        if (mounted) {
          setState(() {
            _availableVariants = variantsData.map((v) {
              if (v['variant_attribute_values'] is List) {
                final Map<String, dynamic> flatAttributes = {};
                for (final vav in v['variant_attribute_values'] as List) {
                  if (vav is Map && vav['attribute_values'] is Map) {
                    final av = vav['attribute_values'] as Map;
                    if (av['attributes'] is Map) {
                      final attr = av['attributes'] as Map;
                      if (attr['name'] != null) {
                        flatAttributes[attr['name'].toString()] =
                            av['value']?.toString() ?? '';
                      }
                    }
                  }
                }
                v['attributes'] = flatAttributes;
              }
              return ProductVariantModel.fromJson(v);
            }).toList();
          });

          // FIX BUG #1: Si el producto NO tiene variantes extras (variante única/default),
          // el DropdownButtonFormField no se muestra y _onVariantChanged nunca se llama.
          // En ese caso, tomamos el id de la única variante disponible y cargamos los lotes.
          if (_availableVariants.length == 1 && val.usesBatches) {
            await _fetchExistingBatches(_availableVariants.first.id);
          }
        }
      } catch (e) {
        debugPrint('Error fetching variants: $e');
      }
    }
  }

  void _onVariantChanged(ProductVariantModel? val) {
    setState(() {
      _selectedVariant = val;
      final cost = _effectiveCost(variant: val, product: _selectedProduct);
      _costCtrl.text = cost.toStringAsFixed(2);
      // Resetear lotes y campo al cambiar de variante
      _existingBatches = [];
      _batchCtrl.clear();
      _batchAutocompleteKey = UniqueKey();
    });

    if (val != null && _selectedProduct?.usesBatches == true) {
      _fetchExistingBatches(val.id);
    }
  }

  Future<void> _showQuantityDialog() async {
    final qtyCtrl = TextEditingController(text: _quantity.toStringAsFixed(0));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  void _submit() {
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    final availableVariants = _availableVariants;

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
    if (cost < 0) {
      AppSnackbar.show(
        context,
        message: 'El costo no puede ser negativo',
        type: SnackbarType.error,
      );
      return;
    }
    if (availableVariants.isNotEmpty && _selectedVariant == null) {
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

    final variantToUse = _selectedVariant ??
        ProductVariantModel(
          id: '',
          productId: _selectedProduct!.id,
          sku: null,
          salePrice: null,
        );

    Navigator.pop(
      context,
      EntryItemUI(
        product: _selectedProduct!,
        variant: variantToUse,
        quantity: _quantity,
        unitCost: cost,
        batchNumber: usesBatches ? _batchCtrl.text.trim() : 'DEFAULT',
        expiryDate: usesBatches ? _expiryDate : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableVariants = _availableVariants;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final mediaQuery = MediaQuery.of(context);

    // Calcular el ancho del Autocomplete para que coincida con el espacio disponible
    double overlayWidth = mediaQuery.size.width - 48; // 24 padding por lado
    if (overlayWidth > 492) {
      overlayWidth = 492; // Max width de 540 - 48
    }

    String? currentImageUrl;
    if (_selectedVariant?.images.isNotEmpty == true) {
      currentImageUrl = _selectedVariant!.images.first.imageUrl;
    } else if (_selectedProduct?.images.isNotEmpty == true) {
      currentImageUrl = _selectedProduct!.images
          .firstWhere(
            (img) => img.isMain,
            orElse: () => _selectedProduct!.images.first,
          )
          .imageUrl;
    }

    final bool usesBatches = _selectedProduct?.usesBatches == true;

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                        try {
                          final res = await _service.searchProducts(
                            textEditingValue.text,
                          );
                          return res.map((p) => ProductModel.fromJson(p));
                        } catch (e) {
                          debugPrint('Error en autocomplete: $e');
                          return const Iterable<ProductModel>.empty();
                        }
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
                          textEditingController.text = _selectedProduct!.name;
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
                            suffixIcon: _selectedProduct != null
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
                            shadowColor: Colors.black.withValues(alpha: 0.1),
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
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final p = options.elementAt(index);
                                  String? imgUrl;
                                  if (p.images.isNotEmpty) {
                                    imgUrl = p.images
                                        .firstWhere(
                                          (img) => img.isMain,
                                          orElse: () => p.images.first,
                                        )
                                        .imageUrl;
                                  }
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    leading: _ProductThumbnail(
                                      imageUrl: imgUrl,
                                      size: 40,
                                    ),
                                    title: Text(
                                      p.name,
                                      style: textTheme.bodyMedium?.copyWith(
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

                  // Selector de variante
                  if (availableVariants.isNotEmpty) ...[
                    DropdownButtonFormField<ProductVariantModel>(
                      initialValue: _selectedVariant,
                      isExpanded: true,
                      icon: const Icon(Icons.expand_more_rounded),
                      decoration: _dropdownDecoration(
                        'Selecciona la Variante (Obligatorio)',
                      ),
                      items: availableVariants
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
                        _ProductThumbnail(imageUrl: currentImageUrl, size: 64),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final cost =
                                  double.tryParse(_costCtrl.text.trim()) ?? 0.0;
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
                                  labelStyle: textTheme.bodyMedium?.copyWith(
                                    color: isZeroCost
                                        ? AppColors.warning
                                        : AppColors.textSecondary,
                                  ),
                                  helperText: isZeroCost
                                      ? '⚠ Verifica el costo — está en S/ 0.00'
                                      : null,
                                  helperStyle: textTheme.bodySmall?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  prefixText: 'S/ ',
                                  prefixStyle: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: isZeroCost
                                          ? AppColors.warning
                                          : AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: isZeroCost
                                          ? AppColors.warning
                                          : AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: isZeroCost
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
                      onRemove: _quantity > 1
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
                    Autocomplete<WarehouseStockBatchModel>(
                      key: _batchAutocompleteKey,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _existingBatches;
                        }
                        return _existingBatches.where(
                          (option) => option.batchNumber.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      displayStringForOption: (option) => option.batchNumber,
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          onChanged: (value) => _batchCtrl.text = value,
                          decoration: InputDecoration(
                            labelText: 'Nº de Lote (Obligatorio)',
                            labelStyle: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            hintText: _existingBatches.isEmpty
                                ? 'Ej: LOTE-2024-001'
                                : 'Escribe o toca para ver lotes existentes...',
                            filled: true,
                            fillColor: AppColors.background,
                            prefixIcon: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.textMuted,
                            ),
                            suffixIcon: _existingBatches.isNotEmpty
                                ? Tooltip(
                                    message:
                                        '${_existingBatches.length} lote(s) existente(s) en este almacén',
                                    child: Icon(
                                      Icons.layers_rounded,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 20,
                                    ),
                                  )
                                : null,
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
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8.0,
                            shadowColor: Colors.black.withValues(alpha: 0.1),
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
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  final dateStr = option.expiryDate != null
                                      ? '${option.expiryDate!.day.toString().padLeft(2, '0')}/${option.expiryDate!.month.toString().padLeft(2, '0')}/${option.expiryDate!.year}'
                                      : 'Sin vencimiento';
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.tag,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      option.batchNumber,
                                      style: textTheme.bodyMedium?.copyWith(
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
                                          style: textTheme.labelSmall?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        Text(
                                          option.availableQuantity
                                              .toStringAsFixed(0),
                                          style:
                                              textTheme.titleSmall?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
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
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _submit();
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
                    transitionBuilder: (child, animation) => ScaleTransition(
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    color: value == null
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
            color: enabled
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
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 1.5,
      ),
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
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
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
