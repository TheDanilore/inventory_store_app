import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';

import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_client_section.dart';
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
  State<DesktopPosPanel> createState() => _DesktopPosPanelState();
}

class _DesktopPosPanelState extends State<DesktopPosPanel> {
  // Controladores
  final _formKey = GlobalKey<FormState>();
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  Timer? _debounce;
  bool _lastSaleWasDraft = false;
  Map<String, int> _lastSoldQuantities = {};

  /// Mutex local anti-doble-tap que previene la ejecución simultánea de ventas.
  bool _isProcessing = false;

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
    } catch (e) {
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

          // Refrescar saldos de cuentas (balance) tras la venta
          posCubit.initPosData(forceRefresh: true);

          widget.onSaleCompleted?.call(_lastSoldQuantities);

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (dialogContext) => PosSuccessDialog(
                  isDraft: _lastSaleWasDraft,
                  onPrint: () async {
                    try {
                      final fetchResult = await GetIt.I<PosRepository>()
                          .fetchOrderForReceipt(orderId);
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
                    } catch (e) {
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
                // Header del Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.point_of_sale_rounded,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CAJA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      BlocSelector<CartCubit, CartState, bool>(
                        selector: (state) => state.items.isEmpty,
                        builder: (context, isCartEmpty) {
                          return IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            tooltip: 'Vaciar caja',
                            onPressed:
                                isCartEmpty
                                    ? null
                                    : () {
                                      showDialog(
                                        context: context,
                                        builder:
                                            (ctx) => AlertDialog(
                                              title: const Text(
                                                '¿Vaciar caja?',
                                              ),
                                              content: const Text(
                                                'Se eliminarán todos los productos de la caja actual.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(ctx),
                                                  child: const Text(
                                                    'Cancelar',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors
                                                              .textSecondary,
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.danger,
                                                      ),
                                                  onPressed: () {
                                                    posCubit.removeClient();
                                                    posCubit.setPuntosAUsar(0);
                                                    cartCubit.clearCart();
                                                    posCubit
                                                        .clearAllBatchOverrides();
                                                    Navigator.pop(ctx);
                                                  },
                                                  child: const Text(
                                                    'Vaciar',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Contenido Escroleable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Productos
                        PosCartItemsSection(
                          onShowBatchEditSheet: _showBatchEditSheet,
                        ),
                        const SizedBox(height: 32),

                        // Cliente
                        _buildClientAndPaymentSection(
                          pointsToSolesRatio,
                          isLoyaltyEnabled,
                        ),
                        const SizedBox(height: 32),

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

  Widget _buildClientAndPaymentSection(double ratio, bool isLoyaltyEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Cliente'),
        Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
            return AdminSaleClientSection(
              controller: _clienteCtrl,
              onSearchChanged: _onClientSearchChanged,
              searching:
                  posCubit
                      .state
                      .isLoading, // Wait, searching state? Using local or cubit?
              matches: posCubit.state.clientMatches,
              selectedClientId: posCubit.state.selectedClientId,
              onClientTap: _selectClient,
              saldoActualCliente: posCubit.state.saldoActualCliente,
              creditInfo: posCubit.state.creditInfo,
              isCredito: isCredito,
              isLoyaltyEnabled: isLoyaltyEnabled,
            );
          },
        ),
        Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final cartCubit = context.watch<CartCubit>();
            final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
            return AdminSalePointsSection(
              show:
                  isLoyaltyEnabled &&
                  posCubit.state.selectedClientId != null &&
                  posCubit.state.saldoActualCliente > 0 &&
                  !isCredito,
              saldoActualCliente: posCubit.state.saldoActualCliente,
              maxPuntosAplicables: PosCalculatorUtils.maxPuntosAplicables(
                posCubit.state,
                cartCubit.state,
                ratio,
              ),
              pointsToSolesRatio: ratio,
              pointsController: _puntosCtrl,
              onPointsChanged: (p) {
                final next = PosCalculatorUtils.clampPointsValue(
                  p,
                  posCubit.state,
                  cartCubit.state,
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
        ),
        const SizedBox(height: 32),
        const _SectionTitle('Configuración de venta'),
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
                  discountText: posCubit.state.discountText,
                  isDiscountPercentage: posCubit.state.isDiscountPercentage,
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
              puntosAplicables: isCredito ? 0 : puntosSeguros,
              descuentoPuntos: isCredito ? 0 : puntosSeguros * ratio,
              isLoyaltyEnabled: isLoyaltyEnabled,
              descuentoExtra:
                  isCredito
                      ? 0
                      : PosCalculatorUtils.getCustomDiscountAmount(
                        discountText: posCubit.state.discountText,
                        isDiscountPercentage:
                            posCubit.state.isDiscountPercentage,
                        pos: posCubit.state,
                        cart: cartCubit.state,
                        ratio: ratio,
                      ),
              totalFinal: PosCalculatorUtils.calcularTotalFinal(
                discountText: posCubit.state.discountText,
                isDiscountPercentage: posCubit.state.isDiscountPercentage,
                pos: posCubit.state,
                cart: cartCubit.state,
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
                  _descuentoCtrl.text = maxPerc.toStringAsFixed(2);
                  context.read<PosCubit>().setDiscountText(_descuentoCtrl.text);
                } else {
                  _descuentoCtrl.text = maxDiscount.toStringAsFixed(2);
                  context.read<PosCubit>().setDiscountText(_descuentoCtrl.text);
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
        child: Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final cartCubit = context.watch<CartCubit>();
            final total = PosCalculatorUtils.calcularTotalFinal(
              discountText: posCubit.state.discountText,
              isDiscountPercentage: posCubit.state.isDiscountPercentage,
              pos: posCubit.state,
              cart: cartCubit.state,
              ratio: ratio,
            );
            final isBusy =
                _isProcessing || posCubit.state.status == PosStatus.loading;
            final canProceed = cartCubit.state.items.isNotEmpty && !isBusy;

            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed:
                        !canProceed
                            ? null
                            : () => _processSale(
                              posCubit,
                              cartCubit,
                              isDraft: true,
                            ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Borrador'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
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
                      backgroundColor:
                          !canProceed ? Colors.grey.shade400 : AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_checkout_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cobrar S/ ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
