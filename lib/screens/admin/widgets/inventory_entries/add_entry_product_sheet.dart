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
          // NOTA: NO filtramos por available_quantity > 0 en una orden de compra.
          // El usuario puede reabastecer un lote que ya tiene stock 0.
          .order('expiry_date', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true);


      if (mounted) {
        setState(() {
          _existingBatches =
              response
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
            _availableVariants =
                variantsData.map((v) {
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
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() => _quantity = newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
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

    String? currentImageUrl;
    if (_selectedVariant?.images.isNotEmpty == true) {
      currentImageUrl = _selectedVariant!.images.first.imageUrl;
    } else if (_selectedProduct?.images.isNotEmpty == true) {
      currentImageUrl =
          _selectedProduct!.images
              .firstWhere(
                (img) => img.isMain,
                orElse: () => _selectedProduct!.images.first,
              )
              .imageUrl;
    }

    final bool usesBatches = _selectedProduct?.usesBatches == true;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Añadir Producto',
              style: TextStyle(
                fontSize: 18,
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
                      textEditingController.text != _selectedProduct!.name) {
                    textEditingController.text = _selectedProduct!.name;
                  }
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Buscar producto...',
                      hintStyle: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textHint,
                      ),
                      suffixIcon:
                          _selectedProduct != null
                              ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: AppColors.textHint,
                                ),
                                onPressed: () {
                                  textEditingController.clear();
                                  _onProductChanged(null);
                                },
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
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 300,
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
                            return ListTile(
                              leading: _ProductThumbnail(
                                imageUrl: imgUrl,
                                size: 36,
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => onSelected(p),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Selector de variante
            if (availableVariants.isNotEmpty) ...[
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: _onVariantChanged,
              ),
              const SizedBox(height: 16),
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            labelText: 'Costo de Compra (S/)',
                            labelStyle: TextStyle(
                              color:
                                  isZeroCost
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.textSecondary,
                            ),
                            // Advertencia visual si el costo es 0
                            helperText:
                                isZeroCost
                                    ? '⚠ Verifica el costo — está en S/ 0.00'
                                    : null,
                            helperStyle: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            prefixText: 'S/ ',
                            prefixStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color:
                                    isZeroCost
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color:
                                    isZeroCost
                                        ? const Color(0xFFF59E0B)
                                        : AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color:
                                    isZeroCost
                                        ? const Color(0xFFF59E0B)
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
              const SizedBox(height: 20),

              const _FieldLabel('Cantidad'),
              const SizedBox(height: 8),
              _HorizontalStepper(
                value: _quantity,
                onAdd: () => setState(() => _quantity++),
                onRemove:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                onTapValue: _showQuantityDialog,
              ),
            ],

            const SizedBox(height: 24),

            // Lote (solo si el producto lo requiere)
            if (usesBatches) ...[
              // FIX BUG #3: _batchAutocompleteKey fuerza la reconstrucción del Autocomplete
              // cuando cambia el producto/variante, evitando que el controller interno
              // quede desincronizado con _batchCtrl tras un setState.
              Autocomplete<WarehouseStockBatchModel>(
                key: _batchAutocompleteKey,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  // FIX BUG #2: Si el campo está vacío, mostrar TODOS los lotes existentes
                  // en lugar de retornar vacío. Así el usuario ve las opciones al hacer focus.
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
                      hintText:
                          _existingBatches.isEmpty
                              ? 'Ej: LOTE-2024-001'
                              : 'Escribe o toca para ver lotes existentes...',
                      filled: true,
                      fillColor: AppColors.background,
                      prefixIcon: const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.textHint,
                      ),
                      // Indicador visual de que hay lotes disponibles
                      suffixIcon:
                          _existingBatches.isNotEmpty
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
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 220,
                          // FIX: usar el ancho disponible de la pantalla en lugar de hardcodear 300
                          maxWidth:
                              MediaQuery.of(context).size.width -
                              48, // 48 = padding horizontal del sheet
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            final dateStr =
                                option.expiryDate != null
                                    ? '${option.expiryDate!.day.toString().padLeft(2, '0')}/${option.expiryDate!.month.toString().padLeft(2, '0')}/${option.expiryDate!.year}'
                                    : 'Sin vencimiento';
                            return ListTile(
                              leading: const Icon(
                                Icons.tag,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                option.batchNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('Vence: $dateStr'),
                              trailing: Text(
                                'Stock: ${option.availableQuantity.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => onSelected(option),
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
              const SizedBox(height: 12),
              _DatePickerField(
                label: 'Fecha de Vencimiento (Opcional)',
                value: _expiryDate,
                onPick: (d) => setState(() => _expiryDate = d),
                onClear: () => setState(() => _expiryDate = null),
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Agregar a la lista',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
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
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
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
        borderRadius: BorderRadius.circular(14),
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
                onTap: onTapValue,
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
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
    return InkWell(
      onTap: () async {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value == null
                    ? label
                    : 'Vence: ${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
                style: TextStyle(
                  color:
                      value == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                  fontWeight:
                      value == null ? FontWeight.normal : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ),
          ],
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
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      splashColor: AppColors.primary.withValues(alpha: 0.18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48, // mínimo 48dp según Material Design
        height: 48,
        decoration: BoxDecoration(
          color:
              enabled
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textMuted,
          size: 22,
        ),
      ),
    );
  }
}

InputDecoration _dropdownDecoration(String label, {IconData? icon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    prefixIcon: icon != null ? Icon(icon, color: AppColors.textHint) : null,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
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
                        color: AppColors.textHint,
                      ),
                )
                : const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.textHint,
                  size: 28,
                ),
      ),
    );
  }
}
