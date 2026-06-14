// ─── Bottom Sheet Modal para Añadir Producto (Salida) ──────────────────────

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/screens/admin/inventory_exit_form_screen.dart'; // Importa la clase ExitItemUI
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddExitProductSheet extends StatefulWidget {
  final List<ProductModel> allProducts;
  final Map<String, List<ProductVariantModel>> variantsByProduct;
  final String warehouseId;

  const AddExitProductSheet({
    super.key,
    required this.allProducts,
    required this.variantsByProduct,
    required this.warehouseId,
  });

  @override
  State<AddExitProductSheet> createState() => _AddExitProductSheetState();
}

class _AddExitProductSheetState extends State<AddExitProductSheet> {
  final _supabase = Supabase.instance.client;

  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  Map<String, dynamic>? _selectedBatch;

  List<Map<String, dynamic>> _availableBatches = [];
  bool _loadingBatches = false;

  double _quantity = 1;

  void _onProductSelected(ProductModel? p) {
    setState(() {
      _selectedProduct = p;
      _selectedVariant = null;
      _selectedBatch = null;
      _availableBatches = [];
      _quantity = 1;

      if (p != null) {
        final vars = widget.variantsByProduct[p.id];
        if (vars != null && vars.isNotEmpty) {
          _selectedVariant = vars.first;
          _fetchBatchesForVariant(_selectedVariant!.id);
        }
      }
    });
  }

  void _onVariantSelected(ProductVariantModel? v) {
    setState(() {
      _selectedVariant = v;
      _selectedBatch = null;
      _availableBatches = [];
      _quantity = 1;
      if (v != null) {
        _fetchBatchesForVariant(v.id);
      }
    });
  }

  Future<void> _fetchBatchesForVariant(String variantId) async {
    setState(() => _loadingBatches = true);
    try {
      final resp = await _supabase
          .from('warehouse_stock_batches')
          .select()
          .eq('variant_id', variantId)
          .eq('warehouse_id', widget.warehouseId)
          .gt('available_quantity', 0) // ¡SOLO TRAE LOS QUE TIENEN STOCK!
          .order('expiry_date', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _availableBatches = List<Map<String, dynamic>>.from(resp);
          if (_availableBatches.isNotEmpty) {
            _selectedBatch = _availableBatches.first;
          }
          _loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBatches = false);
    }
  }

  double get _maxAvailable {
    if (_selectedBatch == null) return 0;
    return (_selectedBatch!['available_quantity'] as num).toDouble();
  }

  void _onSave() {
    if (_selectedProduct == null || _selectedVariant == null) return;
    if (_selectedBatch == null || _maxAvailable <= 0) {
      AppSnackbar.show(
        context,
        message: 'No hay stock disponible para retirar de esta variante.',
        type: SnackbarType.error,
      );
      return;
    }

    // Aseguramos que la cantidad no supere el stock real del lote seleccionado
    final finalQty = _quantity > _maxAvailable ? _maxAvailable : _quantity;

    // ── LÓGICA CORREGIDA DE COSTO UNITARIO (Evita nulos y ceros) ──
    final double vCost = _selectedVariant!.unitCost ?? 0.0;
    final double pCost = _selectedProduct!.unitCost;
    final double finalUnitCost = vCost > 0 ? vCost : pCost;

    final item = ExitItemUI(
      product: _selectedProduct!,
      variant: _selectedVariant!,
      selectedBatch: _selectedBatch,
      quantity: finalQty,
      unitCost: finalUnitCost,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Agregar a la Salida',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // ── PRODUCTO ──
            const Text(
              'Producto',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Autocomplete<ProductModel>(
                displayStringForOption: (p) => p.name,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<ProductModel>.empty();
                  }
                  return widget.allProducts.where(
                    (p) => p.name.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: _onProductSelected,
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
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
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
                                  _onProductSelected(null);
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
                            return ListTile(
                              leading: _ProductThumbnail(
                                imageUrl: p.primaryImageUrl,
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

            if (_selectedProduct != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Variante',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProductVariantModel>(
                    value: _selectedVariant,
                    isExpanded: true,
                    hint: const Text('Seleccione una variante'),
                    items:
                        widget.variantsByProduct[_selectedProduct!.id]?.map((
                          v,
                        ) {
                          final double varCost = v.unitCost ?? 0.0;
                          final double prodCost = _selectedProduct!.unitCost;
                          final double displayCost =
                              varCost > 0 ? varCost : prodCost;

                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v.label} (Costo: S/ ${displayCost.toStringAsFixed(2)})',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList() ??
                        [],
                    onChanged: _onVariantSelected,
                  ),
                ),
              ),
            ],

            if (_selectedVariant != null) ...[
              if (_loadingBatches)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_availableBatches.isEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'No hay stock disponible de esta variante en el almacén seleccionado.',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // ── AQUÍ SE OCULTA EL SELECTOR DE LOTE SI NO USA LOTES ──
              ] else if (_selectedProduct?.usesBatches == true) ...[
                const SizedBox(height: 16),
                const Text(
                  'Lote disponible en el Almacén',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedBatch,
                      isExpanded: true,
                      items:
                          _availableBatches.map((b) {
                            final qty = (b['available_quantity'] as num)
                                .toStringAsFixed(0);
                            return DropdownMenuItem(
                              value: b,
                              child: Text(
                                '${b['batch_number']} (Stock: $qty)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBatch = val;
                          _quantity = 1;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ],

            if (_selectedBatch != null && _maxAvailable > 0) ...[
              const SizedBox(height: 20),
              const Text(
                'Cantidad a retirar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      enabled: _quantity > 1,
                      onTap: () => setState(() => _quantity--),
                    ),
                    Expanded(
                      child: Text(
                        '${_quantity.toInt()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      enabled: _quantity < _maxAvailable,
                      onTap: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Máximo disponible: ${_maxAvailable.toInt()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  (_selectedProduct != null &&
                          _selectedVariant != null &&
                          _selectedBatch != null &&
                          _maxAvailable > 0)
                      ? _onSave
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Agregar a la lista',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child:
            imageUrl != null
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget:
                      (c, u, e) =>
                          const Icon(Icons.image_not_supported, size: 20),
                )
                : const Icon(
                  Icons.inventory_2_rounded,
                  color: AppColors.textHint,
                  size: 20,
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
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.dangerLight : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.danger : AppColors.textMuted,
          size: 22,
        ),
      ),
    );
  }
}
