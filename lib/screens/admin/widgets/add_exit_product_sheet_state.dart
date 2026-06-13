// ─── Bottom Sheet Modal para Añadir Producto (Salida) ──────────────────────

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/screens/admin/inventory_exit_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class AddExitProductSheet extends StatefulWidget {
  final List<ProductModel> allProducts;
  final Map<String, List<ProductVariantModel>> variantsByProduct;
  final Map<String, List<Map<String, dynamic>>> warehouseStock;

  const AddExitProductSheet({
    super.key,
    required this.allProducts,
    required this.variantsByProduct,
    required this.warehouseStock,
  });

  @override
  State<AddExitProductSheet> createState() => _AddExitProductSheetState();
}

class _AddExitProductSheetState extends State<AddExitProductSheet> {
  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  Map<String, dynamic>? _selectedBatch; // Para productos con gestión de lotes
  double _quantity = 1;

  /// Costo efectivo: usa el de la variante si > 0, si no el del producto.
  double _effectiveCost({ProductVariantModel? variant, ProductModel? product}) {
    final variantCost = variant?.unitCost ?? 0;
    if (variantCost > 0) return variantCost;
    return product?.unitCost ?? 0;
  }

  void _onProductChanged(ProductModel? val) {
    setState(() {
      _selectedProduct = val;
      _selectedVariant = null;
      _selectedBatch = null;
      _quantity = 1;
    });
  }

  void _onVariantChanged(ProductVariantModel? val) {
    setState(() {
      _selectedVariant = val;
      _selectedBatch = null;
      _quantity = 1;
    });
  }

  double get _maxStock {
    final variantId = _selectedVariant?.id ?? '';
    final batches = widget.warehouseStock[variantId] ?? [];

    if (_selectedProduct?.usesBatches == true) {
      return (_selectedBatch?['available_quantity'] as num?)?.toDouble() ?? 0.0;
    } else {
      return batches.fold(
        0.0,
        (sum, b) =>
            sum + ((b['available_quantity'] as num?)?.toDouble() ?? 0.0),
      );
    }
  }

  Future<void> _mostrarDialogoCantidadModal() async {
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
                helperText: 'Stock máximo: $_maxStock',
                helperStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
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
                    setState(() {
                      _quantity = newQty > _maxStock ? _maxStock : newQty;
                    });
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
    final availableVariants =
        _selectedProduct == null
            ? const <ProductVariantModel>[]
            : (widget.variantsByProduct[_selectedProduct!.id] ?? []);

    if (_selectedProduct == null || _quantity <= 0) {
      AppSnackbar.show(
        context,
        message: 'Revisa los datos ingresados',
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
    if (usesBatches && _selectedBatch == null) {
      AppSnackbar.show(
        context,
        message:
            'Este producto gestiona lotes. Selecciona un lote para retirar.',
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

    if (_quantity > _maxStock) {
      AppSnackbar.show(
        context,
        message: 'No puedes retirar más del stock disponible',
        type: SnackbarType.error,
      );
      return;
    }

    final newItem = ExitItemUI(
      product: _selectedProduct!,
      variant: variantToUse,
      selectedBatch: usesBatches ? _selectedBatch : null,
      quantity: _quantity,
      unitCost: _effectiveCost(
        variant: _selectedVariant,
        product: _selectedProduct,
      ),
    );

    Navigator.pop(context, newItem);
  }

  @override
  Widget build(BuildContext context) {
    final availableVariants =
        _selectedProduct == null
            ? const <ProductVariantModel>[]
            : (widget.variantsByProduct[_selectedProduct!.id] ?? []);

    // Obtenemos los lotes para la variante seleccionada (o vacío si no usa variantes)
    final String variantKey = _selectedVariant?.id ?? '';
    final List<Map<String, dynamic>> availableBatches =
        _selectedProduct != null
            ? (widget.warehouseStock[variantKey] ?? [])
            : [];

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
              'Añadir Salida',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<ProductModel>(
              initialValue: _selectedProduct,
              isExpanded: true,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: InputDecoration(
                labelText: 'Selecciona el Producto',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
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
              ),
              items:
                  widget.allProducts
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: _onProductChanged,
            ),
            const SizedBox(height: 16),

            if (availableVariants.isNotEmpty) ...[
              DropdownButtonFormField<ProductVariantModel>(
                initialValue: _selectedVariant,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: InputDecoration(
                  labelText: 'Selecciona la Variante',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
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
                ),
                items:
                    availableVariants
                        .map(
                          (variant) => DropdownMenuItem(
                            value: variant,
                            child: Text(
                              variant.label,
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

            // ─── NUEVO: SELECTOR DE LOTES (Obligatorio si usa lotes) ───
            if (_selectedProduct?.usesBatches == true &&
                (_selectedVariant != null || availableVariants.isEmpty)) ...[
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: _selectedBatch,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: InputDecoration(
                  labelText: 'Selecciona el Lote de donde se retirará',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.blue,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items:
                    availableBatches.map((b) {
                      final String batchNum = b['batch_number'] ?? 'N/A';
                      final String? expStr = b['expiry_date'];
                      final int qty = (b['available_quantity'] as num).toInt();

                      String label = 'Lote: $batchNum | Stock: $qty';
                      if (expStr != null) {
                        final exp = DateTime.parse(expStr);
                        label +=
                            ' | Vence: ${exp.day}/${exp.month}/${exp.year}';
                      }

                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: b,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
              const SizedBox(height: 16),
            ],

            if (_selectedProduct != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child:
                          currentImageUrl != null
                              ? CachedNetworkImage(
                                imageUrl: currentImageUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) => const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (_, __, ___) => const Icon(
                                      Icons.image_not_supported_rounded,
                                      color: AppColors.textHint,
                                    ),
                              )
                              : const Icon(
                                Icons.image_not_supported_rounded,
                                color: AppColors.textHint,
                              ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            if (availableVariants.isNotEmpty &&
                                _selectedVariant == null) {
                              return _InfoBadge(
                                text: 'Selecciona una variante',
                                isWarning: true,
                              );
                            }
                            if (_selectedProduct?.usesBatches == true &&
                                _selectedBatch == null) {
                              return _InfoBadge(
                                text: 'Selecciona un lote',
                                isWarning: true,
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _maxStock > 0
                                        ? AppColors.success.withValues(
                                          alpha: 0.1,
                                        )
                                        : AppColors.danger.withValues(
                                          alpha: 0.1,
                                        ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      _maxStock > 0
                                          ? AppColors.success.withValues(
                                            alpha: 0.3,
                                          )
                                          : AppColors.danger.withValues(
                                            alpha: 0.3,
                                          ),
                                ),
                              ),
                              child: Text(
                                _maxStock > 0
                                    ? '$_maxStock unidades'
                                    : 'Agotado en este almacén',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      _maxStock > 0
                                          ? AppColors.success
                                          : AppColors.danger,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Cantidad a Retirar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap:
                              _maxStock > 0
                                  ? _mostrarDialogoCantidadModal
                                  : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '$_quantity',
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
                    _QtyButton(
                      icon: Icons.add_rounded,
                      enabled: _quantity < _maxStock,
                      onTap: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (_selectedProduct != null &&
                            (_selectedVariant != null ||
                                availableVariants.isEmpty) &&
                            (!(_selectedProduct?.usesBatches == true) ||
                                _selectedBatch != null) &&
                            _maxStock > 0)
                        ? _submit
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.background,
                  disabledForegroundColor: AppColors.textHint,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Agregar a la lista',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final bool isWarning;

  const _InfoBadge({required this.text, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
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
