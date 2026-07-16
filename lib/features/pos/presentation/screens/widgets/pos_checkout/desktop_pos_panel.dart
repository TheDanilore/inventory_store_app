import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/pos/data/models/cart_item_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/pos/data/repositories/pos_checkout_service.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/pos_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/admin_sale_client_section.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/admin_sale_points_section.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/pos_cart_items_section.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/pos_total_summary_section.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/pos_dialogs.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/batch_edit_sheet.dart';

class DesktopPosPanel extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const DesktopPosPanel({super.key, this.onSaleCompleted});

  @override
  State<DesktopPosPanel> createState() => _DesktopPosPanelState();
}

class _DesktopPosPanelState extends State<DesktopPosPanel> {
  final PosCheckoutService _checkoutService = PosCheckoutService();

  // Controladores
  final _clienteCtrl = TextEditingController();
  final _puntosCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController();

  // BÃºsqueda de clientes
  List<Map<String, dynamic>> _clientMatches = [];
  bool _searchingClients = false;
  int _clientSearchVersion = 0;
  Timer? _debounce;

  bool _isDiscountPercentage = false;

  // AlmacÃ©n, Cuentas y Caja
  List<WarehouseModel> _warehouseList = [];
  List<Map<String, dynamic>> _accountsList = [];
  String? _selectedAccountId;
  Map<String, dynamic>? _activeShift;

  // CrÃ©dito del cliente seleccionado
  Map<String, dynamic>? _creditInfo;

  // Venta
  bool _isProcessingSale = false;
  bool _isLoadingInitialData = true;

  @override
  void initState() {
    super.initState();
    final pos = Provider.of<PosProvider>(context, listen: false);
    _clienteCtrl.text = pos.selectedClientName ?? '';
    _puntosCtrl.text = pos.puntosAUsar.toString();
    _loadInitialData(pos);
  }

  @override
  void dispose() {
    _clienteCtrl.dispose();
    _puntosCtrl.dispose();
    _descuentoCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData(PosProvider pos) async {
    try {
      final data = await _checkoutService.loadInitialData();
      final list = data['warehouses'] as List<WarehouseModel>;
      final accs = data['accounts'] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _warehouseList = list;
          if (pos.selectedWarehouseId == null && list.isNotEmpty) {
            pos.setWarehouse(list.first.id);
          }
          _accountsList = accs;
          if (accs.isNotEmpty) {
            final firstAcc = accs.firstWhere(
              (a) => a['type'] == 'CAJA',
              orElse: () => accs.first,
            );
            _selectedAccountId = firstAcc['id'] as String;

            if (pos.paymentMethod != 'CRÃ‰DITO') {
              final accountName = (firstAcc['name'] as String? ?? '');
              pos.setPaymentMethod(accountName);
            }

            _checkActiveShift();
          }
        });
      }

      if (pos.selectedClientId != null) {
        final creditResp = await _checkoutService.fetchClientCredit(
          pos.selectedClientId!,
        );
        if (mounted) {
          setState(() {
            _creditInfo = creditResp;
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
        orElse: () => <String, dynamic>{},
      );
      if (accountData['type'] != 'CAJA') {
        if (mounted) setState(() => _activeShift = null);
        return;
      }
      final shiftRes = await _checkoutService.checkActiveShift(
        _selectedAccountId!,
      );
      if (mounted) setState(() => _activeShift = shiftRes);
    } catch (e) {
      debugPrint('Error verificando turno de caja: $e');
    }
  }

  void _onClientSearchChanged(String query) {
    final pos = context.read<PosProvider>();
    if (pos.selectedClientId != null) {
      pos.setClient(null, null, 0);
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
          _clientMatches = response;
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
    final pos = context.read<PosProvider>();
    pos.setClient(
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
      if (mounted) setState(() => _creditInfo = creditResp);
    } catch (e) {
      debugPrint('Error cargando crÃ©dito: $e');
    }
  }

  Future<void> _processSale(PosProvider pos, {bool isDraft = false}) async {
    if (pos.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacÃ©n.',
        type: SnackbarType.error,
      );
      return;
    }
    if (pos.itemCount == 0) {
      AppSnackbar.show(
        context,
        message: 'La caja estÃ¡ vacÃ­a.',
        type: SnackbarType.error,
      );
      return;
    }

    final isCredito = pos.paymentMethod == 'CRÃ‰DITO';

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
      pos: pos,
      ratio: pointsToSolesRatio,
    );

    if (isCredito && !isDraft) {
      if (pos.selectedClientId == null) {
        AppSnackbar.show(
          context,
          message: 'Debes seleccionar un cliente para ventas a crÃ©dito.',
          type: SnackbarType.error,
        );
        return;
      }
      if (!PosCalculatorUtils.isCreditActivo(_creditInfo)) {
        AppSnackbar.show(
          context,
          message: 'El cliente no tiene lÃ­nea de crÃ©dito activa.',
          type: SnackbarType.error,
        );
        return;
      }

      final disp = PosCalculatorUtils.getCreditDisponible(_creditInfo);
      if (disp < totalFinal) {
        AppSnackbar.show(
          context,
          message:
              'CrÃ©dito insuficiente. Disponible: S/ ${disp.toStringAsFixed(2)}',
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
                  pos.selectedClientId != null
                      ? pos.selectedClientName
                      : _clienteCtrl.text.trim().isNotEmpty
                      ? _clienteCtrl.text.trim()
                      : null,
              paymentMethod: pos.paymentMethod,
              onConfirm: () {},
            ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isProcessingSale = true);

    try {
      final puntosUsados = PosCalculatorUtils.clampPointsValue(
        pos.puntosAUsar,
        pos,
        pointsToSolesRatio,
      );
      final totalProfit = PosCalculatorUtils.calcularGananciaTotal(
        discountText: _descuentoCtrl.text,
        isDiscountPercentage: _isDiscountPercentage,
        pos: pos,
        ratio: pointsToSolesRatio,
      );
      final descuentoExtra = PosCalculatorUtils.getCustomDiscountAmount(
        discountText: _descuentoCtrl.text,
        isDiscountPercentage: _isDiscountPercentage,
        pos: pos,
        ratio: pointsToSolesRatio,
      );

      final orderId = await _checkoutService.processSale(
        pos: pos,
        isDraft: isDraft,
        isCredito: isCredito,
        selectedAccountId: _selectedAccountId,
        activeShift: _activeShift,
        accountsList: _accountsList,
        pointsToSolesRatio: pointsToSolesRatio,
        earningRate: earningRate,
        puntosUsados: puntosUsados,
        totalFinal: totalFinal,
        totalProfit: totalProfit,
        descuentoExtra: descuentoExtra,
        customerManualName:
            _clienteCtrl.text.trim().isNotEmpty
                ? _clienteCtrl.text.trim()
                : null,
        getBatchOverride: (p, key) => p.batchOverrides[key],
      );

      pos.clearPos();
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

  Future<void> _showBatchEditSheet(CartItemModel item) async {
    final pos = context.read<PosProvider>();
    if (pos.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacÃ©n primero',
        type: SnackbarType.warning,
      );
      return;
    }

    try {
      final batches = await _checkoutService.fetchBatchesForVariant(
        item.variantId!,
        pos.selectedWarehouseId!,
      );
      if (batches.isEmpty) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message: 'No hay lotes con stock para este producto.',
          type: SnackbarType.warning,
        );
        return;
      }

      final saved = pos.batchOverrides[item.cartKey];
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
      final result = await showDialog(
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
                  productName: item.product.name,
                  variantLabel: item.variantLabel,
                  totalRequired: item.quantity,
                  batches: batches,
                ),
              ),
            ),
      );

      if (result != null && mounted) {
        setState(() {
          pos.setBatchOverride(item.cartKey, result);
        });
      }
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
                  Consumer<PosProvider>(
                    builder:
                        (context, pos, _) => IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Vaciar caja',
                          onPressed:
                              pos.itemCount == 0
                                  ? null
                                  : () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('Â¿Vaciar caja?'),
                                            content: const Text(
                                              'Se eliminarÃ¡n todos los productos de la caja actual.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(ctx),
                                                child: const Text(
                                                  'Cancelar',
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.danger,
                                                ),
                                                onPressed: () {
                                                  pos.clearPos();
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
                    Consumer<PosProvider>(
                      builder:
                          (context, pos, _) => PosCartItemsSection(
                            pos: pos,
                            onShowBatchEditSheet: _showBatchEditSheet,
                          ),
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
        Consumer<PosProvider>(
          builder: (context, pos, _) {
            final isCredito = pos.paymentMethod == 'CRÃ‰DITO';
            return AdminSaleClientSection(
              controller: _clienteCtrl,
              onSearchChanged: _onClientSearchChanged,
              searching: _searchingClients,
              matches: _clientMatches,
              selectedClientId: pos.selectedClientId,
              onClientTap: _selectClient,
              saldoActualCliente: pos.saldoActualCliente,
              creditInfo: _creditInfo,
              isCredito: isCredito,
              isLoyaltyEnabled: isLoyaltyEnabled,
            );
          },
        ),
        Consumer<PosProvider>(
          builder: (context, pos, _) {
            final isCredito = pos.paymentMethod == 'CRÃ‰DITO';
            return AdminSalePointsSection(
              show:
                  isLoyaltyEnabled &&
                  pos.selectedClientId != null &&
                  pos.saldoActualCliente > 0 &&
                  !isCredito,
              saldoActualCliente: pos.saldoActualCliente,
              maxPuntosAplicables: PosCalculatorUtils.maxPuntosAplicables(
                pos,
                ratio,
              ),
              pointsToSolesRatio: ratio,
              pointsController: _puntosCtrl,
              onPointsChanged: (p) {
                final next = PosCalculatorUtils.clampPointsValue(p, pos, ratio);
                pos.setPuntosAUsar(next);
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
        const _SectionTitle('ConfiguraciÃ³n de venta'),
        Consumer<PosProvider>(
          builder: (context, pos, _) {
            final isCredito = pos.paymentMethod == 'CRÃ‰DITO';
            return PaymentWarehouseAccountCard(
              paymentMethod: pos.paymentMethod,
              warehouseList: _warehouseList,
              selectedWarehouseId: pos.selectedWarehouseId,
              accountsList: _accountsList,
              selectedAccountId: _selectedAccountId,
              activeShift: _activeShift,
              isCredito: isCredito,
              onCreditoToggle: (isCredito) {
                if (isCredito) {
                  pos.setPaymentMethod('CRÃ‰DITO');
                  pos.setPuntosAUsar(0);
                  _puntosCtrl.text = '0';
                } else {
                  if (_selectedAccountId != null) {
                    final acc = _accountsList.firstWhere(
                      (a) => a['id'] == _selectedAccountId,
                      orElse: () => <String, dynamic>{},
                    );
                    final accName = acc['name'] as String? ?? 'EFECTIVO';
                    pos.setPaymentMethod(accName);
                  } else {
                    pos.setPaymentMethod('EFECTIVO');
                  }
                }
                setState(() {});
              },
              onWarehouseChanged: (v) => pos.setWarehouse(v),
              onAccountChanged: (v) {
                setState(() => _selectedAccountId = v);
                if (v != null) {
                  final acc = _accountsList.firstWhere(
                    (a) => a['id'] == v,
                    orElse: () => <String, dynamic>{},
                  );
                  final accName = acc['name'] as String? ?? 'OTRO';
                  pos.setPaymentMethod(accName);
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
    return Consumer<PosProvider>(
      builder: (context, pos, _) {
        final isCredito = pos.paymentMethod == 'CRÃ‰DITO';
        final puntosSeguros = PosCalculatorUtils.clampPointsValue(
          pos.puntosAUsar,
          pos,
          ratio,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCredito) ...[
              _CreditWarningCard(
                clienteSeleccionado: pos.selectedClientId != null,
                creditActivo: PosCalculatorUtils.isCreditActivo(_creditInfo),
                creditDisponible: PosCalculatorUtils.getCreditDisponible(
                  _creditInfo,
                ),
                totalFinal: PosCalculatorUtils.calcularTotalFinal(
                  discountText: _descuentoCtrl.text,
                  isDiscountPercentage: _isDiscountPercentage,
                  pos: pos,
                  ratio: ratio,
                ),
                creditInfo: _creditInfo,
              ),
              const SizedBox(height: 24),
            ],

            if (!isCredito) ...[
              _buildCustomDiscountCard(pos, ratio, puntosSeguros),
              const SizedBox(height: 24),
            ],

            PosTotalSummarySection(
              subtotalAntesDePuntos: pos.totalAmount,
              puntosAplicables: isCredito ? 0 : puntosSeguros,
              descuentoPuntos: isCredito ? 0 : puntosSeguros * ratio,
              isLoyaltyEnabled: isLoyaltyEnabled,
              descuentoExtra:
                  isCredito
                      ? 0
                      : PosCalculatorUtils.getCustomDiscountAmount(
                        discountText: _descuentoCtrl.text,
                        isDiscountPercentage: _isDiscountPercentage,
                        pos: pos,
                        ratio: ratio,
                      ),
              totalFinal: PosCalculatorUtils.calcularTotalFinal(
                discountText: _descuentoCtrl.text,
                isDiscountPercentage: _isDiscountPercentage,
                pos: pos,
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
    PosProvider pos,
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
                pos,
                ratio,
                puntosSeguros,
              );
              final amt =
                  _isDiscountPercentage ? (pos.totalAmount * (val / 100)) : val;
              if (amt > maxDiscount) {
                if (_isDiscountPercentage) {
                  final maxPerc = (maxDiscount / pos.totalAmount) * 100;
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
        child: Consumer<PosProvider>(
          builder: (context, pos, _) {
            final total = PosCalculatorUtils.calcularTotalFinal(
              discountText: _descuentoCtrl.text,
              isDiscountPercentage: _isDiscountPercentage,
              pos: pos,
              ratio: ratio,
            );
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    onPressed:
                        pos.itemCount == 0
                            ? null
                            : () => _processSale(pos, isDraft: true),
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
                        pos.itemCount == 0
                            ? null
                            : () => _processSale(pos, isDraft: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          pos.itemCount == 0
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
        'Selecciona un cliente para ver su crÃ©dito.',
        Icons.info_outline,
        Colors.blue,
      );
    }
    if (!creditActivo) {
      return _buildAlert(
        'El cliente no tiene crÃ©dito activo.',
        Icons.warning_amber_rounded,
        AppColors.danger,
      );
    }
    if (totalFinal > creditDisponible) {
      return _buildAlert(
        'CrÃ©dito insuficiente.\nDisp: S/ ${creditDisponible.toStringAsFixed(2)}\nLÃ­mite: S/ ${(creditInfo?['credit_limit'] ?? 0).toStringAsFixed(2)}',
        Icons.error_outline_rounded,
        AppColors.danger,
      );
    }

    return _buildAlert(
      'CrÃ©dito aprobado. Disp: S/ ${creditDisponible.toStringAsFixed(2)}',
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

