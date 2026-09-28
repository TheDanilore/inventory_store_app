import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';

import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_client_header_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_points_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/core/widgets/batch_edit_sheet.dart';

class DesktopPosPanel extends StatefulWidget {
  final ValueChanged<Map<String, int>>? onSaleCompleted;

  const DesktopPosPanel({super.key, this.onSaleCompleted});

  @override
  State<DesktopPosPanel> createState() => DesktopPosPanelState();
}

class DesktopPosPanelState extends State<DesktopPosPanel> {
  // Controladores
  final _formKey = GlobalKey<FormState>();
  final _clientHeaderBarKey = GlobalKey<PosClientHeaderBarState>();
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  Timer? _debounce;
  bool _lastSaleWasDraft = false;
  double _lastSaleTotalAmount = 0.0;
  Map<String, int> _lastSoldQuantities = {};

  /// Mutex local anti-doble-tap que previene la ejecución simultánea de ventas.
  bool _isProcessing = false;

  void openClientSearch() {
    _clientHeaderBarKey.currentState?.openSearch();
  }

  @override
  void initState() {
    super.initState();
    final posCubit = context.read<PosCubit>();
    _clienteCtrl.text = posCubit.state.selectedClientName ?? '';
    _puntosCtrl.text = posCubit.state.puntosAUsar.toString();
    _descuentoCtrl.text = posCubit.state.discountText;

    // Iniciar carga de datos si aún no se ha hecho
    if (posCubit.state.warehouses.isEmpty) {
      posCubit.initPosData();
    }
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _puntosCtrl.dispose();
    _descuentoCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onClientSearchChanged(String query) {
    final posCubit = context.read<PosCubit>();
    if (posCubit.state.selectedClientId != null) {
      posCubit.removeClient();
      _puntosCtrl.text = '0';
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => posCubit.searchClients(query),
    );
  }

  void _selectClient(Map<String, dynamic> client) {
    final posCubit = context.read<PosCubit>();
    final id = client['id'] as String;
    posCubit.setClient(
      id,
      client['full_name'] ?? '',
      (client['wallet_balance'] as num?)?.toInt() ?? 0,
    );
    _clienteCtrl.text = client['full_name'] ?? '';
    _puntosCtrl.text = '0';
    FocusScope.of(context).unfocus();
    posCubit.fetchClientCredit(id);
    if (mounted) setState(() {});
  }

  void _clearClient() {
    final posCubit = context.read<PosCubit>();
    posCubit.removeClient();
    _clienteCtrl.clear();
    _puntosCtrl.text = '0';
    if (mounted) setState(() {});
  }

  /// Invocado externamente (ej: atajo de teclado F2) para iniciar el cobro sin usar el mouse.
  void triggerCheckout() {
    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();
    if (cartCubit.state.items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No hay productos en la caja para cobrar',
        type: SnackbarType.warning,
      );
      return;
    }
    _processSale(posCubit, cartCubit, isDraft: false);
  }

  /// Invocado externamente (ej: atajo de teclado Alt+B) para guardar borrador.
  void triggerDraft() {
    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();
    if (cartCubit.state.items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No hay productos en la caja para guardar como borrador',
        type: SnackbarType.warning,
      );
      return;
    }
    _processSale(posCubit, cartCubit, isDraft: true);
  }

  Future<void> _processSale(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _processSaleInternal(posCubit, cartCubit, isDraft: isDraft);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processSaleInternal(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final config = context.read<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);

    final totalFinal = PosCalculatorUtils.calcularTotalFinal(
      discountText: posCubit.state.discountText,
      isDiscountPercentage: posCubit.state.isDiscountPercentage,
      pos: posCubit.state,
      cart: cartCubit.state,
      ratio: pointsToSolesRatio,
    );
    _lastSaleTotalAmount = totalFinal;

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

    _lastSaleWasDraft = isDraft;
    _lastSoldQuantities = {
      for (final item in cartCubit.state.items.values)
        item.productId: item.quantity,
    };

    posCubit.processSale(
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
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error cargando lotes en DesktopPosPanel',
        tag: 'DesktopPosPanel',
        error: e,
        stackTrace: stackTrace,
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

  @override
  Widget build(BuildContext context) {
    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();
    final pointsToSolesRatio = context.select<AppConfigCubit, double>(
      (c) => c.getDouble('points_to_soles_ratio', 0.01),
    );
    final earningRate = context.select<AppConfigCubit, double>(
      (c) => c.getDouble('points_earning_rate', 0.03),
    );
    final isLoyaltyEnabled = context.select<AppConfigCubit, bool>(
      (c) => c.loyaltyGlobalEnabled,
    );

    // Si el sistema de fidelidad está desactivado globalmente y hay puntos asignados, purgarlos
    if (!isLoyaltyEnabled && posCubit.state.puntosAUsar > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && posCubit.state.puntosAUsar > 0) {
          posCubit.setPuntosAUsar(0);
          _puntosCtrl.text = '0';
        }
      });
    }

    return BlocListener<PosCubit, PosState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        if (state.status == PosStatus.error) {
          AppSnackbar.show(
            context,
            message: state.errorMessage,
            type: SnackbarType.error,
          );
        } else if (state.status == PosStatus.success &&
            state.lastOrderId != null) {
          final orderId = state.lastOrderId!;

          posCubit.removeClient();
          posCubit.setPuntosAUsar(0);
          posCubit.setDiscountText('');
          cartCubit.clearCart();
          posCubit.clearAllBatchOverrides();

          // Limpiar controladores de texto independientes del estado Cubit
          _clienteCtrl.clear();
          _puntosCtrl.text = '0';
          _descuentoCtrl.clear();

          // Refrescar saldos de cuenta de manera local y optimista sin data egress
          if (posCubit.state.selectedAccountId != null && !_lastSaleWasDraft) {
            posCubit.updateAccountBalanceLocal(
              accountId: posCubit.state.selectedAccountId!,
              deltaAmount: _lastSaleTotalAmount,
            );
          }

          widget.onSaleCompleted?.call(_lastSoldQuantities);

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => PosSuccessDialog(
                  isDraft: _lastSaleWasDraft,
                  onPrint: () async {
                    try {
                      final fetchResult = await posCubit
                          .fetchOrderDetailsForTicket(orderId);
                      fetchResult.fold(
                        (failure) {
                          if (dialogContext.mounted) {
                            AppSnackbar.show(
                              dialogContext,
                              message:
                                  'Error al obtener orden: ${failure.message}',
                              type: SnackbarType.error,
                            );
                          }
                        },
                        (result) async {
                          final config = context.read<AppConfigCubit>();
                          await OrderPdfGenerator.shareTicket(
                            result.order,
                            items: result.items,
                            businessName: config.businessName,
                            taxId: config.businessTaxId,
                            address: config.businessAddress,
                            phone: config.businessPhone,
                          );
                        },
                      );
                    } catch (e, stackTrace) {
                      LoggerService.e(
                        'Error imprimiendo comprobante',
                        tag: 'DesktopPosPanel',
                        error: e,
                        stackTrace: stackTrace,
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
        }
      },
      child: Form(
        key: _formKey,
        child: Stack(
          children: [
            Column(
              children: [
                // ── BARRA UNIFICADA ERGONÓMICA (Caja + Cliente + Quick Actions en 52px)
                _buildClientHeader(isLoyaltyEnabled),

                // Contenido Escroleable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Productos
                        PosCartItemsSection(
                          onShowBatchEditSheet: _showBatchEditSheet,
                        ),
                        const SizedBox(height: 16),

                        // Configuración de venta y Puntos de lealtad
                        _buildPaymentAndConfigSection(
                          pointsToSolesRatio,
                          isLoyaltyEnabled,
                        ),
                        const SizedBox(height: 20),

                        // Resumen Total
                        _buildSummarySection(
                          pointsToSolesRatio,
                          earningRate,
                          isLoyaltyEnabled,
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Bar inferior
                _buildStickyActionBar(pointsToSolesRatio),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onClearCartRequested() {
    final posCubit = context.read<PosCubit>();
    final cartCubit = context.read<CartCubit>();
    if (cartCubit.state.items.isEmpty) return;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                SizedBox(width: 8),
                Text('¿Vaciar caja?'),
              ],
            ),
            content: const Text(
              'Se eliminarán todos los productos de la caja actual.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
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
                  posCubit.removeClient();
                  posCubit.setPuntosAUsar(0);
                  posCubit.setDiscountText('');
                  _clienteCtrl.clear();
                  _puntosCtrl.text = '0';
                  _descuentoCtrl.clear();
                  cartCubit.clearCart();
                  posCubit.clearAllBatchOverrides();
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Vaciar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
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
            final (itemCount, isCartEmpty) = cartTuple;
            return PosClientHeaderBar(
              key: _clientHeaderBarKey,
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
              cartItemCount: itemCount,
              isCartEmpty: isCartEmpty,
              onClearCart: _onClearCartRequested,
              showCajaHeader: true,
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentAndConfigSection(double ratio, bool isLoyaltyEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                final posCubit = context.read<PosCubit>();
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
        const SizedBox(height: 20),
        const _SectionTitle('Configuración de venta'),
        BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.paymentMethod != curr.paymentMethod ||
                  prev.warehouses != curr.warehouses ||
                  prev.selectedWarehouseId != curr.selectedWarehouseId ||
                  prev.accounts != curr.accounts ||
                  prev.selectedAccountId != curr.selectedAccountId ||
                  prev.activeShift != curr.activeShift,
          builder: (context, posState) {
            final posCubit = context.read<PosCubit>();
            final isCredito = posState.paymentMethod == 'CRÉDITO';
            return PaymentWarehouseAccountCard(
              paymentMethod: posState.paymentMethod,
              warehouseList: posState.warehouses,
              selectedWarehouseId: posState.selectedWarehouseId,
              accountsList: posState.accounts,
              selectedAccountId: posState.selectedAccountId,
              activeShift: posState.activeShift,
              isCredito: isCredito,
              onCreditoToggle: (isCredito) {
                if (isCredito) {
                  posCubit.setPaymentMethod('CRÉDITO');
                  posCubit.setPuntosAUsar(0);
                  _puntosCtrl.text = '0';
                } else {
                  if (posState.selectedAccountId != null) {
                    final acc = posState.accounts.firstWhere(
                      (a) => a['id'] == posState.selectedAccountId,
                      orElse: () => <String, dynamic>{},
                    );
                    final accName = acc['name'] as String? ?? 'EFECTIVO';
                    posCubit.setPaymentMethod(accName);
                  } else {
                    posCubit.setPaymentMethod('EFECTIVO');
                  }
                }
              },
              onWarehouseChanged: (v) => posCubit.setWarehouse(v),
              onAccountChanged: (v) {
                posCubit.setSelectedAccountId(v);
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
    return BlocBuilder<PosCubit, PosState>(
      buildWhen:
          (prev, curr) =>
              prev.paymentMethod != curr.paymentMethod ||
              prev.puntosAUsar != curr.puntosAUsar ||
              prev.selectedClientId != curr.selectedClientId ||
              prev.saldoActualCliente != curr.saldoActualCliente ||
              prev.creditInfo != curr.creditInfo ||
              prev.discountText != curr.discountText ||
              prev.isDiscountPercentage != curr.isDiscountPercentage,
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
                  _CreditWarningCard(
                    clienteSeleccionado: posState.selectedClientId != null,
                    creditActivo: PosCalculatorUtils.isCreditActivo(
                      posState.creditInfo,
                    ),
                    creditDisponible: PosCalculatorUtils.getCreditDisponible(
                      posState.creditInfo,
                    ),
                    totalFinal: PosCalculatorUtils.calcularTotalFinal(
                      discountText: posState.discountText,
                      isDiscountPercentage: posState.isDiscountPercentage,
                      pos: posState,
                      cart: cartState,
                      ratio: ratio,
                    ),
                    creditInfo: posState.creditInfo,
                  ),
                  const SizedBox(height: 24),
                ],

                if (!isCredito) ...[
                  _buildCustomDiscountCard(
                    posState,
                    cartState,
                    ratio,
                    puntosSeguros,
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
                            discountText: posState.discountText,
                            isDiscountPercentage: posState.isDiscountPercentage,
                            pos: posState,
                            cart: cartState,
                            ratio: ratio,
                          ),
                  totalFinal: PosCalculatorUtils.calcularTotalFinal(
                    discountText: posState.discountText,
                    isDiscountPercentage: posState.isDiscountPercentage,
                    pos: posState,
                    cart: cartState,
                    ratio: ratio,
                  ),
                  earningRate: earningRate,
                  pointsToSolesRatio: ratio,
                  isCredito: isCredito,
                ),
              ],
            );
          },
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.discount_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Descuento manual',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Monto', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: posState.isDiscountPercentage,
                    onChanged: (val) {
                      context.read<PosCubit>().setIsDiscountPercentage(val);
                      _descuentoCtrl.text = '';
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                  const Text('%', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descuentoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            validator:
                (v) => PosCalculatorUtils.validateDiscountInput(
                  text: v,
                  isPercentage: posState.isDiscountPercentage,
                  maxDiscountAmount: PosCalculatorUtils.getMaxCustomDiscount(
                    cartState,
                    ratio,
                    puntosSeguros,
                  ),
                  cartTotal: cartState.totalAmount,
                ),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: posState.isDiscountPercentage ? null : 'S/ ',
              suffixText: posState.isDiscountPercentage ? '%' : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            onChanged: (v) {
              if (v.trim().isEmpty) {
                context.read<PosCubit>().setDiscountText('');
                return;
              }
              final val = double.tryParse(v) ?? 0.0;
              final maxDiscount = PosCalculatorUtils.getMaxCustomDiscount(
                cartState,
                ratio,
                puntosSeguros,
              );
              final amt =
                  posState.isDiscountPercentage
                      ? (cartState.totalAmount * (val / 100))
                      : val;
              if (amt > maxDiscount) {
                if (posState.isDiscountPercentage) {
                  final maxPerc = (maxDiscount / cartState.totalAmount) * 100;
                  final text = maxPerc.toStringAsFixed(2);
                  _descuentoCtrl.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
                  context.read<PosCubit>().setDiscountText(text);
                } else {
                  final text = maxDiscount.toStringAsFixed(2);
                  _descuentoCtrl.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
                  context.read<PosCubit>().setDiscountText(text);
                }
              } else {
                context.read<PosCubit>().setDiscountText(v);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(double ratio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: BlocBuilder<PosCubit, PosState>(
          buildWhen:
              (prev, curr) =>
                  prev.paymentMethod != curr.paymentMethod ||
                  prev.discountText != curr.discountText ||
                  prev.isDiscountPercentage != curr.isDiscountPercentage ||
                  prev.puntosAUsar != curr.puntosAUsar ||
                  prev.selectedClientId != curr.selectedClientId ||
                  prev.selectedAccountId != curr.selectedAccountId ||
                  prev.activeShift != curr.activeShift ||
                  prev.creditInfo != curr.creditInfo ||
                  prev.status != curr.status,
          builder: (context, posState) {
            return BlocBuilder<CartCubit, CartState>(
              buildWhen:
                  (prev, curr) =>
                      prev.totalAmount != curr.totalAmount ||
                      prev.items.isEmpty != curr.items.isEmpty,
              builder: (context, cartState) {
                final posCubit = context.read<PosCubit>();
                final cartCubit = context.read<CartCubit>();
                final total = PosCalculatorUtils.calcularTotalFinal(
                  discountText: posState.discountText,
                  isDiscountPercentage: posState.isDiscountPercentage,
                  pos: posState,
                  cart: cartState,
                  ratio: ratio,
                );
                final isCredito = posState.paymentMethod == 'CRÉDITO';
                final isBusy =
                    _isProcessing || posState.status == PosStatus.loading;

                final accountData = posState.accounts.firstWhere(
                  (a) => a['id'] == posState.selectedAccountId,
                  orElse: () => <String, dynamic>{},
                );
                final requiresShift =
                    PosCalculatorUtils.accountRequiresShift(accountData);
                final noCajaAbierta =
                    !isCredito &&
                    posState.selectedAccountId != null &&
                    requiresShift &&
                    posState.activeShift == null;

                final disp = PosCalculatorUtils.getCreditDisponible(
                  posState.creditInfo,
                );
                final creditoInsuficiente =
                    isCredito &&
                    posState.selectedClientId != null &&
                    PosCalculatorUtils.isCreditActivo(posState.creditInfo) &&
                    disp < total;
                final creditoSinCliente =
                    isCredito && posState.selectedClientId == null;

                final safePts = PosCalculatorUtils.clampPointsValue(
                  posState.puntosAUsar,
                  posState,
                  cartState,
                  ratio,
                );
                final maxAllowedDisc =
                    cartState.totalAmount - (safePts * ratio);
                final descuentoExtra =
                    PosCalculatorUtils.getCustomDiscountAmount(
                      discountText: posState.discountText,
                      isDiscountPercentage: posState.isDiscountPercentage,
                      pos: posState,
                      cart: cartState,
                      ratio: ratio,
                    );
                final descuentoExcedido = descuentoExtra > maxAllowedDisc;

                final canProceed =
                    cartState.items.isNotEmpty &&
                    !isBusy &&
                    !noCajaAbierta &&
                    !creditoInsuficiente &&
                    !creditoSinCliente &&
                    !descuentoExcedido;

                final canDraft =
                    cartState.items.isNotEmpty && !isBusy && !descuentoExcedido;

                return Row(
                  children: [
                    // Botón Secundario: Guardar Borrador (Alt+B)
                    SizedBox(
                      height: 50,
                      child: Tooltip(
                        message: 'Guardar orden como borrador (Alt+B)',
                        child: OutlinedButton(
                          onPressed:
                              !canDraft
                                  ? null
                                  : () => _processSale(
                                    posCubit,
                                    cartCubit,
                                    isDraft: true,
                                  ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            backgroundColor: Colors.white,
                            disabledForegroundColor: AppColors.textMuted,
                            side: BorderSide(
                              color:
                                  canDraft
                                      ? AppColors.border
                                      : Colors.grey.shade200,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark_add_outlined, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'Borrador',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 0.8,
                                  ),
                                ),
                                child: const Text(
                                  'Alt+B',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botón Principal: Cobrar (CTA F2 / Alt+Enter)
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: Tooltip(
                          message:
                              noCajaAbierta
                                  ? 'Abre turno en caja física o cambia de método de pago'
                                  : 'Completar venta (F2 o Alt+Enter)',
                          child: ElevatedButton(
                            onPressed:
                                !canProceed
                                    ? null
                                    : () => _processSale(
                                      posCubit,
                                      cartCubit,
                                      isDraft: false,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              disabledBackgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.grey.shade500,
                              elevation: canProceed ? 2 : 0,
                              shadowColor: AppColors.teal.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child:
                                isBusy
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.shopping_cart_checkout_rounded,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            isCredito
                                                ? 'Vender a crédito'
                                                : 'Cobrar S/ ${total.toStringAsFixed(2)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'F2',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
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
    this.creditInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (!clienteSeleccionado) {
      return _buildAlert(
        'Selecciona un cliente para ver su crédito.',
        Icons.info_outline,
        Colors.blue,
      );
    }
    if (!creditActivo) {
      return _buildAlert(
        'El cliente no tiene crédito activo.',
        Icons.warning_amber_rounded,
        AppColors.danger,
      );
    }
    if (totalFinal > creditDisponible) {
      return _buildAlert(
        'Crédito insuficiente.\nDisp: S/ ${creditDisponible.toStringAsFixed(2)}\nLímite: S/ ${(creditInfo?['credit_limit'] ?? 0).toStringAsFixed(2)}',
        Icons.error_outline_rounded,
        AppColors.danger,
      );
    }

    return _buildAlert(
      'Crédito aprobado. Disp: S/ ${creditDisponible.toStringAsFixed(2)}',
      Icons.check_circle_outline_rounded,
      AppColors.success,
    );
  }

  Widget _buildAlert(String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
