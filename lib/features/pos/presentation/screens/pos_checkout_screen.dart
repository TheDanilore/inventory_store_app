import 'dart:async';
import 'dart:developer' as developer;
import 'package:inventory_store_app/core/utils/isolate_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_client_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_points_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';
import 'package:inventory_store_app/core/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

class PosCheckoutScreen extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const PosCheckoutScreen({super.key, this.onSaleCompleted});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  // Controladores
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  Timer? _debounce;

  final _isDiscountPercentageNotifier = ValueNotifier<bool>(false);

  /// Mutex local que impide doble-ejecución de _processSale ante taps rápidos.
  /// El estado PosStatus.loading tarda un frame en propagarse al botón;
  /// este flag bloquea la re-entrada de forma síncrona e inmediata.
  bool _isProcessing = false;

  bool _isLoadingInitialData = true;

  @override
  void initState() {
    super.initState();
    final posCubit = context.read<PosCubit>();
    _clienteCtrl.text = posCubit.state.selectedClientName ?? '';
    _puntosCtrl.text = posCubit.state.puntosAUsar.toString();
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

  // CARGA DE DATOS

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
    FocusScope.of(context).unfocus();

    await posCubit.fetchClientCredit(client['id']);
  }

  //  CÁLCULOS (Movidos a PosCalculatorUtils)

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
        developer.log(
          'Error al verificar stock de carrito por almacén: ${failure.message}',
          name: 'PosCheckoutScreen._updateCartItemsStockForWarehouse',
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
        for (final item in items) {
          if (item.variantId != null) {
            final stock = stockMap[item.variantId] ?? 0;
            cartCubit.updateAvailableStock(item.cartKey, stock);
          }
        }
      },
    );
  }

  // ─── HELPER DE CÁLCULO (evita recalcular totalFinal 3× por frame) ───────────

  double _calcTotal(PosState pos, CartState cart, double ratio) {
    return PosCalculatorUtils.calcularTotalFinal(
      discountText: _descuentoCtrl.text,
      isDiscountPercentage: _isDiscountPercentageNotifier.value,
      pos: pos,
      cart: cart,
      ratio: ratio,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _processSale(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    // Mutex: bloquea re-entrada síncrona antes de que el BLoC actualice la UI.
    if (posCubit.state.status == PosStatus.loading) return;
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _processSaleInternal(posCubit, cartCubit, isDraft: isDraft);
    } finally {
      _isProcessing = false; // Sin setState para no re-renderizar todo el widget
    }
  }

  Future<void> _processSaleInternal(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    final config = context.read<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);

    // Usa el helper memoizado en lugar de invocar directamente la utilidad.
    final totalFinal = _calcTotal(
      posCubit.state,
      cartCubit.state,
      pointsToSolesRatio,
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

    if (!isDraft) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => PosConfirmationDialog(
              totalFinal: totalFinal,
              clienteName:
                  posCubit.state.selectedClientId != null
                      ? posCubit.state.selectedClientName
                      : _clienteCtrl.text.trim().isNotEmpty
                      ? _clienteCtrl.text.trim()
                      : null,
              paymentMethod: posCubit.state.paymentMethod,
            ),
      );
      if (confirmed != true) return;
    }

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
    final posCubit = context.read<PosCubit>();
    if (posCubit.state.selectedWarehouseId == null) {
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
      developer.log(
        'Error cargando lotes',
        name: 'PosCheckoutScreen',
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

  // BUILD

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

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
          final posCubit = context.read<PosCubit>();
          final cartCubit = context.read<CartCubit>();
          final orderId = state.lastOrderId!;

          posCubit.removeClient();
          posCubit.setPuntosAUsar(0);
          cartCubit.clearCart();
          posCubit.clearAllBatchOverrides();
          widget.onSaleCompleted?.call();

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => PosSuccessDialog(
                  isDraft: false,
                  onPrint: () async {
                    try {
                      final detailsRes = await posCubit
                          .fetchOrderDetailsForTicket(orderId);
                      detailsRes.fold(
                        (failure) {
                          AppSnackbar.show(
                            dialogContext,
                            message:
                                'Error cargando comprobante: ${failure.message}',
                            type: SnackbarType.error,
                          );
                        },
                        (details) async {
                          final order = details.order;
                          final items = details.items;
                          final bytes = await IsolateUtils.run(() {
                            return OrderPdfGenerator.buildPdfBytes(
                              order,
                              items: items,
                              businessName: config.businessName,
                              taxId: config.businessTaxId,
                              address: config.businessAddress,
                              phone: config.businessPhone,
                            );
                          });

                          await Printing.sharePdf(
                            bytes: bytes,
                            filename: 'Pedido_${orderId.substring(0, 8)}.pdf',
                          );
                        },
                      );
                    } catch (e, st) {
                      developer.log(
                        'Error generando comprobante',
                        name: 'PosCheckoutScreen',
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
            Navigator.pop(context, true);
          }
          posCubit.resetStatus();
        }
      },
      child: AdminLayout(
        title: 'Caja POS',
        showBackButton: true,
        body:
            _isLoadingInitialData
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
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        PosSectionLabel('Productos en caja'),
                                        BlocBuilder<CartCubit, CartState>(
                                          builder: (context, cartState) {
                                            if (cartState.items.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          return PosCartItemsSection(
                                            onShowBatchEditSheet:
                                                _showBatchEditSheet,
                                          );
                                        },
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
                              isWide: true,
                            ),
                          ),
                        ],
                      );
                    }

                    // Móvil (Columna única pero con Action Bar pegajoso al fondo)
                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    PosSectionLabel('Productos en caja'),
                                    BlocBuilder<CartCubit, CartState>(
                                      builder: (context, cartState) {
                                        if (cartState.items.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
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
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                PosCartItemsSection(
                                  onShowBatchEditSheet: _showBatchEditSheet,
                                ),
                                const SizedBox(height: 24),
                                _buildClientAndPaymentSection(
                                  pointsToSolesRatio,
                                  isLoyaltyEnabled,
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
                              (context, _) =>
                                  _buildStickyActionBar(pointsToSolesRatio),
                        ),
                      ],
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildRightPanel(
    double ratio,
    double earningRate,
    bool isLoyaltyEnabled, {
    required bool isWide,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClientAndPaymentSection(ratio, isLoyaltyEnabled),
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
          builder: (context, _) => _buildStickyActionBar(ratio),
        ),
      ],
    );
  }

  Widget _buildClientAndPaymentSection(double ratio, bool isLoyaltyEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PosSectionLabel('Cliente'),
        BlocBuilder<PosCubit, PosState>(
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
            return AdminSaleClientSection(
              controller: _clienteCtrl,
              onSearchChanged: _onClientSearchChanged,
              searching: posState.isLoading,
              matches: posState.clientMatches,
              selectedClientId: posState.selectedClientId,
              onClientTap: _selectClient,
              onClearClient: () {
                final posCubit = context.read<PosCubit>();
                posCubit.removeClient();
                posCubit.setPuntosAUsar(0);
                _clienteCtrl.clear();
              },
              saldoActualCliente: posState.saldoActualCliente,
              creditInfo: posState.creditInfo,
              isCredito: isCredito,
              isLoyaltyEnabled: isLoyaltyEnabled,
            );
          },
        ),
        BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.paymentMethod != curr.paymentMethod ||
                  prev.selectedClientId != curr.selectedClientId ||
                  prev.saldoActualCliente != curr.saldoActualCliente ||
                  prev.puntosAUsar != curr.puntosAUsar,
          builder: (context, posState) {
            final isCredito = posState.paymentMethod == 'CRÉDITO';
            return BlocSelector<CartCubit, CartState, double>(
              selector: (state) => state.totalAmount,
              builder: (context, totalAmount) {
                final cartState = context.read<CartCubit>().state;
                return AdminSalePointsSection(
                  show:
                      isLoyaltyEnabled &&
                      posState.selectedClientId != null &&
                      posState.saldoActualCliente > 0 &&
                      !isCredito,
                  saldoActualCliente: posState.saldoActualCliente,
                  maxPuntosAplicables: PosCalculatorUtils.maxPuntosAplicables(
                    posState,
                    cartState,
                    ratio,
                  ),
                  pointsToSolesRatio: ratio,
                  pointsController: _puntosCtrl,
                  onPointsChanged: (p) {
                    final posCubit = context.read<PosCubit>();
                    final next = PosCalculatorUtils.clampPointsValue(
                      p,
                      posState,
                      cartState,
                      ratio,
                    );
                    posCubit.setPuntosAUsar(next);
                    _puntosCtrl.value = TextEditingValue(
                      text: next.toString(),
                      selection: TextSelection.collapsed(
                        offset: next.toString().length,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        PosSectionLabel('Configuración de venta'),
        Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
            return PaymentWarehouseAccountCard(
              paymentMethod: posCubit.state.paymentMethod,
              warehouseList: posCubit.state.warehouses,
              selectedWarehouseId: posCubit.state.selectedWarehouseId,
              accountsList: posCubit.state.accounts,
              selectedAccountId: posCubit.state.selectedAccountId,
              activeShift: posCubit.state.activeShift,
              isCredito: isCredito,
              onCreditoToggle: (isCredito) {
                if (isCredito) {
                  posCubit.setPaymentMethod('CRÉDITO');
                  posCubit.setPuntosAUsar(0);
                  _puntosCtrl.text = '0';
                } else {
                  if (posCubit.state.selectedAccountId != null) {
                    final acc = posCubit.state.accounts.firstWhere(
                      (a) => a['id'] == posCubit.state.selectedAccountId,
                      orElse: () => {},
                    );
                    final accName = acc['name'] as String? ?? 'EFECTIVO';
                    posCubit.setPaymentMethod(accName);
                  } else {
                    posCubit.setPaymentMethod('EFECTIVO');
                  }
                }
              },
              onWarehouseChanged: (v) {
                posCubit.setWarehouse(v);
                if (v != null) {
                  _updateCartItemsStockForWarehouse(v);
                }
              },
              onAccountChanged: (v) {
                posCubit.setSelectedAccountId(v);
                if (v != null) {
                  final acc = posCubit.state.accounts.firstWhere(
                    (a) => a['id'] == v,
                    orElse: () => {},
                  );
                  final accName = acc['name'] as String? ?? 'OTRO';
                  posCubit.setPaymentMethod(accName);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummarySection(
    double ratio,
    double earningRate,
    bool isLoyaltyEnabled,
  ) {
    return Builder(
      builder: (context) {
        final posCubit = context.watch<PosCubit>();
        final cartCubit = context.watch<CartCubit>();
        final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
        final puntosSeguros = PosCalculatorUtils.clampPointsValue(
          posCubit.state.puntosAUsar,
          posCubit.state,
          cartCubit.state,
          ratio,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCredito) ...[
              _CreditWarningCard(
                clienteSeleccionado: posCubit.state.selectedClientId != null,
                creditActivo: PosCalculatorUtils.isCreditActivo(
                  posCubit.state.creditInfo,
                ),
                creditDisponible: PosCalculatorUtils.getCreditDisponible(
                  posCubit.state.creditInfo,
                ),
                totalFinal: PosCalculatorUtils.calcularTotalFinal(
                  discountText: _descuentoCtrl.text,
                  isDiscountPercentage: _isDiscountPercentageNotifier.value,
                  pos: posCubit.state,
                  cart: cartCubit.state,
                  ratio: ratio,
                ),
                creditInfo: posCubit.state.creditInfo,
              ),
              const SizedBox(height: 24),
            ],

            if (!isCredito) ...[
              _buildCustomDiscountCard(
                posCubit.state,
                cartCubit.state,
                ratio,
                puntosSeguros,
              ),
              const SizedBox(height: 24),
            ],

            PosTotalSummarySection(
              subtotalAntesDePuntos: cartCubit.state.totalAmount,
              puntosAplicables:
                  isCredito || !isLoyaltyEnabled ? 0 : puntosSeguros,
              descuentoPuntos:
                  isCredito || !isLoyaltyEnabled ? 0 : puntosSeguros * ratio,
              isLoyaltyEnabled: isLoyaltyEnabled,
              descuentoExtra:
                  isCredito
                      ? 0
                      : PosCalculatorUtils.getCustomDiscountAmount(
                        discountText: _descuentoCtrl.text,
                        isDiscountPercentage:
                            _isDiscountPercentageNotifier.value,
                        pos: posCubit.state,
                        cart: cartCubit.state,
                        ratio: ratio,
                      ),
              totalFinal: PosCalculatorUtils.calcularTotalFinal(
                discountText: _descuentoCtrl.text,
                isDiscountPercentage: _isDiscountPercentageNotifier.value,
                pos: posCubit.state,
                cart: cartCubit.state,
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
  }

  Widget _buildCustomDiscountCard(
    PosState posState,
    CartState cartState,
    double ratio,
    int puntosSeguros,
  ) {
    final descuentoExtra = PosCalculatorUtils.getCustomDiscountAmount(
      discountText: _descuentoCtrl.text,
      isDiscountPercentage: _isDiscountPercentageNotifier.value,
      pos: posState,
      cart: cartState,
      ratio: ratio,
    );
    final maxAllowed = cartState.totalAmount - (puntosSeguros * ratio);
    final descuentoExcedido = descuentoExtra > maxAllowed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: descuentoExcedido ? AppColors.danger : Colors.grey.shade200,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Text(
                'Descuento Extra',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _descuentoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // Restringe la entrada a números con máximo 2 decimales.
                    // Elimina el callback vacío onChanged — el ListenableBuilder
                    // padre ya reacciona al controller automáticamente.
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => _isDiscountPercentageNotifier.value = false,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color:
                                  !_isDiscountPercentageNotifier.value
                                      ? Colors.white
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                              boxShadow:
                                  !_isDiscountPercentageNotifier.value
                                      ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ]
                                      : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'S/',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    !_isDiscountPercentageNotifier.value
                                        ? AppColors.primary
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              () => _isDiscountPercentageNotifier.value = true,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color:
                                  _isDiscountPercentageNotifier.value
                                      ? Colors.white
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                              boxShadow:
                                  _isDiscountPercentageNotifier.value
                                      ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ]
                                      : [],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "%",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _isDiscountPercentageNotifier.value
                                        ? AppColors.primary
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (descuentoExcedido)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "No puede superar los S/ ${maxAllowed.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(double ratio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final cartCubit = context.watch<CartCubit>();
            final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
            final puntosSeguros = PosCalculatorUtils.clampPointsValue(
              posCubit.state.puntosAUsar,
              posCubit.state,
              cartCubit.state,
              ratio,
            );
            final descuentoExtra = PosCalculatorUtils.getCustomDiscountAmount(
              discountText: _descuentoCtrl.text,
              isDiscountPercentage: _isDiscountPercentageNotifier.value,
              pos: posCubit.state,
              cart: cartCubit.state,
              ratio: ratio,
            );
            final descuentoExcedido =
                descuentoExtra >
                (cartCubit.state.totalAmount - (puntosSeguros * ratio));

            // Usa el helper _calcTotal para no recalcular el total 3 veces por frame.
            final totalFinal = _calcTotal(
              posCubit.state,
              cartCubit.state,
              ratio,
            );

            final disp = PosCalculatorUtils.getCreditDisponible(
              posCubit.state.creditInfo,
            );
            final creditoInsuficiente =
                isCredito &&
                posCubit.state.selectedClientId != null &&
                PosCalculatorUtils.isCreditActivo(posCubit.state.creditInfo) &&
                disp < totalFinal;
            final creditoSinCliente =
                isCredito && posCubit.state.selectedClientId == null;

            // Unificado con la misma lógica booleana que usa _processSale,
            // eliminando el magic string 'CAJA' que era inconsistente.
            final accountData = posCubit.state.accounts.firstWhere(
              (a) => a['id'] == posCubit.state.selectedAccountId,
              orElse: () => {},
            );
            final requiresShift =
                accountData['is_cash_register'] == true ||
                accountData['requires_shift'] == true;
            final noCajaAbierta =
                !isCredito &&
                posCubit.state.selectedAccountId != null &&
                requiresShift &&
                posCubit.state.activeShift == null;

            final puedeVender =
                cartCubit.state.items.isNotEmpty &&
                !descuentoExcedido &&
                !creditoInsuficiente &&
                !creditoSinCliente &&
                !noCajaAbierta;

            // Combina el estado del BLoC con el mutex local para máxima seguridad.
            final isProcessingSale =
                posCubit.state.status == PosStatus.loading || _isProcessing;

            return Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PosConfirmButton(
                        loading: isProcessingSale,
                        enabled: puedeVender,
                        label:
                            isCredito
                                ? 'Vender a crédito'
                                : 'Cobrar (S/ ${totalFinal.toStringAsFixed(2)})',
                        onPressed:
                            () => _processSale(
                              posCubit,
                              cartCubit,
                              isDraft: false,
                            ),
                      ),
                    ),
                    if (!isCredito) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Tooltip(
                          message: 'Guardar borrador',
                          child: OutlinedButton(
                            onPressed:
                                (isProcessingSale ||
                                        cartCubit.state.items.isEmpty ||
                                        descuentoExcedido)
                                    ? null
                                    : () => _processSale(
                                      posCubit,
                                      cartCubit,
                                      isDraft: true,
                                    ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              padding: EdgeInsets.zero,
                              side: BorderSide(
                                color: AppColors.teal.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                              ),
                            ),
                            child: const Icon(Icons.save_as_rounded, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isProcessingSale)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.5),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CreditWarningCard extends StatelessWidget {
  final bool clienteSeleccionado;
  final bool creditActivo;
  final double creditDisponible;
  final double totalFinal;
  final Map<String, dynamic>? creditInfo;

  const _CreditWarningCard({
    required this.clienteSeleccionado,
    required this.creditActivo,
    required this.creditDisponible,
    required this.totalFinal,
    required this.creditInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (!clienteSeleccionado) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepOrange.shade50,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: Colors.deepOrange.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.deepOrange, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Debes seleccionar un cliente para ventas a crédito.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!creditActivo) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.red, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Este cliente no tiene línea de crédito activa.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final limit = (creditInfo!['credit_limit'] as num).toDouble();
    final debt = (creditInfo!['current_debt'] as num).toDouble();
    final insuficiente = creditDisponible < totalFinal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: insuficiente ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: insuficiente ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                insuficiente
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: insuficiente ? Colors.red : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                insuficiente ? 'Crédito insuficiente' : 'Crédito disponible',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: insuficiente ? Colors.red : Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Límite',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${limit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deuda actual',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${debt.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disponible',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${creditDisponible.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color:
                            insuficiente ? Colors.red : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (insuficiente)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Necesitas S/ ${totalFinal.toStringAsFixed(2)} pero solo hay S/ ${creditDisponible.toStringAsFixed(2)} disponibles.',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
