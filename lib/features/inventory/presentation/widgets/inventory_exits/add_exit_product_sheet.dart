import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_state.dart';

class AddExitProductSheet extends StatefulWidget {
  final String warehouseId;

  const AddExitProductSheet({super.key, required this.warehouseId});

  @override
  State<AddExitProductSheet> createState() => _AddExitProductSheetState();
}

class _AddExitProductSheetState extends State<AddExitProductSheet> {
  late final ProductsRepository _repository;
  late final AddExitProductCubit _cubit;

  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  Map<String, dynamic>? _selectedBatch;

  double _quantity = 1;
  String? _quantityError;

  final _searchDebouncer = _Debouncer(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _repository = GetIt.I<ProductsRepository>();
    _cubit = AddExitProductCubit(_repository);
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onProductSelected(ProductModel? p) {
    ProductVariantModel? autoSelectedVariant;
    if (p != null && p.productVariants.isNotEmpty) {
      if (p.productVariants.length == 1) {
        autoSelectedVariant = p.productVariants.first;
      }
    }

    setState(() {
      _selectedProduct = p;
      _selectedVariant = autoSelectedVariant;
      _selectedBatch = null;
      _quantity = 1;
      _quantityError = null;
    });

    if (p != null) {
      _cubit.loadVariantsAndBatches(p.id, p.usesBatches, widget.warehouseId);
    }
  }

  void _onVariantSelected(ProductVariantModel? v) {
    setState(() {
      _selectedVariant = v;
      _selectedBatch = null;
      _quantity = 1;
      _quantityError = null;
    });
    if (v != null) {
      _cubit.loadBatches(v.id, widget.warehouseId);
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
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final sanitizedQty = qtyCtrl.text.trim().replaceAll(',', '.');
                  final newQty = double.tryParse(sanitizedQty);
                  if (newQty != null && newQty > 0) {
                    setState(() {
                      if (newQty > _maxAvailable) {
                        _quantityError =
                            'Supera el stock actual (${_maxAvailable.toInt()})';
                        _quantity = _maxAvailable;
                      } else {
                        _quantityError = null;
                        _quantity = newQty;
                      }
                    });
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

    if (_quantity > _maxAvailable) {
      setState(() {
        _quantityError = 'Supera el stock actual (${_maxAvailable.toInt()})';
      });
      return;
    }

    final double vCost = _selectedVariant!.unitCost ?? 0.0;
    final double pCost = _selectedProduct!.defaultVariant?.unitCost ?? 0.0;
    final double finalUnitCost = vCost > 0 ? vCost : pCost;

    final item = ExitItemUI(
      product: _selectedProduct!,
      variant: _selectedVariant!,
      selectedBatch: _selectedBatch,
      quantity: _quantity,
      unitCost: finalUnitCost,
    );

    Navigator.pop(context, item);
  }

  // Lógica de imagen copiada exactamente de add_entry_product_sheet
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<AddExitProductCubit, AddExitProductState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackbar.show(
              context,
              message: state.errorMessage!,
              type: SnackbarType.error,
            );
          }
          if (state.availableVariants.isNotEmpty && _selectedVariant == null) {
            if (state.availableVariants.length == 1) {
              setState(() {
                _selectedVariant = state.availableVariants.first;
              });
              if (_selectedProduct?.usesBatches == true) {
                _cubit.loadBatches(_selectedVariant!.id, widget.warehouseId);
              }
            }
          }
        },
        builder: (context, state) {
          final availableVariants = state.availableVariants;
          final currentImageUrl = _resolveCurrentImageUrl();

          double displayCost = 0.0;
          if (_selectedProduct != null) {
            final double varCost = _selectedVariant?.unitCost ?? 0.0;
            displayCost =
                varCost > 0
                    ? varCost
                    : (_selectedProduct!.defaultVariant?.unitCost ?? 0.0);
          }

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final textTheme = theme.textTheme;
          final mediaQuery = MediaQuery.of(context);

          double overlayWidth = mediaQuery.size.width - 48;
          if (overlayWidth > 492) {
            overlayWidth = 492;
          }

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
                          'Agregar a la Salida',
                          style: textTheme.titleLarge?.copyWith(
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
                            // Lógica de búsqueda copiada exactamente de add_entry_product_sheet
                            optionsBuilder: (textEditingValue) async {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<ProductModel>.empty();
                              }
                              return _searchDebouncer.run<
                                Iterable<ProductModel>
                              >(() async {
                                final res = await _repository
                                    .searchProductsForEntry(
                                      textEditingValue.text,
                                    );
                                return res.fold((l) {
                                  developer.log(
                                    'Error de red al buscar',
                                    error: l.message,
                                  );
                                  if (mounted) {
                                    AppSnackbar.show(
                                      context,
                                      message:
                                          'Error de red al buscar productos. Revisa tu conexión.',
                                      type: SnackbarType.error,
                                    );
                                  }
                                  return const Iterable<ProductModel>.empty();
                                }, (r) => r.map((p) => ProductModel.fromJson(p)));
                              }, const Iterable<ProductModel>.empty());
                            },
                            onSelected: (val) {
                              HapticFeedback.lightImpact();
                              _onProductSelected(val);
                            },
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
                                              _onProductSelected(null);
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

                                        // Lógica de imagen para la lista copiada de add_entry_product_sheet
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
                        const SizedBox(height: 16),

                        // ── VARIANTE ──
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
                              _onVariantSelected(val);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── IMAGEN Y COSTO (SOLO LECTURA) ──
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
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Costo Unitario (S/)',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'S/ ${displayCost.toStringAsFixed(2)}',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── LOTE Y STOCK ──
                        if (_selectedVariant != null) ...[
                          if (state.isLoadingBatches)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (state.availableBatches.isEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
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
                                  state.availableBatches.map((b) {
                                    final qty = (b['available_quantity'] as num)
                                        .toStringAsFixed(0);
                                    return DropdownMenuItem(
                                      value: b,
                                      child: Text(
                                        '${b['batch_number']} (Stock: $qty)',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedBatch = val;
                                  _quantity = 1;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],

                        // ── CANTIDAD ──
                        if (_selectedBatch != null && _maxAvailable > 0) ...[
                          const _FieldLabel('Cantidad a retirar'),
                          const SizedBox(height: 8),
                          _HorizontalStepper(
                            value: _quantity,
                            onAdd: () {
                              if (_quantity < _maxAvailable) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _quantity++;
                                  _quantityError = null;
                                });
                              } else {
                                setState(() {
                                  _quantityError = 'Límite de stock alcanzado';
                                });
                              }
                            },
                            onRemove:
                                _quantity > 1
                                    ? () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _quantity--;
                                        _quantityError = null;
                                      });
                                    }
                                    : null,
                            onTapValue: _showQuantityDialog,
                          ),
                          if (_quantityError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _quantityError!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Máximo disponible: ${_maxAvailable.toInt()}',
                              style: textTheme.labelMedium?.copyWith(
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
                                    ? () {
                                      HapticFeedback.mediumImpact();
                                      _onSave();
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
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
                                color: Colors.white,
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
        splashColor: AppColors.danger.withValues(alpha: 0.18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                enabled
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.danger : AppColors.textMuted,
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
