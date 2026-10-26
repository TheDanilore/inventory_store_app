import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_receipt_export_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_client_header_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_credit_warning_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_custom_discount_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_payment_and_config_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_sticky_action_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';

class PosCheckoutScreen extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const PosCheckoutScreen({super.key, this.onSaleCompleted});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  // Controladores y Formulario
  final _formKey = GlobalKey<FormState>();
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  Timer? _debounce;
  final _isDiscountPercentageNotifier = ValueNotifier<bool>(false);

  /// Mutex local que impide doble-ejecución de _processSale ante taps rápidos.
  bool _isProcessing = false;
  bool _isOpeningBatchSheet = false;
  bool _isLoadingInitialData = false;

  bool _lastSaleWasDraft = false;
  double _lastSaleTotalAmount = 0.0;
  double? _lastSaleAmountReceived;
  String _lastSalePaymentMethod = 'EFECTIVO';
  String _lastSaleCustomerName = 'Cliente Varios';
  String _lastSaleDocumentType = 'NOTA_VENTA';
  String? _lastSaleDocumentSeries;
  String? _lastSalePaymentReference;
  String _lastSaleCurrency = 'PEN';
  Map<String, int> _lastSoldQuantities = {};

  @override
  void initState() {
    super.initState();
    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();

    _clienteCtrl.text = posCubit.state.selectedClientName ?? '';
    _puntosCtrl.text = posCubit.state.puntosAUsar.toString();

    // SWR Pattern: Si ya hay almacenes o cuentas en memoria, o productos en el carrito,
    // jamás mostrar shimmer obstructivo de pantalla completa.
    final hasCachedData =
        (posCubit.state.warehouses.isNotEmpty &&
            posCubit.state.accounts.isNotEmpty) ||
        cartCubit.state.items.isNotEmpty;

    _isLoadingInitialData = !hasCachedData;
    _loadInitialData(posCubit);
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _puntosCtrl.dispose();
    _descuentoCtrl.dispose();
    _isDiscountPercentageNotifier.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── CARGA DE DATOS ──────────────────────────────────────────────────────────

  Future<void> _loadInitialData(PosCubit posCubit) async {
    try {
      await posCubit.initPosData();
      if (posCubit.state.selectedClientId != null) {
        await posCubit.fetchClientCredit(posCubit.state.selectedClientId!);
      }
      if (posCubit.state.selectedWarehouseId != null) {
        await _updateCartItemsStockForWarehouse(
          posCubit.state.selectedWarehouseId!,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
    }
  }

  void _onClientSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchClients(query);
    });
  }

  Future<void> _searchClients(String query) async {
    await context.read<PosCubit>().searchClients(query);
  }

  Future<void> _selectClient(Map<String, dynamic> client) async {
    final posCubit = context.read<PosCubit>();
    posCubit.setClient(
      client['id'],
      client['full_name'],
      client['points_balance'] ?? 0,
    );
    _clienteCtrl.text = client['full_name'];
    if (mounted) setState(() {});
    FocusScope.of(context).unfocus();

    await posCubit.fetchClientCredit(client['id']);
  }

  void _clearClient() {
    final posCubit = context.read<PosCubit>();
    posCubit.removeClient();
    posCubit.setPuntosAUsar(0);
    _clienteCtrl.clear();
    _puntosCtrl.text = '0';
    if (mounted) setState(() {});
  }

  Future<void> _openCameraScanner() async {
    final warehouseId = context.read<PosCubit>().state.selectedWarehouseId;
    final cartCubit = context.read<CartCubit>();
    await PosBarcodeScannerService.openCameraScanner(
      context: context,
      cartCubit: cartCubit,
      warehouseId: warehouseId,
    );
  }

  Future<void> _updateCartItemsStockForWarehouse(String warehouseId) async {
    final cartCubit = context.read<CartCubit>();
    final items = cartCubit.state.items.values.toList();
    if (items.isEmpty) return;

    final variantIds =
        items
            .where((i) => i.variantId != null && i.variantId!.isNotEmpty)
            .map((i) => i.variantId!)
            .toSet()
            .toList();

    if (variantIds.isEmpty) return;

    final repo = sl<ProductsRepository>();
    final res = await repo.fetchVariantStockByVariantIds(
      variantIds,
      warehouseId: warehouseId,
    );

    res.fold(
      (failure) {
        LoggerService.e(
          'Error al verificar stock de carrito por almacén: ${failure.message}',
          tag: 'PosCheckoutScreen',
          error: failure.message,
        );
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Alerta al verificar stock: ${failure.message}',
            type: SnackbarType.warning,
          );
        }
      },
      (stockMap) {
        cartCubit.updateBatchAvailableStock(stockMap);
      },
    );
  }

  // ─── PROCESO DE VENTA ────────────────────────────────────────────────────────

  Future<void> _processSale(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    if (posCubit.state.status == PosStatus.loading) return;
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _processSaleInternal(posCubit, cartCubit, isDraft: isDraft);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processSaleInternal(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final config = context.read<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);

    final totalFinal = PosCalculatorUtils.calcularTotalFinal(
      discountText: _descuentoCtrl.text,
      isDiscountPercentage: _isDiscountPercentageNotifier.value,
      pos: posCubit.state,
      cart: cartCubit.state,
      ratio: pointsToSolesRatio,
    );

    final validationError = PosCalculatorUtils.validateSalePreFlight(
      posState: posCubit.state,
      cartState: cartCubit.state,
      totalFinal: totalFinal,
      isDraft: isDraft,
    );
    if (validationError != null) {
      AppSnackbar.show(
        context,
        message: validationError,
        type: SnackbarType.error,
      );
      return;
    }

    final clientName =
        _clienteCtrl.text.trim().isNotEmpty
            ? _clienteCtrl.text.trim()
            : (posCubit.state.selectedClientName ?? 'Cliente Varios');
    final currency = posCubit.state.currencyCode == 'USD' ? '\$' : 'S/';

    double? confirmedAmountReceived;
    if (!isDraft) {
      confirmedAmountReceived = await PosConfirmationDialog.show(
        context,
        totalFinal: totalFinal,
        paymentMethod: posCubit.state.paymentMethod,
        documentType: posCubit.state.documentType,
        documentSeries: posCubit.state.effectiveSeries,
        clienteName: clientName,
        currencySymbol: currency,
      );

      if (confirmedAmountReceived == null) {
        return;
      }
    }

    _lastSaleWasDraft = isDraft;
    _lastSaleTotalAmount = totalFinal;
    _lastSaleAmountReceived = confirmedAmountReceived;
    _lastSalePaymentMethod = posCubit.state.paymentMethod;
    _lastSaleCustomerName = clientName;
    _lastSaleDocumentType = posCubit.state.documentType;
    _lastSaleDocumentSeries = posCubit.state.effectiveSeries;
    _lastSalePaymentReference = posCubit.state.paymentReference;
    _lastSaleCurrency = posCubit.state.currencyCode;
    _lastSoldQuantities = {
      for (final item in cartCubit.state.items.values)
        item.productId: item.quantity,
    };

    posCubit.setDiscountText(_descuentoCtrl.text);
    posCubit.setIsDiscountPercentage(_isDiscountPercentageNotifier.value);

    await posCubit.processSale(
      cartState: cartCubit.state,
      pointsToSolesRatio: pointsToSolesRatio,
      earningRate: earningRate,
      customClientName:
          _clienteCtrl.text.trim().isNotEmpty ? _clienteCtrl.text.trim() : null,
      accountId: posCubit.state.selectedAccountId,
      activeShift: posCubit.state.activeShift,
      isDraft: isDraft,
    );
  }

  Future<void> _showBatchEditSheet(CartItemEntity item) async {
    if (_isOpeningBatchSheet) return;
    _isOpeningBatchSheet = true;

    final posCubit = context.read<PosCubit>();
    if (posCubit.state.selectedWarehouseId == null) {
      _isOpeningBatchSheet = false;
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacén primero',
        type: SnackbarType.warning,
      );
      return;
    }

    try {
      final batchesResult = await posCubit.fetchBatchesForVariant(
        item.variantId!,
        posCubit.state.selectedWarehouseId!,
      );

      batchesResult.fold(
        (failure) {
          if (!mounted) return;
          AppSnackbar.show(
            context,
            message: 'Error cargando lotes: ${failure.message}',
            type: SnackbarType.error,
          );
        },
        (batches) async {
          if (batches.isEmpty) {
            if (!mounted) return;
            AppSnackbar.show(
              context,
              message: 'No hay lotes con stock para este producto.',
              type: SnackbarType.warning,
            );
            return;
          }

          final saved = posCubit.state.batchOverrides[item.cartKey];
          if (saved != null) {
            for (final s in saved) {
              final idx = batches.indexWhere((b) => b.batchId == s.batchId);
              if (idx >= 0) batches[idx].assigned = s.assigned;
            }
          } else {
            int remaining = item.quantity;
            for (final b in batches) {
              if (remaining <= 0) break;
              b.assigned = (remaining > b.available) ? b.available : remaining;
              remaining -= b.assigned;
            }
          }

          if (!mounted) return;
          final result = await BatchEditSheet.show(
            context,
            productName: item.productName,
            variantLabel: item.variantLabel,
            totalRequired: item.quantity,
            batches: batches,
          );

          if (result != null && mounted) {
            if (result.isEmpty) {
              posCubit.clearBatchOverride(item.cartKey);
              AppSnackbar.show(
                context,
                message: 'Restablecido a FEFO automático',
                type: SnackbarType.info,
              );
            } else {
              posCubit.setBatchOverride(item.cartKey, result);
            }
          }
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error cargando lotes',
        tag: 'PosCheckoutScreen',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando lotes: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) _isOpeningBatchSheet = false;
    }
  }

  Future<void> _onClearCart() async {
    final cartCubit = context.read<CartCubit>();
    if (cartCubit.state.items.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Vaciar Caja',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              '¿Estás seguro de que deseas eliminar todos los productos de la caja actual?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Vaciar Todo'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      cartCubit.clearCart();
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pointsToSolesRatio = context.select<AppConfigCubit, double>(
      (c) => c.getDouble('points_to_soles_ratio', 0.01),
    );
    final earningRate = context.select<AppConfigCubit, double>(
      (c) => c.getDouble('points_earning_rate', 0.03),
    );
    final isLoyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.loyaltyGlobalEnabled,
    );

    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();

    // Si el sistema de fidelidad está desactivado globalmente y hay puntos asignados, purgarlos
    if (!isLoyaltyEnabled && posCubit.state.puntosAUsar > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && posCubit.state.puntosAUsar > 0) {
          posCubit.setPuntosAUsar(0);
          _puntosCtrl.text = '0';
        }
      });
    }

    // SWR Verification en build: Si hay datos en memoria en los BLoCs, NUNCA bloquear con Shimmer.
    final hasDataInCache =
        (posCubit.state.warehouses.isNotEmpty &&
            posCubit.state.accounts.isNotEmpty) ||
        cartCubit.state.items.isNotEmpty;
    final showShimmer = _isLoadingInitialData && !hasDataInCache;

    return BlocListener<PosCubit, PosState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        if (state.status == PosStatus.error) {
          AppSnackbar.show(
            context,
            message: state.errorMessage,
            type: SnackbarType.error,
          );
          context.read<PosCubit>().resetStatus();
        } else if (state.status == PosStatus.success &&
            state.lastOrderId != null) {
          final orderId = state.lastOrderId!;

          posCubit.removeClient();
          posCubit.setPuntosAUsar(0);
          posCubit.setPaymentReference(null);
          cartCubit.clearCart();
          posCubit.clearAllBatchOverrides();
          widget.onSaleCompleted?.call();

          if (posCubit.state.selectedAccountId != null && !_lastSaleWasDraft) {
            posCubit.updateAccountBalanceLocal(
              accountId: posCubit.state.selectedAccountId!,
              deltaAmount: _lastSaleTotalAmount,
            );
          }

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => PosSuccessDialog(
                  isDraft: _lastSaleWasDraft,
                  totalAmount: _lastSaleTotalAmount,
                  amountReceived: _lastSaleAmountReceived,
                  paymentMethod: _lastSalePaymentMethod,
                  customerName: _lastSaleCustomerName,
                  documentType: _lastSaleDocumentType,
                  documentSeries: _lastSaleDocumentSeries,
                  paymentReference: _lastSalePaymentReference,
                  currencySymbol: _lastSaleCurrency == 'USD' ? '\$' : 'S/',
                  onPrint: () async {
                    try {
                      final detailsRes = await posCubit
                          .fetchOrderDetailsForTicket(orderId);

                      await detailsRes.fold<Future<void>>(
                        (failure) async {
                          if (dialogContext.mounted) {
                            AppSnackbar.show(
                              dialogContext,
                              message:
                                  'Error cargando comprobante: ${failure.message}',
                              type: SnackbarType.error,
                            );
                          }
                        },
                        (details) async {
                          if (dialogContext.mounted) {
                            await OrderReceiptExportSheet.show(
                              dialogContext,
                              order: details.order,
                              initialItems: details.items,
                              isSaleSuccess: true,
                            );
                          }
                        },
                      );
                    } catch (e, st) {
                      LoggerService.e(
                        'Error generando comprobante',
                        tag: 'PosCheckoutScreen',
                        error: e,
                        stackTrace: st,
                      );
                      if (dialogContext.mounted) {
                        AppSnackbar.show(
                          dialogContext,
                          message: 'Error generando comprobante: $e',
                          type: SnackbarType.error,
                        );
                      }
                    }
                  },
                ),
          );
          if (context.mounted) {
            Navigator.pop(context, _lastSoldQuantities);
          }
          posCubit.resetStatus();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Volver a Caja',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/pos');
              }
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cobrar Venta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          actions: [
            BlocSelector<CartCubit, CartState, int>(
              selector:
                  (cart) => cart.items.values.fold<int>(
                    0,
                    (sum, i) => sum + i.quantity,
                  ),
              builder: (context, count) {
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        size: 14,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$count ${count == 1 ? "ítem" : "ítems"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child:
              showShimmer
                  ? ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, _) => const AppShimmer(height: 120),
                  )
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Izquierda: Carrito
                            Expanded(
                              flex: 5,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCartHeader(),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: PosCartItemsSection(
                                          onShowBatchEditSheet:
                                              _showBatchEditSheet,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Derecha: Pago, Cliente, Resumen, Action Bar
                            Expanded(
                              flex: 4,
                              child: _buildRightPanel(
                                pointsToSolesRatio,
                                earningRate,
                                isLoyaltyEnabled,
                              ),
                            ),
                          ],
                        );
                      }

                      // Móvil: Columna única con Action Bar inferior
                      return Column(
                        children: [
                          _buildClientHeader(isLoyaltyEnabled),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCartHeader(),
                                  PosCartItemsSection(
                                    onShowBatchEditSheet: _showBatchEditSheet,
                                  ),
                                  const SizedBox(height: 20),
                                  PosPaymentAndConfigSection(
                                    ratio: pointsToSolesRatio,
                                    isLoyaltyEnabled: isLoyaltyEnabled,
                                    pointsController: _puntosCtrl,
                                    onWarehouseChanged: (v) {
                                      posCubit.setWarehouse(v);
                                      if (v != null) {
                                        _updateCartItemsStockForWarehouse(v);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  ListenableBuilder(
                                    listenable: Listenable.merge([
                                      _descuentoCtrl,
                                      _isDiscountPercentageNotifier,
                                    ]),
                                    builder: (context, _) {
                                      return _buildSummarySection(
                                        pointsToSolesRatio,
                                        earningRate,
                                        isLoyaltyEnabled,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              _descuentoCtrl,
                              _isDiscountPercentageNotifier,
                            ]),
                            builder:
                                (context, _) => PosStickyActionBar(
                                  ratio: pointsToSolesRatio,
                                  discountText: _descuentoCtrl.text,
                                  isDiscountPercentage:
                                      _isDiscountPercentageNotifier.value,
                                  isProcessingLocal: _isProcessing,
                                  onProcessSale:
                                      ({required bool isDraft}) => _processSale(
                                        posCubit,
                                        cartCubit,
                                        isDraft: isDraft,
                                      ),
                                ),
                          ),
                        ],
                      );
                    },
                  ),
        ),
      ),
    );
  }

  Widget _buildCartHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PosSectionLabel('Productos en caja'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Escanear código de barra / QR',
                child: TextButton.icon(
                  onPressed: _openCameraScanner,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.teal,
                    size: 18,
                  ),
                  label: const Text(
                    'Escanear',
                    style: TextStyle(
                      color: AppColors.teal,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BlocSelector<CartCubit, CartState, bool>(
                selector: (cart) => cart.items.isEmpty,
                builder: (context, isEmpty) {
                  if (isEmpty) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: _onClearCart,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    label: const Text(
                      'Vaciar Todo',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(
    double ratio,
    double earningRate,
    bool isLoyaltyEnabled,
  ) {
    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();

    return Column(
      children: [
        _buildClientHeader(isLoyaltyEnabled),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosPaymentAndConfigSection(
                  ratio: ratio,
                  isLoyaltyEnabled: isLoyaltyEnabled,
                  pointsController: _puntosCtrl,
                  onWarehouseChanged: (v) {
                    posCubit.setWarehouse(v);
                    if (v != null) {
                      _updateCartItemsStockForWarehouse(v);
                    }
                  },
                ),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    _descuentoCtrl,
                    _isDiscountPercentageNotifier,
                  ]),
                  builder: (context, _) {
                    return _buildSummarySection(
                      ratio,
                      earningRate,
                      isLoyaltyEnabled,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([
            _descuentoCtrl,
            _isDiscountPercentageNotifier,
          ]),
          builder:
              (context, _) => PosStickyActionBar(
                ratio: ratio,
                discountText: _descuentoCtrl.text,
                isDiscountPercentage: _isDiscountPercentageNotifier.value,
                isProcessingLocal: _isProcessing,
                onProcessSale:
                    ({required bool isDraft}) =>
                        _processSale(posCubit, cartCubit, isDraft: isDraft),
              ),
        ),
      ],
    );
  }

  Widget _buildClientHeader(bool isLoyaltyEnabled) {
    return BlocBuilder<PosCubit, PosState>(
      buildWhen:
          (prev, curr) =>
              prev.paymentMethod != curr.paymentMethod ||
              prev.isLoading != curr.isLoading ||
              prev.clientMatches != curr.clientMatches ||
              prev.selectedClientId != curr.selectedClientId ||
              prev.saldoActualCliente != curr.saldoActualCliente ||
              prev.creditInfo != curr.creditInfo,
      builder: (context, posState) {
        final isCredito = posState.paymentMethod == 'CRÉDITO';
        return BlocSelector<CartCubit, CartState, (int, bool)>(
          selector:
              (cart) => (
                cart.items.values.fold<int>(
                  0,
                  (sum, item) => sum + item.quantity,
                ),
                cart.items.isEmpty,
              ),
          builder: (context, cartTuple) {
            final (totalItems, isCartEmpty) = cartTuple;
            return PosClientHeaderBar(
              controller: _clienteCtrl,
              onSearchChanged: _onClientSearchChanged,
              searching: posState.isLoading,
              matches: posState.clientMatches,
              selectedClientId: posState.selectedClientId,
              onClientTap: _selectClient,
              onClearClient: _clearClient,
              saldoActualCliente: posState.saldoActualCliente,
              creditInfo: posState.creditInfo,
              isCredito: isCredito,
              isLoyaltyEnabled: isLoyaltyEnabled,
              cartItemCount: totalItems,
              isCartEmpty: isCartEmpty,
              onClearCart: _onClearCart,
              showCajaHeader: false,
            );
          },
        );
      },
    );
  }

  Widget _buildSummarySection(
    double ratio,
    double earningRate,
    bool isLoyaltyEnabled,
  ) {
    return BlocBuilder<PosCubit, PosState>(
      buildWhen:
          (prev, curr) =>
              prev.paymentMethod != curr.paymentMethod ||
              prev.puntosAUsar != curr.puntosAUsar ||
              prev.selectedClientId != curr.selectedClientId ||
              prev.saldoActualCliente != curr.saldoActualCliente ||
              prev.creditInfo != curr.creditInfo,
      builder: (context, posState) {
        return BlocBuilder<CartCubit, CartState>(
          buildWhen: (prev, curr) => prev.totalAmount != curr.totalAmount,
          builder: (context, cartState) {
            final isCredito = posState.paymentMethod == 'CRÉDITO';
            final puntosSeguros = PosCalculatorUtils.clampPointsValue(
              posState.puntosAUsar,
              posState,
              cartState,
              ratio,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCredito) ...[
                  PosCreditWarningCard(
                    clienteSeleccionado: posState.selectedClientId != null,
                    creditActivo: PosCalculatorUtils.isCreditActivo(
                      posState.creditInfo,
                    ),
                    creditDisponible: PosCalculatorUtils.getCreditDisponible(
                      posState.creditInfo,
                    ),
                    totalFinal: PosCalculatorUtils.calcularTotalFinal(
                      discountText: _descuentoCtrl.text,
                      isDiscountPercentage: _isDiscountPercentageNotifier.value,
                      pos: posState,
                      cart: cartState,
                      ratio: ratio,
                    ),
                    creditInfo: posState.creditInfo,
                  ),
                  const SizedBox(height: 24),
                ],

                if (!isCredito) ...[
                  PosCustomDiscountCard(
                    discountController: _descuentoCtrl,
                    isPercentageNotifier: _isDiscountPercentageNotifier,
                    posState: posState,
                    cartState: cartState,
                    ratio: ratio,
                    puntosSeguros: puntosSeguros,
                  ),
                  const SizedBox(height: 24),
                ],

                PosTotalSummarySection(
                  subtotalAntesDePuntos: cartState.totalAmount,
                  puntosAplicables:
                      isCredito || !isLoyaltyEnabled ? 0 : puntosSeguros,
                  descuentoPuntos:
                      isCredito || !isLoyaltyEnabled
                          ? 0
                          : puntosSeguros * ratio,
                  isLoyaltyEnabled: isLoyaltyEnabled,
                  descuentoExtra:
                      isCredito
                          ? 0
                          : PosCalculatorUtils.getCustomDiscountAmount(
                            discountText: _descuentoCtrl.text,
                            isDiscountPercentage:
                                _isDiscountPercentageNotifier.value,
                            pos: posState,
                            cart: cartState,
                            ratio: ratio,
                          ),
                  totalFinal: PosCalculatorUtils.calcularTotalFinal(
                    discountText: _descuentoCtrl.text,
                    isDiscountPercentage: _isDiscountPercentageNotifier.value,
                    pos: posState,
                    cart: cartState,
                    ratio: ratio,
                  ),
                  pointsToSolesRatio: ratio,
                  earningRate: earningRate,
                  isCredito: isCredito,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
