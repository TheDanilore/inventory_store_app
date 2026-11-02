import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_receipt_export_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/models/pos_sale_receipt_data.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_client_header_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_credit_warning_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_desktop_discount_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_payment_and_config_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_sticky_action_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';

export 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/models/pos_sale_receipt_data.dart';

/// Panel lateral de facturación POS para Escritorio.
/// Optimizado para bajo consumo de RAM, 60fps constantes en CPUs de gama baja
/// y desacoplamiento estricto de Clean Architecture (Zero-Shimmer).
class DesktopPosPanel extends StatefulWidget {
  final ValueChanged<Map<String, int>>? onSaleCompleted;

  const DesktopPosPanel({super.key, this.onSaleCompleted});

  @override
  State<DesktopPosPanel> createState() => DesktopPosPanelState();
}

class DesktopPosPanelState extends State<DesktopPosPanel> {
  final _formKey = GlobalKey<FormState>();
  final _clientHeaderBarKey = GlobalKey<PosClientHeaderBarState>();
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  Timer? _debounce;
  PosSaleReceiptData? _lastReceiptData;

  /// Mutex local anti-doble-tap que previene la ejecución simultánea de ventas.
  bool _isProcessing = false;

  /// Mutex anti-doble-clic para modal de edición de lotes (FEFO).
  bool _isOpeningBatchSheet = false;

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

    if (posCubit.state.warehouses.isEmpty) {
      posCubit.initPosData();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _clienteCtrl.dispose();
    _puntosCtrl.dispose();
    _descuentoCtrl.dispose();
    super.dispose();
  }

  void _onClientSearchChanged(String query) {
    final posCubit = context.read<PosCubit>();
    if (posCubit.state.selectedClientId != null) {
      posCubit.removeClient();
      _puntosCtrl.text = '0';
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
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

    // Inversión de dependencias respetada: PosCubit orquesta la consulta de stock
    final posCubit = context.read<PosCubit>();
    final res = await posCubit.fetchVariantStocks(
      variantIds,
      warehouseId: warehouseId,
    );

    res.fold(
      (failure) {
        LoggerService.e(
          'Error al verificar stock de carrito por almacén: ${failure.message}',
          tag: 'DesktopPosPanel',
          error: failure.message,
        );
      },
      (stockMap) {
        cartCubit.updateBatchAvailableStock(stockMap);
      },
    );
  }

  /// Invocado externamente (ej: atajo de teclado F2) para iniciar el cobro.
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
    if (!_formKey.currentState!.validate()) return;

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

      if (confirmedAmountReceived == null) return;
    }

    _lastReceiptData = PosSaleReceiptData(
      isDraft: isDraft,
      totalAmount: totalFinal,
      amountReceived: confirmedAmountReceived,
      paymentMethod: posCubit.state.paymentMethod,
      customerName: clientName,
      documentType: posCubit.state.documentType,
      documentSeries: posCubit.state.effectiveSeries,
      paymentReference: posCubit.state.paymentReference,
      currencyCode: posCubit.state.currencyCode,
      soldQuantities: {
        for (final item in cartCubit.state.items.values)
          item.productId: item.quantity,
      },
      accountId: posCubit.state.selectedAccountId,
    );

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
    } finally {
      if (mounted) _isOpeningBatchSheet = false;
    }
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

    // Si el sistema de fidelidad está desactivado y hay puntos residuales, purgarlos
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
          final receipt = _lastReceiptData;

          posCubit.removeClient();
          posCubit.setPuntosAUsar(0);
          posCubit.setDiscountText('');
          posCubit.setPaymentReference(null);
          cartCubit.clearCart();
          posCubit.clearAllBatchOverrides();

          _clienteCtrl.clear();
          _puntosCtrl.text = '0';
          _descuentoCtrl.clear();

          if (receipt != null &&
              receipt.accountId != null &&
              !receipt.isDraft) {
            posCubit.updateAccountBalanceLocal(
              accountId: receipt.accountId!,
              deltaAmount: receipt.totalAmount,
            );
          }

          if (receipt != null) {
            widget.onSaleCompleted?.call(receipt.soldQuantities);
          }

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => PosSuccessDialog(
                  isDraft: receipt?.isDraft ?? false,
                  totalAmount: receipt?.totalAmount ?? 0.0,
                  amountReceived: receipt?.amountReceived,
                  paymentMethod: receipt?.paymentMethod ?? 'EFECTIVO',
                  customerName: receipt?.customerName ?? 'Cliente Varios',
                  documentType: receipt?.documentType ?? 'NOTA_VENTA',
                  documentSeries: receipt?.documentSeries,
                  paymentReference: receipt?.paymentReference,
                  currencySymbol: receipt?.currencySymbol ?? 'S/',
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
                          if (dialogContext.mounted) {
                            await OrderReceiptExportSheet.show(
                              dialogContext,
                              order: result.order,
                              initialItems: result.items,
                              isSaleSuccess: true,
                            );
                          }
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
        child: Column(
          children: [
            // ── Barra Unificada de Cabecera (Caja + Cliente + Vaciar) ──
            RepaintBoundary(child: _buildClientHeader(isLoyaltyEnabled)),

            // ── Contenido Escroleable con RepaintBoundary Aislado ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lista de productos del carrito
                    RepaintBoundary(
                      child: PosCartItemsSection(
                        onShowBatchEditSheet: _showBatchEditSheet,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Configuración de venta, almacén y puntos
                    RepaintBoundary(
                      child: PosPaymentAndConfigSection(
                        ratio: pointsToSolesRatio,
                        isLoyaltyEnabled: isLoyaltyEnabled,
                        pointsController: _puntosCtrl,
                        onWarehouseChanged: (whId) {
                          posCubit.setWarehouse(whId);
                          if (whId != null) {
                            _updateCartItemsStockForWarehouse(whId);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Resumen Total y Descuento Manual
                    _buildSummarySection(
                      pointsToSolesRatio,
                      earningRate,
                      isLoyaltyEnabled,
                    ),
                  ],
                ),
              ),
            ),

            // ── Action Bar Inferior Fijo ──
            RepaintBoundary(
              child: BlocSelector<PosCubit, PosState, (String, bool)>(
                selector: (s) => (s.discountText, s.isDiscountPercentage),
                builder: (context, discountData) {
                  return PosStickyActionBar(
                    ratio: pointsToSolesRatio,
                    discountText: discountData.$1,
                    isDiscountPercentage: discountData.$2,
                    isProcessingLocal: _isProcessing,
                    showShortcutBadge: true,
                    onProcessSale: ({required bool isDraft}) {
                      _processSale(posCubit, cartCubit, isDraft: isDraft);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
                  PosCreditWarningCard(
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
                  PermissionGuard(
                    permission: AppPermissions.posDiscount,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: PosDesktopDiscountCard(
                        discountController: _descuentoCtrl,
                        posState: posState,
                        cartState: cartState,
                        ratio: ratio,
                        puntosSeguros: puntosSeguros,
                      ),
                    ),
                  ),
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
}
