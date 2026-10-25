import 'dart:async';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/add_exit_product/add_exit_product_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

/// Identificador estable de un lote (para saber cuánto ya está en la lista).
String exitBatchKey(Map<String, dynamic>? batch) {
  if (batch == null) return '';
  return (batch['id'] ?? batch['batch_number'] ?? '').toString();
}

/// Panel para añadir un producto a la salida de inventario.
///
/// Mismo patrón que `AddEntryProductSheet`:
/// - Pantallas angostas: bottom sheet.
/// - Pantallas anchas: diálogo anclado arriba.
///
/// Usa [AddExitProductSheet.show] para abrirlo.
class AddExitProductSheet extends StatefulWidget {
  final String warehouseId;

  /// Cantidad ya presente en la lista por lote (clave = [exitBatchKey]).
  /// Evita retirar más de lo que realmente hay si el mismo lote se agrega
  /// dos veces.
  final Map<String, double> reservedByBatchId;

  /// Si se pasa, aparece "Agregar y seguir".
  final ValueChanged<ExitItemUI>? onAddAndContinue;

  /// Lo define [show]. `true` = diálogo (pantalla ancha).
  final bool asDialog;

  /// Producto inicial opcional (ej. cuando se escaneó un código previamente).
  final ProductModel? initialProduct;

  /// Variante inicial opcional.
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

  /// Variante para la que ya pedimos lotes (evita pedirlos en bucle).
  String? _requestedBatchesFor;

  /// Error dentro del panel (un snackbar quedaría detrás del modal).
  String? _formError;
  String? _lastHandledError;

  String? _lastAddedName;
  int _addedCount = 0;

  final _searchDebouncer = _Debouncer(milliseconds: 500);

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
    _searchDebouncer.dispose();
    _cubit.close();
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  double _stockOf(Map<String, dynamic> b) =>
      (b['available_quantity'] as num?)?.toDouble() ?? 0.0;

  /// Stock del lote menos lo que ya está en la lista.
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

  /// Primero los que vencen antes (FEFO); sin vencimiento al final.
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

  /// Reacciona a los datos que llegan del cubit: errores, autoselección de
  /// la variante única y del lote (siempre en productos sin lote).
  void _onCubitState(BuildContext context, AddExitProductState state) {
    final error = state.errorMessage;
    if (error != null && error.isNotEmpty && error != _lastHandledError) {
      _lastHandledError = error;
      setState(() => _formError = error);
    }

    final product = _selectedProduct;
    if (product == null || state.isLoadingVariants) return;

    // Variante única llegada desde el cubit.
    if (_selectedVariant == null && state.availableVariants.length == 1) {
      final v = state.availableVariants.first;
      setState(() => _selectedVariant = v);
      _requestBatches(v);
      return;
    }

    final variant = _selectedVariant;
    if (variant == null) return;

    // Pedimos el stock SIEMPRE, use o no lotes el producto.
    if (_requestedBatchesFor != variant.id) {
      _requestBatches(variant);
      return;
    }

    if (state.isLoadingBatches || _selectedBatch != null) return;

    final selectable =
        state.availableBatches.where((b) => _remainingOf(b) > 0).toList();
    if (selectable.isEmpty) return;

    // Sin control por lote, o un solo lote con stock: no hay nada que elegir.
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
              AppFeedbackService.lightImpact();
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
          onSelected: (p) {
            AppFeedbackService.lightImpact();
            _onProductChanged(p);
          },
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
                            AppFeedbackService.lightImpact();
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

  List<Widget> _buildDetails(BuildContext context, AddExitProductState state) {
    final variants = _variantsOf(state);
    final needsVariant = variants.length > 1 && _selectedVariant == null;

    return [
      if (state.isLoadingVariants)
        const Padding(padding: EdgeInsets.only(top: 16), child: _LoadingBar())
      else if (variants.length > 1) ...[
        const SizedBox(height: 20),
        const _FieldLabel('Variante'),
        const SizedBox(height: 8),
        _buildVariantPicker(context, variants),
      ],
      if (needsVariant)
        const _MutedHint('Elige una variante para ver el stock disponible.')
      else if (_selectedVariant != null) ...[
        const SizedBox(height: 20),
        _buildStockSection(context, state),
      ],
      if (_selectedBatch != null && _maxAvailable > 0) ...[
        const SizedBox(height: 20),
        _buildAmounts(context),
        const SizedBox(height: 20),
        _LossBar(amount: _quantity * _unitCost),
      ],
    ];
  }

  Widget _buildVariantPicker(
    BuildContext context,
    List<ProductVariantModel> variants,
  ) {
    final textTheme = Theme.of(context).textTheme;

    if (variants.length > 6) {
      return DropdownButtonFormField<ProductVariantModel>(
        key: ValueKey('variant_${_selectedVariant?.id}'),
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
          if (val == null) return;
          AppFeedbackService.lightImpact();
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
                AppFeedbackService.selectionClick();
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

  Widget _buildStockSection(BuildContext context, AddExitProductState state) {
    final product = _selectedProduct!;

    if (state.isLoadingBatches) {
      return const _LoadingBar();
    }

    final batches = _sortedBatches(state.availableBatches);
    final totalRemaining = batches.fold<double>(
      0.0,
      (sum, b) => sum + _remainingOf(b),
    );

    if (batches.isEmpty) {
      return const _NoStockBox(
        message: 'No hay stock de esta variante en el almacén de origen.',
      );
    }
    if (totalRemaining <= 0) {
      return const _NoStockBox(
        message: 'Ya agregaste todo el stock disponible de esta variante.',
      );
    }

    // Sin control por lote: solo informamos cuánto hay.
    if (!product.usesBatches) {
      final available =
          _selectedBatch != null
              ? _remainingOf(_selectedBatch!)
              : totalRemaining;
      return _StockInfo(available: available);
    }

    final hasMultipleExpiries =
        batches.where((b) => _expiryOf(b) != null).length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Lote'),
        const SizedBox(height: 8),
        ...List.generate(batches.length, (i) {
          final b = batches[i];
          final remaining = _remainingOf(b);
          final key = exitBatchKey(b);
          return Padding(
            padding: EdgeInsets.only(bottom: i == batches.length - 1 ? 0 : 8),
            child: _BatchTile(
              batchNumber: (b['batch_number'] ?? '—').toString(),
              expiry: _expiryOf(b),
              remaining: remaining,
              alreadyInList: _reserved[key] ?? 0.0,
              selected: exitBatchKey(_selectedBatch) == key && key.isNotEmpty,
              expiresFirst:
                  hasMultipleExpiries && i == 0 && _expiryOf(b) != null,
              onTap:
                  remaining > 0
                      ? () {
                        AppFeedbackService.selectionClick();
                        _selectBatch(b);
                      }
                      : null,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAmounts(BuildContext context) {
    final cost = _unitCost;
    final product = _selectedProduct!;

    final costField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Costo unitario'),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cost == 0 ? AppColors.warning : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'S/ ${cost.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        if (cost == 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Sin costo registrado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
      ],
    );

    final qtyField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Cantidad a retirar'),
        const SizedBox(height: 8),
        ExitQuantityStepper(
          key: ValueKey(
            'qty_${product.id}_${_selectedVariant?.id}_${exitBatchKey(_selectedBatch)}',
          ),
          value: _quantity,
          max: _maxAvailable,
          large: true,
          onChanged:
              (v) => setState(() {
                _quantity = v;
                _formError = null;
              }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Disponible: ${formatExitQty(_maxAvailable)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
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

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, AddExitProductState state) {
    final loading = state.isLoadingVariants || state.isLoadingBatches;
    // El botón queda activo y, al tocarlo, explica qué falta (en vez de
    // quedar gris sin decir por qué).
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
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.5),
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

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      child: LinearProgressIndicator(minHeight: 3, color: AppColors.primary),
    );
  }
}

class _MutedHint extends StatelessWidget {
  final String text;
  const _MutedHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
              Icons.outbox_rounded,
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

class _BatchTile extends StatelessWidget {
  final String batchNumber;
  final DateTime? expiry;
  final double remaining;
  final double alreadyInList;
  final bool selected;
  final bool expiresFirst;
  final VoidCallback? onTap;

  const _BatchTile({
    required this.batchNumber,
    required this.expiry,
    required this.remaining,
    required this.alreadyInList,
    required this.selected,
    required this.expiresFirst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final disabled = onTap == null;

    final subtitleParts = <String>[
      expiry != null ? 'Vence: ${_formatDate(expiry!)}' : 'Sin vencimiento',
      if (alreadyInList > 0) '${formatExitQty(alreadyInList)} ya en la lista',
    ];

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  selected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              batchNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (expiresFirst) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Vence primero',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Stock',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      formatExitQty(remaining),
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockInfo extends StatelessWidget {
  final double available;
  const _StockInfo({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stock disponible: ${formatExitQty(available)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoStockBox extends StatelessWidget {
  final String message;
  const _NoStockBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.remove_shopping_cart_outlined,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LossBar extends StatelessWidget {
  final double amount;
  const _LossBar({required this.amount});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pérdida estimada',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              'S/ ${amount.toStringAsFixed(2)}',
              key: ValueKey(amount.toStringAsFixed(2)),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.danger,
                letterSpacing: -0.3,
              ),
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

/// Espera a que el usuario deje de escribir antes de buscar.
///
/// Al destruirse completa el futuro pendiente con el valor de respaldo
/// (antes lo completaba con un error que nadie capturaba y aparecía como
/// excepción sin manejar).
class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  Completer? _completer;
  dynamic _fallback;

  _Debouncer({required this.milliseconds});

  Future<T> run<T>(Future<T> Function() action, T fallbackValue) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(_fallback);
      }
    }

    final completer = Completer<T>();
    _completer = completer;
    _fallback = fallbackValue;

    _timer = Timer(Duration(milliseconds: milliseconds), () async {
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        developer.log('Debouncer error', error: e, stackTrace: st);
        if (!completer.isCompleted) completer.complete(fallbackValue);
      }
    });

    return completer.future;
  }

  void dispose() {
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(_fallback);
    }
  }
}
