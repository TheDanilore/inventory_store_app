import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_client_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_points_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/batch_edit_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';

class PosCheckoutScreen extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const PosCheckoutScreen({super.key, this.onSaleCompleted});

  @override
  State<PosCheckoutScreen> createState() => _PosCheckoutScreenState();
}

class _PosCheckoutScreenState extends State<PosCheckoutScreen> {
  final PosRepository _checkoutService = GetIt.I<PosRepository>();

  // Controladores
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  // Búsqueda de clientes
  List<Map<String, dynamic>> _clientMatches = [];
  bool _searchingClients = false;
  int _clientSearchVersion = 0;
  Timer? _debounce;

  bool _isDiscountPercentage = false;

  // Almacén, Cuentas y Caja
  List<WarehouseModel> _warehouseList = [];
  List<Map<String, dynamic>> _accountsList = [];
  String? _selectedAccountId;
  CashShiftEntity? _activeShift;

  // Crédito del cliente seleccionado
  Map<String, dynamic>?
  _creditInfo; // {id, credit_limit, current_debt, is_active}

  // Venta
  bool _isProcessingSale = false;
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
    _debounce?.cancel();
    super.dispose();
  }

  // CARGA DE DATOS

  Future<void> _loadInitialData(PosCubit posCubit) async {
    try {
      final dataResult = await _checkoutService.loadInitialData();
      dataResult.fold(
        (failure) {
          if (mounted) {
            AppSnackbar.show(
              context,
              message: 'Error cargando datos: ${failure.message}',
              type: SnackbarType.error,
            );
          }
        },
        (data) async {
          final list = data.warehouses;
          final accs = data.accounts;

          if (mounted) {
            setState(() {
              _warehouseList = list;
              if (posCubit.state.selectedWarehouseId == null &&
                  list.isNotEmpty) {
                posCubit.setWarehouse(list.first.id);
              }
              _accountsList = accs;
              if (accs.isNotEmpty) {
                final firstAcc = accs.firstWhere(
                  (a) => a['type'] == 'CAJA',
                  orElse: () => accs.first,
                );
                _selectedAccountId = firstAcc['id'] as String;

                if (posCubit.state.paymentMethod != 'CRÉDITO') {
                  final accountName = (firstAcc['name'] as String? ?? '');
                  posCubit.setPaymentMethod(accountName);
                }

                _checkActiveShift();
              }
            });
          }
        },
      );

      if (posCubit.state.selectedClientId != null) {
        final creditResp = await _checkoutService.fetchClientCredit(
          posCubit.state.selectedClientId!,
        );
        if (mounted) {
          setState(() {
            _creditInfo = creditResp.fold((l) => null, (r) => r);
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos iniciales: $e');
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando datos: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitialData = false;
        });
      }
    }
  }

  Future<void> _checkActiveShift() async {
    if (_selectedAccountId == null) return;
    try {
      final accountData = _accountsList.firstWhere(
        (a) => a['id'] == _selectedAccountId,
        orElse: () => {},
      );
      if (accountData['type'] != 'CAJA') {
        if (mounted) setState(() => _activeShift = null);
        return;
      }
      final shiftRes = await _checkoutService.checkActiveShift(
        _selectedAccountId!,
      );
      if (mounted)
        setState(() => _activeShift = shiftRes.fold((l) => null, (r) => r));
    } catch (e) {
      debugPrint('Error verificando turno de caja: $e');
    }
  }

  void _onClientSearchChanged(String query) {
    final posCubit = context.read<PosCubit>();
    if (posCubit.state.selectedClientId != null) {
      posCubit.removeClient();
      _puntosCtrl.text = '0';
      setState(() => _creditInfo = null);
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _searchClients(query),
    );
  }

  Future<void> _searchClients(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          _clientMatches = [];
          _searchingClients = false;
        });
      }
      return;
    }
    final currentVersion = ++_clientSearchVersion;
    setState(() => _searchingClients = true);
    try {
      final response = await _checkoutService.searchClients(text);
      if (currentVersion == _clientSearchVersion && mounted) {
        setState(() {
          _clientMatches = response.fold((l) => [], (r) => r);
          _searchingClients = false;
        });
      }
    } catch (e) {
      if (currentVersion == _clientSearchVersion && mounted) {
        setState(() => _searchingClients = false);
      }
    }
  }

  Future<void> _selectClient(Map<String, dynamic> client) async {
    final posCubit = context.read<PosCubit>();
    posCubit.setClient(
      client['id'] as String,
      client['full_name'] ?? '',
      (client['wallet_balance'] as num?)?.toInt() ?? 0,
    );
    _clienteCtrl.text = client['full_name'] ?? '';
    _puntosCtrl.text = '0';
    setState(() {
      _clientMatches = [];
      _creditInfo = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final creditResp = await _checkoutService.fetchClientCredit(
        client['id'] as String,
      );
      if (mounted)
        setState(() => _creditInfo = creditResp.fold((l) => null, (r) => r));
    } catch (e) {
      debugPrint('Error cargando crédito: $e');
    }
  }

  //  CÁLCULOS (Movidos a PosCalculatorUtils)

  Future<void> _processSale(
    PosCubit posCubit,
    CartCubit cartCubit, {
    bool isDraft = false,
  }) async {
    if (posCubit.state.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacén.',
        type: SnackbarType.error,
      );
      return;
    }
    if (cartCubit.state.items.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'La caja está vacía.',
        type: SnackbarType.error,
      );
      return;
    }

    final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';

    if (!isDraft && !isCredito) {
      if (_selectedAccountId == null) {
        AppSnackbar.show(
          context,
          message: 'Selecciona una cuenta financiera para el ingreso.',
          type: SnackbarType.error,
        );
        return;
      }
      final accountData = _accountsList.firstWhere(
        (a) => a['id'] == _selectedAccountId,
        orElse: () => {},
      );
      if (accountData['type'] == 'CAJA' && _activeShift == null) {
        AppSnackbar.show(
          context,
          message: 'La caja seleccionada no tiene un turno abierto.',
          type: SnackbarType.error,
        );
        return;
      }
    }

    final config = context.read<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);

    final totalFinal = PosCalculatorUtils.calcularTotalFinal(
      discountText: _descuentoCtrl.text,
      isDiscountPercentage: _isDiscountPercentage,
      pos: posCubit.state,
      cart: cartCubit.state,
      ratio: pointsToSolesRatio,
    );

    if (isCredito && !isDraft) {
      if (posCubit.state.selectedClientId == null) {
        AppSnackbar.show(
          context,
          message: 'Debes seleccionar un cliente para ventas a crédito.',
          type: SnackbarType.error,
        );
        return;
      }
      if (!PosCalculatorUtils.isCreditActivo(_creditInfo)) {
        AppSnackbar.show(
          context,
          message: 'El cliente no tiene línea de crédito activa.',
          type: SnackbarType.error,
        );
        return;
      }

      final disp = PosCalculatorUtils.getCreditDisponible(_creditInfo);
      if (disp < totalFinal) {
        AppSnackbar.show(
          context,
          message:
              'Crédito insuficiente. Disponible: S/ ${disp.toStringAsFixed(2)}',
          type: SnackbarType.error,
        );
        return;
      }
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
              onConfirm: () {},
            ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isProcessingSale = true);

    try {
      final puntosUsados = PosCalculatorUtils.clampPointsValue(
        posCubit.state.puntosAUsar,
        posCubit.state,
        cartCubit.state,
        pointsToSolesRatio,
      );
      final totalProfit = PosCalculatorUtils.calcularGananciaTotal(
        discountText: _descuentoCtrl.text,
        isDiscountPercentage: _isDiscountPercentage,
        pos: posCubit.state,
        cart: cartCubit.state,
        ratio: pointsToSolesRatio,
      );
      final descuentoExtra = PosCalculatorUtils.getCustomDiscountAmount(
        discountText: _descuentoCtrl.text,
        isDiscountPercentage: _isDiscountPercentage,
        pos: posCubit.state,
        cart: cartCubit.state,
        ratio: pointsToSolesRatio,
      );

      final saleItems =
          cartCubit.state.items.values.map((item) {
            return SaleItemEntity(
              productId: item.productId,
              variantId: item.variantId,
              quantity: item.quantity,
              unitCost: item.unitCost,
              appliedPrice: item.unitPrice,
              batchAssignments:
                  posCubit.state.batchOverrides[item.cartKey] ?? [],
            );
          }).toList();

      final sale = SaleEntity(
        items: saleItems,
        warehouseId: posCubit.state.selectedWarehouseId!,
        paymentMethod: posCubit.state.paymentMethod,
        totalAmount: totalFinal,
        totalProfit: totalProfit,
        customerId: posCubit.state.selectedClientId,
        customerName:
            posCubit.state.selectedClientName ??
            (_clienteCtrl.text.trim().isNotEmpty
                ? _clienteCtrl.text.trim()
                : null),
        accountId: _selectedAccountId,
        paymentStatus:
            isCredito ? SalePaymentStatus.pending : SalePaymentStatus.paid,
        discountAmount: descuentoExtra,
        amountPaid: isCredito ? 0 : totalFinal,
        pointsUsed: puntosUsados,
        pointsEarned: PosCalculatorUtils.calcularPuntosGanados(
          total: totalFinal,
          rate: earningRate,
        ),
        isDraft: isDraft,
        isCredit: isCredito,
        activeShift: _activeShift,
      );

      final saleResult = await _checkoutService.processSale(sale);
      if (!mounted) return;

      final orderId = saleResult.fold((failure) {
        AppSnackbar.show(
          context,
          message: 'Error procesando venta: ${failure.message}',
          type: SnackbarType.error,
        );
        return null;
      }, (id) => id);

      if (orderId == null) {
        setState(() => _isProcessingSale = false);
        return;
      }

      posCubit.removeClient();
      posCubit.setPuntosAUsar(0);
      cartCubit.clearCart();
      posCubit.clearAllBatchOverrides();
      widget.onSaleCompleted?.call();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => PosSuccessDialog(
                isDraft: isDraft,
                onPrint: () async {
                  try {
                    final orderResp =
                        await Supabase.instance.client
                            .from('orders')
                            .select(
                              'id, customer_name, customer_id, total_amount, total_profit, discount_amount, payment_method, payment_status, amount_paid, status, points_used, points_earned, created_at, warehouse_id, profiles!orders_customer_id_fkey(full_name, phone), warehouses(name)',
                            )
                            .eq('id', orderId)
                            .single();
                    final itemsResp = await Supabase.instance.client
                        .from('order_items')
                        .select(
                          'id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at, products(name, product_images(id, image_url, is_main)), product_variants(sku, product_images(id, image_url, is_main), variant_attribute_values(attribute_values(value, attributes(name))))',
                        )
                        .eq('order_id', orderId);

                    final order = OrderModel.fromJson(orderResp);
                    final items =
                        List<Map<String, dynamic>>.from(
                          itemsResp,
                        ).map((x) => OrderItemModel.fromJson(x)).toList();

                    await OrderPdfGenerator.shareTicket(order, items: items);
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
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
    }
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
      final batchesResult = await _checkoutService.fetchBatchesForVariant(
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
          final result = await showModalBottomSheet<List<BatchAssignmentModel>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (_) => BatchEditSheet(
                  productName: item.productName,
                  variantLabel: item.variantLabel,
                  totalRequired: item.quantity,
                  batches: batches,
                ),
          );

          if (result != null && mounted) {
            posCubit.setBatchOverride(item.cartKey, result);
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

  // BUILD

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

    return AdminLayout(
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
                                right: BorderSide(color: Colors.grey.shade200),
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
                                  child: PosSectionLabel('Productos en caja'),
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PosSectionLabel('Productos en caja'),
                              PosCartItemsSection(
                                onShowBatchEditSheet: _showBatchEditSheet,
                              ),
                              const SizedBox(height: 24),
                              _buildClientAndPaymentSection(
                                pointsToSolesRatio,
                                isLoyaltyEnabled,
                              ),
                              const SizedBox(height: 24),
                              _buildSummarySection(
                                pointsToSolesRatio,
                                earningRate,
                                isLoyaltyEnabled,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildStickyActionBar(pointsToSolesRatio),
                    ],
                  );
                },
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
                _buildSummarySection(ratio, earningRate, isLoyaltyEnabled),
              ],
            ),
          ),
        ),
        _buildStickyActionBar(ratio),
      ],
    );
  }

  Widget _buildClientAndPaymentSection(double ratio, bool isLoyaltyEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PosSectionLabel('Cliente'),
        Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
            return AdminSaleClientSection(
              controller: _clienteCtrl,
              onSearchChanged: _onClientSearchChanged,
              searching: _searchingClients,
              matches: _clientMatches,
              selectedClientId: posCubit.state.selectedClientId,
              onClientTap: _selectClient,
              saldoActualCliente: posCubit.state.saldoActualCliente,
              creditInfo: _creditInfo,
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
        const SizedBox(height: 24),
        PosSectionLabel('Configuración de venta'),
        Builder(
          builder: (context) {
            final posCubit = context.watch<PosCubit>();
            final isCredito = posCubit.state.paymentMethod == 'CRÉDITO';
            return PaymentWarehouseAccountCard(
              paymentMethod: posCubit.state.paymentMethod,
              warehouseList: _warehouseList,
              selectedWarehouseId: posCubit.state.selectedWarehouseId,
              accountsList: _accountsList,
              selectedAccountId: _selectedAccountId,
              activeShift: _activeShift,
              isCredito: isCredito,
              onCreditoToggle: (isCredito) {
                if (isCredito) {
                  posCubit.setPaymentMethod('CRÉDITO');
                  posCubit.setPuntosAUsar(0);
                  _puntosCtrl.text = '0';
                } else {
                  if (_selectedAccountId != null) {
                    final acc = _accountsList.firstWhere(
                      (a) => a['id'] == _selectedAccountId,
                      orElse: () => {},
                    );
                    final accName = acc['name'] as String? ?? 'EFECTIVO';
                    posCubit.setPaymentMethod(accName);
                  } else {
                    posCubit.setPaymentMethod('EFECTIVO');
                  }
                }
                setState(() {});
              },
              onWarehouseChanged: (v) => posCubit.setWarehouse(v),
              onAccountChanged: (v) {
                setState(() => _selectedAccountId = v);
                if (v != null) {
                  final acc = _accountsList.firstWhere(
                    (a) => a['id'] == v,
                    orElse: () => {},
                  );
                  final accName = acc['name'] as String? ?? 'OTRO';
                  posCubit.setPaymentMethod(accName);
                }
                _checkActiveShift();
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
                creditActivo: PosCalculatorUtils.isCreditActivo(_creditInfo),
                creditDisponible: PosCalculatorUtils.getCreditDisponible(
                  _creditInfo,
                ),
                totalFinal: PosCalculatorUtils.calcularTotalFinal(
                  discountText: _descuentoCtrl.text,
                  isDiscountPercentage: _isDiscountPercentage,
                  pos: posCubit.state,
                  cart: cartCubit.state,
                  ratio: ratio,
                ),
                creditInfo: _creditInfo,
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
                        isDiscountPercentage: _isDiscountPercentage,
                        pos: posCubit.state,
                        cart: cartCubit.state,
                        ratio: ratio,
                      ),
              totalFinal: PosCalculatorUtils.calcularTotalFinal(
                discountText: _descuentoCtrl.text,
                isDiscountPercentage: _isDiscountPercentage,
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
      isDiscountPercentage: _isDiscountPercentage,
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
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: "0.00",
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
                              () =>
                                  setState(() => _isDiscountPercentage = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color:
                                  !_isDiscountPercentage
                                      ? Colors.white
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                              boxShadow:
                                  !_isDiscountPercentage
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
                              "S/",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    !_isDiscountPercentage
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
                              () =>
                                  setState(() => _isDiscountPercentage = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color:
                                  _isDiscountPercentage
                                      ? Colors.white
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm,
                              ),
                              boxShadow:
                                  _isDiscountPercentage
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
                                    _isDiscountPercentage
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
              isDiscountPercentage: _isDiscountPercentage,
              pos: posCubit.state,
              cart: cartCubit.state,
              ratio: ratio,
            );
            final descuentoExcedido =
                descuentoExtra >
                (cartCubit.state.totalAmount - (puntosSeguros * ratio));
            final totalFinal = PosCalculatorUtils.calcularTotalFinal(
              discountText: _descuentoCtrl.text,
              isDiscountPercentage: _isDiscountPercentage,
              pos: posCubit.state,
              cart: cartCubit.state,
              ratio: ratio,
            );

            final disp = PosCalculatorUtils.getCreditDisponible(_creditInfo);
            final creditoInsuficiente =
                isCredito &&
                posCubit.state.selectedClientId != null &&
                PosCalculatorUtils.isCreditActivo(_creditInfo) &&
                disp < totalFinal;
            final creditoSinCliente =
                isCredito && posCubit.state.selectedClientId == null;
            final isCajaAccount = _accountsList.any(
              (a) => a['id'] == _selectedAccountId && a['type'] == 'CAJA',
            );
            final noCajaAbierta =
                !isCredito &&
                _selectedAccountId != null &&
                isCajaAccount &&
                _activeShift == null;

            final puedeVender =
                cartCubit.state.items.isNotEmpty &&
                !descuentoExcedido &&
                !creditoInsuficiente &&
                !creditoSinCliente &&
                !noCajaAbierta;

            return Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PosConfirmButton(
                        loading: _isProcessingSale,
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
                                (_isProcessingSale ||
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
                if (_isProcessingSale)
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
