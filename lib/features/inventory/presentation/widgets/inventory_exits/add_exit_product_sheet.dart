import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_batches_for_variant_usecase.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

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
  final _getBatchesUseCase = sl<GetBatchesForVariantUseCase>();

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
      final batches = await _getBatchesUseCase.call(
        variantId,
        widget.warehouseId,
      );
      if (mounted) {
        setState(() {
          _availableBatches = List<Map<String, dynamic>>.from(batches);
          if (_availableBatches.isNotEmpty) {
            _selectedBatch = _availableBatches.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando lotes: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingBatches = false);
    }
  }

  double get _maxAvailable {
    if (_selectedBatch == null) return 0;
    return (_selectedBatch!['available_quantity'] as num).toDouble();
  }

  Future<void> _showQuantityDialog() async {
    if (_maxAvailable <= 0) return;

    final qtyCtrl = TextEditingController(text: _quantity.toStringAsFixed(0));
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad a retirar',
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
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () {
                  final newQty = double.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      _quantity =
                          newQty > _maxAvailable ? _maxAvailable : newQty;
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

    final finalQty = _quantity > _maxAvailable ? _maxAvailable : _quantity;
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
    final availableVariants =
        _selectedProduct == null
            ? const <ProductVariantModel>[]
            : (widget.variantsByProduct[_selectedProduct!.id] ?? []);

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
    } else if (_selectedProduct?.primaryImageUrl != null) {
      currentImageUrl = _selectedProduct!.primaryImageUrl;
    }

    double displayCost = 0.0;
    if (_selectedProduct != null) {
      final double varCost = _selectedVariant?.unitCost ?? 0.0;
      displayCost = varCost > 0 ? varCost : _selectedProduct!.unitCost;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
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
              'Agregar a la Salida',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── BUSCADOR DE PRODUCTO ──
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
                                  color: AppColors.textMuted,
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
            const SizedBox(height: 16),

            // ── VARIANTE ──
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
                onChanged: _onVariantSelected,
              ),
              const SizedBox(height: 16),
            ],

            // ── IMAGEN Y COSTO (SOLO LECTURA) ──
            if (_selectedProduct != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ProductThumbnail(imageUrl: currentImageUrl, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: displayCost.toStringAsFixed(2),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        labelText: 'Costo Unitario (S/)',
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
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
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // ── LOTE Y STOCK ──
            if (_selectedVariant != null) ...[
              if (_loadingBatches)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_availableBatches.isEmpty) ...[
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
                const SizedBox(height: 20),
              ] else if (_selectedProduct?.usesBatches == true) ...[
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedBatch,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded),
                  decoration: _dropdownDecoration(
                    'Lote disponible en el Almacén',
                  ),
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
                  onChanged:
                      (val) => setState(() {
                        _selectedBatch = val;
                        _quantity = 1;
                      }),
                ),
                const SizedBox(height: 20),
              ],
            ],

            // ── CANTIDAD ──
            if (_selectedBatch != null && _maxAvailable > 0) ...[
              const _FieldLabel('Cantidad a retirar'),
              const SizedBox(height: 8),
              _HorizontalStepper(
                value: _quantity.toInt(),
                onAdd:
                    _quantity < _maxAvailable
                        ? () => setState(() => _quantity++)
                        : null,
                onRemove:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
                onTapValue: _showQuantityDialog,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Máximo disponible: ${_maxAvailable.toInt()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── BOTÓN GUARDAR ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (_selectedProduct != null &&
                            _selectedVariant != null &&
                            _selectedBatch != null &&
                            _maxAvailable > 0)
                        ? _onSave
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
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
  final int value;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback onTapValue;
  const _HorizontalStepper({
    required this.value,
    this.onAdd,
    this.onRemove,
    required this.onTapValue,
  });

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
          _QtyButton(
            icon: Icons.remove_rounded,
            enabled: onRemove != null,
            onTap: onRemove ?? () {},
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTapValue,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    value.toString(),
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
            enabled: onAdd != null,
            onTap: onAdd ?? () {},
          ),
        ],
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
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color:
              enabled
                  ? AppColors.danger
                  : AppColors.danger.withValues(alpha: 0.5),
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
    prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
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
