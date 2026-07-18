import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_client_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/admin_sale_points_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_total_summary_section.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/batch_edit_sheet.dart';

class DesktopPosPanel extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const DesktopPosPanel({super.key, this.onSaleCompleted});

  @override
  State<DesktopPosPanel> createState() => _DesktopPosPanelState();
}

class _DesktopPosPanelState extends State<DesktopPosPanel> {
  final PosRepository _checkoutService = GetIt.I<PosRepository>();

  // Controladores
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  // Busqueda de clientes
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
  Map<String, dynamic>? _creditInfo;

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
        creditResp.fold((_) {}, (info) {
          if (mounted) {
            setState(() {
              _creditInfo = info;
            });
          }
        });
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
    final account = _accountsList.firstWhere(
      (a) => a['id'] == _selectedAccountId,
      orElse: () => <String, dynamic>{},
    );
    if (account['type'] != 'CAJA') {
      if (mounted) setState(() => _activeShift = null);
      return;
    }

    try {
      final shiftResult = await _checkoutService.checkActiveShift(
        _selectedAccountId!,
      );
      shiftResult.fold(
        (_) {
          if (mounted) setState(() => _activeShift = null);
        },
        (shift) {
          if (mounted) {
            setState(() {
              _activeShift = shift;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error checkActiveShift: $e');
      if (mounted) setState(() => _activeShift = null);
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
      final responseResult = await _checkoutService.searchClients(text);
      if (currentVersion == _clientSearchVersion && mounted) {
        responseResult.fold(
          (_) {
            setState(() {
              _clientMatches = [];
              _searchingClients = false;
            });
          },
          (matches) {
            setState(() {
              _clientMatches = matches;
              _searchingClients = false;
            });
          },
        );
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
      creditResp.fold(
        (_) {
          if (mounted) setState(() => _creditInfo = null);
        },
        (info) {
          if (mounted) setState(() => _creditInfo = info);
        },
      );
    } catch (e) {
      debugPrint('Error cargando crédito: $e');
      if (mounted) setState(() => _creditInfo = null);
    }
  }

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
        orElse: () => <String, dynamic>{},
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

          // En desktop usamos un Dialog
          final result = await showDialog<List<BatchAssignmentModel>>(
            context: context,
            builder:
                (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                      maxHeight: 600,
                    ),
                    child: BatchEditSheet(
                      productName: item.productName,
                      variantLabel: item.variantLabel,
                      totalRequired: item.quantity,
                      batches: batches,
                    ),
                  ),
                ),
          );

          if (result != null && mounted) {
            posCubit.setBatchOverride(item.cartKey, result);
          }
        },
      );

      if (!mounted) return;

      // Ya procesado arriba
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
    if (_isLoadingInitialData) {
      return const Center(child: CircularProgressIndicator());
    }

    final posCubit = context.watch<PosCubit>();
    final cartCubit = context.watch<CartCubit>();
    final config = context.watch<AppConfigCubit>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

    return Stack(
      children: [
        Column(
          children: [
            // Header del Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Vaciar caja',
                    onPressed:
                        cartCubit.state.items.isEmpty
                            ? null
                            : () {
                              showDialog(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text('¿Vaciar caja?'),
                                      content: const Text(
                                        'Se eliminarán todos los productos de la caja actual.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            'Cancelar',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.danger,
                                          ),
                                          onPressed: () {
                                            posCubit.removeClient();
                                            posCubit.setPuntosAUsar(0);
                                            cartCubit.clearCart();
                                            posCubit.clearAllBatchOverrides();
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
                    // Productos (Reutilizando componente existente)
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

        // Capa de carga
        if (_isProcessingSale) const PosProcessingOverlay(isVisible: true),
      ],
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
        const SizedBox(height: 32),
        const _SectionTitle('Configuración de venta'),
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
                      orElse: () => <String, dynamic>{},
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
                    orElse: () => <String, dynamic>{},
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
              puntosAplicables: isCredito ? 0 : puntosSeguros,
              descuentoPuntos: isCredito ? 0 : puntosSeguros * ratio,
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
                    value: _isDiscountPercentage,
                    onChanged: (val) {
                      setState(() {
                        _isDiscountPercentage = val;
                        _descuentoCtrl.text = '';
                      });
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                  const Text('%', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descuentoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: _isDiscountPercentage ? null : 'S/ ',
              suffixText: _isDiscountPercentage ? '%' : null,
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
                setState(() {});
                return;
              }
              final val = double.tryParse(v) ?? 0.0;
              final maxDiscount = PosCalculatorUtils.getMaxCustomDiscount(
                cartState,
                ratio,
                puntosSeguros,
              );
              final amt =
                  _isDiscountPercentage
                      ? (cartState.totalAmount * (val / 100))
                      : val;
              if (amt > maxDiscount) {
                if (_isDiscountPercentage) {
                  final maxPerc = (maxDiscount / cartState.totalAmount) * 100;
                  _descuentoCtrl.text = maxPerc.toStringAsFixed(2);
                } else {
                  _descuentoCtrl.text = maxDiscount.toStringAsFixed(2);
                }
              }
              setState(() {});
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
              discountText: _descuentoCtrl.text,
              isDiscountPercentage: _isDiscountPercentage,
              pos: posCubit.state,
              cart: cartCubit.state,
              ratio: ratio,
            );
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed:
                        cartCubit.state.items.isEmpty
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
                        cartCubit.state.items.isEmpty
                            ? null
                            : () => _processSale(
                              posCubit,
                              cartCubit,
                              isDraft: false,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          cartCubit.state.items.isEmpty
                              ? Colors.grey.shade400
                              : AppColors.teal,
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
