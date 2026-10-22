import 'dart:async';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

/// Panel para añadir un producto a la entrada de inventario.
///
/// - En pantallas angostas se muestra como bottom sheet.
/// - En pantallas anchas se muestra como diálogo anclado arriba (no salta
///   de posición al crecer el contenido).
///
/// Usa [AddEntryProductSheet.show] para abrirlo: elige el formato solo.
class AddEntryProductSheet extends StatefulWidget {
  final String? warehouseId;
  final bool isBatchRequired;

  /// Si se pasa, aparece el botón "Agregar y seguir": agrega el producto a la
  /// lista sin cerrar el panel, para cargar varios productos seguidos.
  final ValueChanged<InventoryEntryItemEntity>? onAddAndContinue;

  /// Lo define [show]. `true` = diálogo (pantalla ancha).
  final bool asDialog;

  /// Producto inicial opcional (ej. cuando se escaneó un código previamente).
  final ProductModel? initialProduct;

  /// Variante inicial opcional.
  final ProductVariantModel? initialVariant;

  const AddEntryProductSheet({
    super.key,
    this.warehouseId,
    this.isBatchRequired = true,
    this.onAddAndContinue,
    this.asDialog = false,
    this.initialProduct,
    this.initialVariant,
  });

  static Future<InventoryEntryItemEntity?> show(
    BuildContext context, {
    String? warehouseId,
    bool isBatchRequired = true,
    ValueChanged<InventoryEntryItemEntity>? onAddAndContinue,
    ProductModel? initialProduct,
    ProductVariantModel? initialVariant,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      return showDialog<InventoryEntryItemEntity>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black54,
        builder:
            (_) => AddEntryProductSheet(
              warehouseId: warehouseId,
              isBatchRequired: isBatchRequired,
              onAddAndContinue: onAddAndContinue,
              asDialog: true,
              initialProduct: initialProduct,
              initialVariant: initialVariant,
            ),
      );
    }
    return showModalBottomSheet<InventoryEntryItemEntity>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => AddEntryProductSheet(
            warehouseId: warehouseId,
            isBatchRequired: isBatchRequired,
            onAddAndContinue: onAddAndContinue,
            initialProduct: initialProduct,
            initialVariant: initialVariant,
          ),
    );
  }

  @override
  State<AddEntryProductSheet> createState() => _AddEntryProductSheetState();
}

class _AddEntryProductSheetState extends State<AddEntryProductSheet> {
  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  double _quantity = 1;
  final _costCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _batchCtrl = TextEditingController();
  DateTime? _expiryDate;

  /// El usuario tocó el costo a mano: ya no lo pisamos con el sugerido.
  bool _costEdited = false;

  /// Error mostrado dentro del panel (un snackbar quedaría detrás del modal).
  String? _formError;
  String? _lastHandledError;

  /// Producto recién agregado con "Agregar y seguir".
  String? _lastAddedName;
  int _addedCount = 0;

  final _searchDebouncer = _Debouncer(milliseconds: 500);

  late final AddEntryProductCubit _cubit;
  late final ProductsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = GetIt.I<ProductsRepository>();
    _cubit = AddEntryProductCubit(_repository);
    if (widget.initialProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onProductChanged(widget.initialProduct);
        if (widget.initialVariant != null) {
          _onVariantChanged(widget.initialVariant);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    _batchCtrl.dispose();
    _cubit.close();
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  /// Costo efectivo: primero el de la variante (si es > 0), luego el del
  /// producto como fallback.
  double _effectiveCost({ProductVariantModel? variant, ProductModel? product}) {
    final variantCost = variant?.unitCost ?? 0;
    if (variantCost > 0) return variantCost;
    return product?.defaultVariant?.unitCost ?? 0;
  }

  double get _currentCost =>
      double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

  String _fmtQty(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _onProductChanged(ProductModel? val) {
    ProductVariantModel? autoSelectedVariant;
    if (val != null && val.productVariants.length == 1) {
      autoSelectedVariant = val.productVariants.first;
    }

    setState(() {
      _selectedProduct = val;
      _selectedVariant = autoSelectedVariant;
      _quantity = 1;
      _qtyCtrl.text = '1';
      _costEdited = false;
      _formError = null;
      _lastHandledError = null;
      _batchCtrl.clear();
      _expiryDate = null;
      if (val != null) {
        final cost = _effectiveCost(variant: autoSelectedVariant, product: val);
        _costCtrl.text = cost.toStringAsFixed(2);
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
      _formError = null;
      if (!_costEdited) {
        final cost = _effectiveCost(variant: val, product: _selectedProduct);
        _costCtrl.text = cost.toStringAsFixed(2);
      }
      _batchCtrl.clear();
    });

    if (val != null &&
        _selectedProduct?.usesBatches == true &&
        widget.warehouseId != null) {
      _cubit.loadBatches(val.id, widget.warehouseId!);
    }
  }

  void _setQuantity(double value) {
    setState(() {
      _quantity = value;
      _qtyCtrl.text = _fmtQty(value);
      _qtyCtrl.selection = TextSelection.collapsed(
        offset: _qtyCtrl.text.length,
      );
      _formError = null;
    });
  }

  void _stepQuantity(int delta) {
    HapticFeedback.selectionClick();
    final double base = _quantity > 0 ? _quantity : 0.0;
    double next = base + delta;
    if (next < 1) next = 1;
    _setQuantity(next);
  }

  void _onQuantityTyped(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    setState(() {
      _quantity = (parsed != null && parsed > 0) ? parsed : 0;
      _formError = null;
    });
  }

  void _fail(String message) {
    HapticFeedback.mediumImpact();
    setState(() => _formError = message);
  }

  InventoryEntryItemEntity? _buildItem(AddEntryProductState state) {
    final product = _selectedProduct;
    if (product == null) {
      _fail('Selecciona un producto');
      return null;
    }

    final variants = state.availableVariants;
    if (variants.length > 1 && _selectedVariant == null) {
      _fail('Elige una variante para continuar');
      return null;
    }
    if (_quantity <= 0) {
      _fail('La cantidad debe ser mayor a 0');
      return null;
    }

    final cost = double.tryParse(_costCtrl.text.trim().replaceAll(',', '.'));
    if (cost == null || cost < 0) {
      _fail('Ingresa un costo válido (positivo)');
      return null;
    }

    final bool usesBatches = product.usesBatches == true;
    if (widget.isBatchRequired &&
        usesBatches &&
        _batchCtrl.text.trim().isEmpty) {
      _fail('El número de lote es obligatorio para este producto');
      return null;
    }

    final variantToUse =
        _selectedVariant ??
        (variants.isNotEmpty
            ? variants.first
            : (product.productVariants.isNotEmpty
                ? product.productVariants.first
                : ProductVariantModel(
                  id: '',
                  productId: product.id,
                  sku: null,
                  salePrice: null,
                )));

    return InventoryEntryItemEntity(
      productId: product.id,
      productName: product.name,
      variantId: variantToUse.id,
      variantLabel: _selectedVariant?.label ?? variantToUse.label,
      imageUrl: _resolveCurrentImageUrl(),
      usesBatches: usesBatches,
      quantity: _quantity,
      unitCost: cost,
      batchNumber:
          usesBatches
              ? (_batchCtrl.text.trim().isEmpty
                  ? 'DEFAULT'
                  : _batchCtrl.text.trim())
              : 'DEFAULT',
      expiryDate: usesBatches ? _expiryDate : null,
    );
  }

  void _submit(AddEntryProductState state, {bool keepOpen = false}) {
    final item = _buildItem(state);
    if (item == null) return;

    if (keepOpen && widget.onAddAndContinue != null) {
      HapticFeedback.mediumImpact();
      widget.onAddAndContinue!(item);
      setState(() {
        _selectedProduct = null;
        _selectedVariant = null;
        _quantity = 1;
        _qtyCtrl.text = '1';
        _costCtrl.clear();
        _batchCtrl.clear();
        _expiryDate = null;
        _costEdited = false;
        _formError = null;
        _lastHandledError = null;
        _lastAddedName = item.productName;
        _addedCount++;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context, item);
  }

  void _onCubitState(BuildContext context, AddEntryProductState state) {
    final error = state.errorMessage;
    if (error != null && error.isNotEmpty && error != _lastHandledError) {
      _lastHandledError = error;
      setState(() => _formError = error);
    }

    // Autoselección de variante / costo sugerido, solo con el producto
    // actual ya cargado (evita aplicar variantes de un producto anterior).
    if (_selectedProduct == null ||
        state.isLoadingVariants ||
        state.availableVariants.isEmpty ||
        _selectedVariant != null) {
      return;
    }

    if (state.availableVariants.length == 1) {
      setState(() {
        _selectedVariant = state.availableVariants.first;
        if (!_costEdited) {
          final cost = _effectiveCost(
            variant: _selectedVariant,
            product: _selectedProduct,
          );
          if (cost > 0) _costCtrl.text = cost.toStringAsFixed(2);
        }
      });
    } else if (!_costEdited && _currentCost <= 0.0) {
      final suggested = _effectiveCost(
        variant: state.availableVariants.first,
        product: _selectedProduct,
      );
      if (suggested > 0) {
        setState(() => _costCtrl.text = suggested.toStringAsFixed(2));
      }
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<AddEntryProductCubit, AddEntryProductState>(
        listener: _onCubitState,
        builder: (context, state) {
          final mq = MediaQuery.of(context);

          if (widget.asDialog) {
            final top =
                mq.size.height * 0.08 < 24 ? 24.0 : mq.size.height * 0.08;
            final maxHeight = mq.size.height - top - 24 - mq.viewInsets.bottom;
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  top,
                  24,
                  24 + mq.viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    maxHeight: maxHeight,
                  ),
                  child: _buildPanel(
                    context,
                    state,
                    radius: BorderRadius.circular(24),
                    elevation: 12,
                  ),
                ),
              ),
            );
          }

          final maxHeight =
              mq.size.height -
              mq.viewInsets.bottom -
              mq.padding.top -
              mq.padding.bottom -
              8;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 540,
                    maxHeight: maxHeight,
                  ),
                  child: _buildPanel(
                    context,
                    state,
                    radius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    AddEntryProductState state, {
    required BorderRadius radius,
    required double elevation,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      elevation: elevation,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: _buildContent(context, state),
            ),
          ),
          _buildFooter(context, state),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asDialog)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, widget.asDialog ? 20 : 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Añadir producto',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_addedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _addedCount == 1
                              ? '1 producto agregado en esta sesión'
                              : '$_addedCount productos agregados en esta sesión',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AddEntryProductState state) {
    final product = _selectedProduct;
    final variantLabel = _selectedVariant?.label;
    final showVariantLabel =
        variantLabel != null &&
        variantLabel.isNotEmpty &&
        variantLabel != 'Default' &&
        variantLabel != 'Variante Única';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lastAddedName != null) _AddedBanner(name: _lastAddedName!),
        if (product == null) ...[
          const _FieldLabel('Producto'),
          const SizedBox(height: 8),
          _buildSearchField(context),
          const _SearchHint(),
        ] else ...[
          _SelectedProductCard(
            name: product.name,
            variantLabel: showVariantLabel ? variantLabel : null,
            imageUrl: _resolveCurrentImageUrl(),
            usesBatches: product.usesBatches == true,
            onChange: () {
              HapticFeedback.lightImpact();
              _onProductChanged(null);
            },
          ),
          ..._buildDetails(context, state),
        ],
      ],
    );
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  Widget _buildSearchField(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final overlayWidth = constraints.maxWidth;
        return Autocomplete<ProductModel>(
          displayStringForOption: (p) => p.name,
          optionsBuilder: (textEditingValue) async {
            if (textEditingValue.text.trim().isEmpty) {
              return const Iterable<ProductModel>.empty();
            }
            return _searchDebouncer.run<Iterable<ProductModel>>(() async {
              final res = await _repository.searchProductsForEntry(
                textEditingValue.text,
              );
              return res.fold((l) {
                developer.log('Error de red al buscar', error: l.message);
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
          onSelected: _onProductChanged,
          fieldViewBuilder: (
            context,
            textEditingController,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              autofocus: widget.initialProduct == null,
              textInputAction: TextInputAction.search,
              style: textTheme.bodyLarge,
              decoration: _inputDecoration(
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
                      _onProductChanged(ProductModel.fromEntity(res.product));
                      if (res.variant != null) {
                        _onVariantChanged(
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
                          leading: _ProductThumbnail(
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
                            HapticFeedback.lightImpact();
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

  // ── Detalles del producto elegido ─────────────────────────────────────────

  List<Widget> _buildDetails(BuildContext context, AddEntryProductState state) {
    final variants = state.availableVariants;
    final usesBatches = _selectedProduct?.usesBatches == true;
    final subtotal = _quantity * _currentCost;

    return [
      if (state.isLoadingVariants)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
            ),
          ),
        )
      else if (variants.length > 1) ...[
        const SizedBox(height: 20),
        const _FieldLabel('Variante'),
        const SizedBox(height: 8),
        _buildVariantPicker(context, variants),
      ],
      const SizedBox(height: 20),
      _buildAmounts(context),
      if (usesBatches) ...[
        const SizedBox(height: 20),
        _buildBatchSection(context, state),
      ],
      const SizedBox(height: 20),
      _SubtotalBar(subtotal: subtotal),
    ];
  }

  Widget _buildVariantPicker(
    BuildContext context,
    List<ProductVariantModel> variants,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Pocas variantes: chips (1 toque). Muchas: lista desplegable.
    if (variants.length > 6) {
      return DropdownButtonFormField<ProductVariantModel>(
        initialValue: _selectedVariant,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded),
        decoration: _inputDecoration(hint: 'Selecciona una variante'),
        items:
            variants
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
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          variants.map((v) {
            final selected = _selectedVariant?.id == v.id;
            return ChoiceChip(
              label: Text(v.label),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                _onVariantChanged(v);
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.background,
              labelStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildAmounts(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isZeroCost = _currentCost == 0.0;

    final costField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Costo unitario'),
        const SizedBox(height: 8),
        TextField(
          controller: _costCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onTap:
              () =>
                  _costCtrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _costCtrl.text.length,
                  ),
          onChanged:
              (_) => setState(() {
                _costEdited = true;
                _formError = null;
              }),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          decoration: _inputDecoration(
            prefixText: 'S/ ',
            helper: isZeroCost ? 'Verifica el costo: está en S/ 0.00' : null,
            accent: isZeroCost ? AppColors.warning : null,
          ),
        ),
      ],
    );

    final qtyField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Cantidad'),
        const SizedBox(height: 8),
        _QuantityStepper(
          controller: _qtyCtrl,
          canDecrease: _quantity > 1,
          onDecrease: () => _stepQuantity(-1),
          onIncrease: () => _stepQuantity(1),
          onChanged: _onQuantityTyped,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 300) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: costField),
              const SizedBox(width: 12),
              Expanded(child: qtyField),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [costField, const SizedBox(height: 16), qtyField],
        );
      },
    );
  }

  Widget _buildBatchSection(BuildContext context, AddEntryProductState state) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(
          widget.isBatchRequired ? 'Lote (obligatorio)' : 'Lote (opcional)',
        ),
        const SizedBox(height: 8),
        if (state.isLoadingBatches)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final overlayWidth = constraints.maxWidth;
              return Autocomplete<WarehouseStockBatchModel>(
                key: ValueKey(
                  'batch_autocomplete_${_selectedProduct?.id}_${_selectedVariant?.id}',
                ),
                initialValue: TextEditingValue(text: _batchCtrl.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final batches =
                      state.availableBatches
                          .map((e) => WarehouseStockBatchModel.fromJson(e))
                          .toList();
                  if (textEditingValue.text.isEmpty) return batches;
                  return batches.where(
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
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (value) {
                      _batchCtrl.text = value;
                      if (_formError != null) {
                        setState(() => _formError = null);
                      }
                    },
                    decoration: _inputDecoration(
                      hint:
                          state.availableBatches.isEmpty
                              ? (widget.isBatchRequired
                                  ? 'Ej: LOTE-2024-001'
                                  : 'Se asigna en la recepción física')
                              : 'Escribe o elige un lote existente',
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon:
                          state.availableBatches.isNotEmpty
                              ? Tooltip(
                                message:
                                    '${state.availableBatches.length} lote(s) en este almacén',
                                child: Icon(
                                  Icons.layers_rounded,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                  size: 20,
                                ),
                              )
                              : null,
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
                            maxHeight: 260,
                            maxWidth: overlayWidth,
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder:
                                (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final dateStr =
                                  option.expiryDate != null
                                      ? _formatDate(option.expiryDate!)
                                      : 'Sin vencimiento';
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.tag_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  option.batchNumber,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Vence: $dateStr',
                                  style: textTheme.bodySmall,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Stock',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      option.availableQuantity.toStringAsFixed(
                                        0,
                                      ),
                                      style: textTheme.titleSmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
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
                    ),
                  );
                },
                onSelected: (WarehouseStockBatchModel selection) {
                  setState(() {
                    _batchCtrl.text = selection.batchNumber;
                    _expiryDate = selection.expiryDate;
                    _formError = null;
                  });
                },
              );
            },
          ),
        const SizedBox(height: 12),
        _DatePickerField(
          label: 'Fecha de vencimiento (opcional)',
          value: _expiryDate,
          onPick: (d) => setState(() => _expiryDate = d),
          onClear: () {
            HapticFeedback.lightImpact();
            setState(() => _expiryDate = null);
          },
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, AddEntryProductState state) {
    final loading = state.isLoadingVariants || state.isLoadingBatches;
    final canAdd = _selectedProduct != null && !loading;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_formError != null) _InlineError(message: _formError!),
          Row(
            children: [
              if (widget.onAddAndContinue != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        canAdd ? () => _submit(state, keepOpen: true) : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Agregar y seguir',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: canAdd ? () => _submit(state) : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary,
                    foregroundColor: colorScheme.onPrimary,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Agregar a la lista',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Decoración compartida ─────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    String? hint,
    String? helper,
    String? prefixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? accent,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      helperText: helper,
      helperStyle: TextStyle(
        color: accent ?? AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(accent ?? AppColors.border),
      enabledBorder: border(accent ?? AppColors.border),
      focusedBorder: border(accent ?? AppColors.primary, 1.5),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═════════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}

/// Estado inicial: invita a buscar en vez de dejar un hueco vacío.
class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Escribe el nombre del producto',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedProductCard extends StatelessWidget {
  final String name;
  final String? variantLabel;
  final String? imageUrl;
  final bool usesBatches;
  final VoidCallback onChange;

  const _SelectedProductCard({
    required this.name,
    required this.variantLabel,
    required this.imageUrl,
    required this.usesBatches,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ProductThumbnail(imageUrl: imageUrl, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (variantLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      variantLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (usesBatches)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Se controla por lote',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(64, 44),
            ),
            child: const Text(
              'Cambiar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddedBanner extends StatelessWidget {
  final String name;
  const _AddedBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$name agregado a la lista',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtotalBar extends StatelessWidget {
  final double subtotal;
  const _SubtotalBar({required this.subtotal});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Subtotal',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              'S/ ${subtotal.toStringAsFixed(2)}',
              key: ValueKey(subtotal.toStringAsFixed(2)),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stepper con la cantidad editable directamente (sin diálogo intermedio).
class _QuantityStepper extends StatelessWidget {
  final TextEditingController controller;
  final bool canDecrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onChanged;

  const _QuantityStepper({
    required this.controller,
    required this.canDecrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 5),
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
              enabled: canDecrease,
              onTap: onDecrease,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
              ],
              onTap:
                  () =>
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      ),
              onChanged: onChanged,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Semantics(
            label: 'Aumentar cantidad',
            button: true,
            child: _QtyButton(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: onIncrease,
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
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.primary.withValues(alpha: 0.18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color:
                enabled
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
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
            initialDate: value ?? DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            helpText: 'Fecha de vencimiento',
          );
          if (picked != null) onPick(picked);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          padding: EdgeInsets.only(left: 16, right: value != null ? 0 : 16),
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
                  value == null ? label : 'Vence: ${_formatDate(value!)}',
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
            imageUrl != null && imageUrl!.trim().isNotEmpty
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
