import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_entry_product/add_entry_product_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_batch_selector.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_cost_quantity_fields.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_common_widgets.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_footer_actions.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_search_bar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_selected_product_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_variant_selector.dart';

/// Panel modular optimizado para añadir productos a la entrada de inventario.
///
/// - Pantallas angostas: ModalBottomSheet adaptativo.
/// - Pantallas anchas: Diálogo anclado superior con contención de viewport.
/// - Stale-While-Revalidate: Carga inmediata desde EntryProductCache (Zero-Shimmer).
class AddEntryProductSheet extends StatefulWidget {
  final String? warehouseId;
  final bool isBatchRequired;
  final ValueChanged<InventoryEntryItemEntity>? onAddAndContinue;
  final bool asDialog;
  final ProductModel? initialProduct;
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

  bool _costEdited = false;
  String? _formError;
  String? _lastHandledError;
  String? _lastAddedName;
  int _addedCount = 0;

  late final AddEntryProductCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = AddEntryProductCubit(GetIt.I<ProductsRepository>());
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
    _costCtrl.dispose();
    _qtyCtrl.dispose();
    _batchCtrl.dispose();
    _cubit.close();
    super.dispose();
  }

  double _effectiveCost({ProductVariantModel? variant, ProductModel? product}) {
    final variantCost = variant?.unitCost ?? 0;
    if (variantCost > 0) return variantCost;
    return product?.defaultVariant?.unitCost ?? 0;
  }

  double get _currentCost =>
      double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

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

  void _fail(String message) {
    AppFeedbackService.mediumImpact();
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
      AppFeedbackService.mediumImpact();
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

    AppFeedbackService.mediumImpact();
    Navigator.pop(context, item);
  }

  void _onCubitState(BuildContext context, AddEntryProductState state) {
    final error = state.errorMessage;
    if (error != null && error.isNotEmpty && error != _lastHandledError) {
      _lastHandledError = error;
      setState(() => _formError = error);
    }

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
          EntryProductFooterActions(
            formError: _formError,
            canAdd:
                _selectedProduct != null &&
                !state.isLoadingVariants &&
                !state.isLoadingBatches,
            showAddAndContinue: widget.onAddAndContinue != null,
            onAddAndContinue: () => _submit(state, keepOpen: true),
            onSubmit: () => _submit(state),
          ),
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
        if (_lastAddedName != null) EntryAddedBanner(name: _lastAddedName!),
        if (product == null) ...[
          const EntryFieldLabel('Producto'),
          const SizedBox(height: 8),
          EntryProductSearchBar(
            warehouseId: widget.warehouseId,
            autofocus: widget.initialProduct == null,
            onProductSelected: _onProductChanged,
            onVariantSelected: _onVariantChanged,
          ),
          const EntrySearchHint(),
        ] else ...[
          EntrySelectedProductCard(
            name: product.name,
            variantLabel: showVariantLabel ? variantLabel : null,
            imageUrl: _resolveCurrentImageUrl(),
            usesBatches: product.usesBatches == true,
            onChange: () {
              AppFeedbackService.lightImpact();
              _onProductChanged(null);
            },
          ),
          ..._buildDetails(context, state),
        ],
      ],
    );
  }

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
        const EntryFieldLabel('Variante'),
        const SizedBox(height: 8),
        EntryVariantSelector(
          variants: variants,
          selectedVariant: _selectedVariant,
          onVariantChanged: _onVariantChanged,
        ),
      ],
      const SizedBox(height: 20),
      EntryCostQuantityFields(
        costCtrl: _costCtrl,
        qtyCtrl: _qtyCtrl,
        currentCost: _currentCost,
        quantity: _quantity,
        onCostEdited: () {
          setState(() {
            _costEdited = true;
            _formError = null;
          });
        },
        onQuantityChanged: (val) {
          setState(() {
            _quantity = val;
            _formError = null;
          });
        },
      ),
      if (usesBatches) ...[
        const SizedBox(height: 20),
        EntryBatchSelector(
          isBatchRequired: widget.isBatchRequired,
          isLoadingBatches: state.isLoadingBatches,
          availableBatches: state.availableBatches,
          productId: _selectedProduct?.id,
          variantId: _selectedVariant?.id,
          batchCtrl: _batchCtrl,
          expiryDate: _expiryDate,
          onBatchChanged: (_) {
            if (_formError != null) setState(() => _formError = null);
          },
          onExpiryDateChanged: (d) => setState(() => _expiryDate = d),
          onBatchSelected: (selection) {
            setState(() {
              _batchCtrl.text = selection.batchNumber;
              _expiryDate = selection.expiryDate;
              _formError = null;
            });
          },
        ),
      ],
      const SizedBox(height: 20),
      EntrySubtotalBar(subtotal: subtotal),
    ];
  }
}
