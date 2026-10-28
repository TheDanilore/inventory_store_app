import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_amount_loss_section.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_batch_picker.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_search_section.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_selected_product_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_sheet_helpers.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_variant_picker.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';

// Re-exportar para preservar compatibilidad con código existente
export 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_sheet_helpers.dart'
    show exitBatchKey;

/// Panel para añadir un producto a la salida de inventario.
///
/// Optimizado con política Zero-Shimmer (Cache-First) y arquitectura modular.
/// - Pantallas angostas: modal bottom sheet.
/// - Pantallas anchas: diálogo anclado arriba.
class AddExitProductSheet extends StatefulWidget {
  final String warehouseId;
  final Map<String, double> reservedByBatchId;
  final ValueChanged<ExitItemUI>? onAddAndContinue;
  final bool asDialog;
  final ProductModel? initialProduct;
  final ProductVariantModel? initialVariant;

  const AddExitProductSheet({
    super.key,
    required this.warehouseId,
    this.reservedByBatchId = const {},
    this.onAddAndContinue,
    this.asDialog = false,
    this.initialProduct,
    this.initialVariant,
  });

  static Future<ExitItemUI?> show(
    BuildContext context, {
    required String warehouseId,
    Map<String, double> reservedByBatchId = const {},
    ValueChanged<ExitItemUI>? onAddAndContinue,
    ProductModel? initialProduct,
    ProductVariantModel? initialVariant,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (isWide) {
      return showDialog<ExitItemUI>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black54,
        builder:
            (_) => AddExitProductSheet(
              warehouseId: warehouseId,
              reservedByBatchId: reservedByBatchId,
              onAddAndContinue: onAddAndContinue,
              asDialog: true,
              initialProduct: initialProduct,
              initialVariant: initialVariant,
            ),
      );
    }
    return showModalBottomSheet<ExitItemUI>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => AddExitProductSheet(
            warehouseId: warehouseId,
            reservedByBatchId: reservedByBatchId,
            onAddAndContinue: onAddAndContinue,
            initialProduct: initialProduct,
            initialVariant: initialVariant,
          ),
    );
  }

  @override
  State<AddExitProductSheet> createState() => _AddExitProductSheetState();
}

class _AddExitProductSheetState extends State<AddExitProductSheet> {
  late final ProductsRepository _repository;
  late final AddExitProductCubit _cubit;
  late final Map<String, double> _reserved;

  ProductModel? _selectedProduct;
  ProductVariantModel? _selectedVariant;
  Map<String, dynamic>? _selectedBatch;
  double _quantity = 1;

  String? _requestedBatchesFor;
  String? _formError;
  String? _lastHandledError;
  String? _lastAddedName;
  int _addedCount = 0;

  @override
  void initState() {
    super.initState();
    _repository = GetIt.I<ProductsRepository>();
    _cubit = AddExitProductCubit(_repository);
    _reserved = Map<String, double>.of(widget.reservedByBatchId);

    if (widget.initialProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onProductChanged(widget.initialProduct);
        if (widget.initialVariant != null) {
          _onVariantChanged(widget.initialVariant!);
        }
      });
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  // ── Lógica de Cálculo y Stock ─────────────────────────────────────────────

  double _stockOf(Map<String, dynamic> b) =>
      (b['available_quantity'] as num?)?.toDouble() ?? 0.0;

  double _remainingOf(Map<String, dynamic> b) {
    final r = _stockOf(b) - (_reserved[exitBatchKey(b)] ?? 0.0);
    return r < 0 ? 0.0 : r;
  }

  DateTime? _expiryOf(Map<String, dynamic> b) {
    final raw = b['expiry_date'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  double get _maxAvailable =>
      _selectedBatch == null ? 0.0 : _remainingOf(_selectedBatch!);

  double get _unitCost {
    final variantCost = _selectedVariant?.unitCost ?? 0.0;
    if (variantCost > 0) return variantCost;
    return _selectedProduct?.defaultVariant?.unitCost ?? 0.0;
  }

  List<ProductVariantModel> _variantsOf(AddExitProductState state) {
    if (state.availableVariants.isNotEmpty) return state.availableVariants;
    return _selectedProduct?.productVariants ?? const [];
  }

  List<Map<String, dynamic>> _sortedBatches(List<Map<String, dynamic>> raw) {
    final list = List<Map<String, dynamic>>.of(raw);
    list.sort((a, b) {
      final ea = _expiryOf(a);
      final eb = _expiryOf(b);
      if (ea == null && eb == null) {
        return (a['batch_number'] ?? '').toString().compareTo(
          (b['batch_number'] ?? '').toString(),
        );
      }
      if (ea == null) return 1;
      if (eb == null) return -1;
      return ea.compareTo(eb);
    });
    return list;
  }

  void _requestBatches(ProductVariantModel v) {
    _requestedBatchesFor = v.id;
    _cubit.loadBatches(v.id, widget.warehouseId);
  }

  void _selectBatch(Map<String, dynamic>? batch) {
    setState(() {
      _selectedBatch = batch;
      final remaining = batch == null ? 0.0 : _remainingOf(batch);
      _quantity = remaining >= 1 ? 1 : remaining;
      _formError = null;
    });
  }

  void _onProductChanged(ProductModel? product) {
    setState(() {
      _selectedProduct = product;
      _selectedVariant = null;
      _selectedBatch = null;
      _requestedBatchesFor = null;
      _quantity = 1;
      _formError = null;
      _lastHandledError = null;
    });
    if (product == null) return;

    _cubit.loadVariantsAndBatches(
      product.id,
      product.usesBatches,
      widget.warehouseId,
    );

    if (product.productVariants.length == 1) {
      final v = product.productVariants.first;
      setState(() => _selectedVariant = v);
      _requestBatches(v);
    }
  }

  void _onVariantChanged(ProductVariantModel v) {
    setState(() {
      _selectedVariant = v;
      _selectedBatch = null;
      _quantity = 1;
      _formError = null;
    });
    _requestBatches(v);
  }

  void _onCubitState(BuildContext context, AddExitProductState state) {
    final error = state.errorMessage;
    if (error != null && error.isNotEmpty && error != _lastHandledError) {
      _lastHandledError = error;
      setState(() => _formError = error);
    }

    final product = _selectedProduct;
    if (product == null || state.isLoadingVariants) return;

    if (_selectedVariant == null && state.availableVariants.length == 1) {
      final v = state.availableVariants.first;
      setState(() => _selectedVariant = v);
      _requestBatches(v);
      return;
    }

    final variant = _selectedVariant;
    if (variant == null) return;

    if (_requestedBatchesFor != variant.id) {
      _requestBatches(variant);
      return;
    }

    if (state.isLoadingBatches || _selectedBatch != null) return;

    final selectable =
        state.availableBatches.where((b) => _remainingOf(b) > 0).toList();
    if (selectable.isEmpty) return;

    if (!product.usesBatches || selectable.length == 1) {
      _selectBatch(_sortedBatches(selectable).first);
    }
  }

  void _fail(String message) {
    AppFeedbackService.mediumImpact();
    setState(() => _formError = message);
  }

  ExitItemUI? _buildItem(AddExitProductState state) {
    final product = _selectedProduct;
    if (product == null) {
      _fail('Selecciona un producto');
      return null;
    }

    final variant = _selectedVariant;
    if (variant == null) {
      _fail(
        _variantsOf(state).length > 1
            ? 'Elige una variante para continuar'
            : 'Aún se están cargando los datos del producto',
      );
      return null;
    }

    if (state.isLoadingBatches) {
      _fail('Cargando el stock disponible…');
      return null;
    }

    final batch = _selectedBatch;
    if (batch == null) {
      if (state.availableBatches.isEmpty) {
        _fail('No hay stock de esta variante en el almacén de origen');
      } else if (product.usesBatches) {
        _fail('Elige el lote del que vas a retirar');
      } else {
        _fail('No hay stock disponible para retirar');
      }
      return null;
    }

    if (_quantity <= 0) {
      _fail('La cantidad debe ser mayor a 0');
      return null;
    }
    if (_quantity > _maxAvailable + 1e-9) {
      _fail(
        'Solo hay ${formatExitQty(_maxAvailable)} disponibles en este lote',
      );
      return null;
    }

    return ExitItemUI(
      product: product,
      variant: variant,
      selectedBatch: batch,
      quantity: _quantity,
      unitCost: _unitCost,
    );
  }

  void _submit(AddExitProductState state, {bool keepOpen = false}) {
    final item = _buildItem(state);
    if (item == null) return;

    AppFeedbackService.mediumImpact();

    if (keepOpen && widget.onAddAndContinue != null) {
      widget.onAddAndContinue!(item);
      final key = exitBatchKey(item.selectedBatch);
      setState(() {
        _reserved[key] = (_reserved[key] ?? 0.0) + item.quantity;
        _selectedProduct = null;
        _selectedVariant = null;
        _selectedBatch = null;
        _requestedBatchesFor = null;
        _quantity = 1;
        _formError = null;
        _lastHandledError = null;
        _lastAddedName = item.product.name;
        _addedCount++;
      });
      return;
    }

    Navigator.pop(context, item);
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

  // ── Renderizado ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<AddExitProductCubit, AddExitProductState>(
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
    AddExitProductState state, {
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
                      'Retirar producto',
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

  Widget _buildContent(BuildContext context, AddExitProductState state) {
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
        if (_lastAddedName != null) ExitAddedBanner(name: _lastAddedName!),
        if (product == null)
          ExitSearchSection(
            warehouseId: widget.warehouseId,
            repository: _repository,
            autofocus: widget.initialProduct == null,
            onProductSelected: _onProductChanged,
            onVariantSelected: _onVariantChanged,
          )
        else ...[
          ExitSelectedProductCard(
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

  List<Widget> _buildDetails(BuildContext context, AddExitProductState state) {
    final variants = _variantsOf(state);
    final needsVariant = variants.length > 1 && _selectedVariant == null;

    return [
      if (state.isLoadingVariants)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: ExitLoadingBar(),
        )
      else if (variants.length > 1) ...[
        const SizedBox(height: 20),
        const ExitFieldLabel('Variante'),
        const SizedBox(height: 8),
        ExitVariantPicker(
          variants: variants,
          selectedVariant: _selectedVariant,
          onVariantChanged: _onVariantChanged,
        ),
      ],
      if (needsVariant)
        const ExitMutedHint('Elige una variante para ver el stock disponible.')
      else if (_selectedVariant != null) ...[
        const SizedBox(height: 20),
        _buildStockSection(context, state),
      ],
      if (_selectedBatch != null && _maxAvailable > 0) ...[
        const SizedBox(height: 20),
        ExitAmountLossSection(
          productId: _selectedProduct!.id,
          variantId: _selectedVariant?.id,
          batchKey: exitBatchKey(_selectedBatch),
          unitCost: _unitCost,
          quantity: _quantity,
          maxAvailable: _maxAvailable,
          onQuantityChanged:
              (v) => setState(() {
                _quantity = v;
                _formError = null;
              }),
        ),
      ],
    ];
  }

  Widget _buildStockSection(BuildContext context, AddExitProductState state) {
    final product = _selectedProduct!;

    if (state.isLoadingBatches) {
      return const ExitLoadingBar();
    }

    final batches = _sortedBatches(state.availableBatches);
    final totalRemaining = batches.fold<double>(
      0.0,
      (sum, b) => sum + _remainingOf(b),
    );

    if (batches.isEmpty) {
      return const ExitNoStockBox(
        message: 'No hay stock de esta variante en el almacén de origen.',
      );
    }
    if (totalRemaining <= 0) {
      return const ExitNoStockBox(
        message: 'Ya agregaste todo el stock disponible de esta variante.',
      );
    }

    if (!product.usesBatches) {
      final available =
          _selectedBatch != null
              ? _remainingOf(_selectedBatch!)
              : totalRemaining;
      return ExitStockInfo(formattedAvailable: formatExitQty(available));
    }

    return ExitBatchPicker(
      batches: batches,
      selectedBatch: _selectedBatch,
      reserved: _reserved,
      onSelectBatch: _selectBatch,
    );
  }

  Widget _buildFooter(BuildContext context, AddExitProductState state) {
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
          if (_formError != null) ExitInlineError(message: _formError!),
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
}
