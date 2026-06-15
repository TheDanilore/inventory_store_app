import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_sale_client_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_sale_points_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/payment_warehouse_account_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/pos_cart_items_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/pos_total_summary_section.dart';
import 'package:inventory_store_app/screens/admin/widgets/pos_batch_edit_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/pos_processing_overlay.dart';
import 'package:inventory_store_app/services/admin/pos_checkout_service.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class AdminPosCheckoutScreen extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const AdminPosCheckoutScreen({super.key, this.onSaleCompleted});

  @override
  State<AdminPosCheckoutScreen> createState() => _AdminPosCheckoutScreenState();
}

class _AdminPosCheckoutScreenState extends State<AdminPosCheckoutScreen> {
  final PosCheckoutService _checkoutService = PosCheckoutService();

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
  Map<String, dynamic>? _activeShift;

  // Crédito del cliente seleccionado
  Map<String, dynamic>?
  _creditInfo; // {id, credit_limit, current_debt, is_active}

  // Venta
  bool _isProcessingSale = false;

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

  // ─── CARGA DE DATOS ──────────────────────────────────────────────────────

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

            if (pos.paymentMethod != 'CRÉDITO') {
              final accountName = (firstAcc['name'] as String? ?? '');
              pos.setPaymentMethod(accountName);
            }

            _checkActiveShift();
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos iniciales: $e');
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
      if (currentVersion == _clientSearchVersion && mounted)
        setState(() => _searchingClients = false);
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
      debugPrint('Error cargando crédito: $e');
    }
  }

  // ─── CÁLCULOS ────────────────────────────────────────────────────────────

  int _clampPointsValue(int desired, PosProvider pos, double ratio) {
    if (pos.selectedClientId == null) return 0;
    if (pos.saldoActualCliente <= 0) return 0;
    int maxPts = pos.saldoActualCliente;
    final total = pos.totalAmount;
    final maxPtsForTotal = (total / ratio).floor();
    if (maxPts > maxPtsForTotal) maxPts = maxPtsForTotal;
    if (desired > maxPts) return maxPts;
    if (desired < 0) return 0;
    return desired;
  }

  int _maxPuntosAplicables(PosProvider pos, double ratio) {
    if (pos.selectedClientId == null) return 0;
    if (pos.saldoActualCliente <= 0) return 0;
    final total = pos.totalAmount;
    final maxPtsForTotal = (total / ratio).floor();
    return pos.saldoActualCliente > maxPtsForTotal
        ? maxPtsForTotal
        : pos.saldoActualCliente;
  }

  double _getCustomDiscountAmount(PosProvider pos) {
    final raw = double.tryParse(_descuentoCtrl.text) ?? 0.0;
    if (raw <= 0) return 0.0;
    if (_isDiscountPercentage) {
      final config = context.read<AppConfigProvider>();
      final ratio = config.getDouble('points_to_soles_ratio', 0.01);
      final safePts = _clampPointsValue(pos.puntosAUsar, pos, ratio);
      final partial = pos.totalAmount - (safePts * ratio);
      return partial * (raw / 100).clamp(0.0, 1.0);
    }
    return raw;
  }

  double _calcularTotalFinal(PosProvider pos, double ratio) {
    final safePts = _clampPointsValue(pos.puntosAUsar, pos, ratio);
    final discExtra = _getCustomDiscountAmount(pos);
    final partial = pos.totalAmount - (safePts * ratio) - discExtra;
    return partial < 0 ? 0 : partial;
  }

  double _calcularGananciaTotal(PosProvider pos) {
    double totalNetProfit = 0;
    for (final item in pos.items.values) {
      totalNetProfit += (item.unitPrice - item.unitCost) * item.quantity;
    }
    final config = context.read<AppConfigProvider>();
    final ratio = config.getDouble('points_to_soles_ratio', 0.01);
    final safePts = _clampPointsValue(pos.puntosAUsar, pos, ratio);
    final totalDesc = (safePts * ratio) + _getCustomDiscountAmount(pos);
    return totalNetProfit - totalDesc;
  }

  bool get _creditActivo =>
      _creditInfo != null && _creditInfo!['is_active'] == true;

  double get _creditDisponible {
    if (_creditInfo == null || _creditInfo!['is_active'] != true) return 0.0;
    final limit = (_creditInfo!['credit_limit'] as num).toDouble();
    final debt = (_creditInfo!['current_debt'] as num).toDouble();
    final disp = limit - debt;
    return disp > 0 ? disp : 0;
  }

  Future<void> _processSale(PosProvider pos, {bool isDraft = false}) async {
    if (pos.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacén.',
        type: SnackbarType.error,
      );
      return;
    }
    if (pos.itemCount == 0) {
      AppSnackbar.show(
        context,
        message: 'La caja está vacía.',
        type: SnackbarType.error,
      );
      return;
    }

    final isCredito = pos.paymentMethod == 'CRÉDITO';

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

    if (isCredito && !isDraft) {
      if (pos.selectedClientId == null) {
        AppSnackbar.show(
          context,
          message: 'Debes seleccionar un cliente para ventas a crédito.',
          type: SnackbarType.error,
        );
        return;
      }
      if (!_creditActivo) {
        AppSnackbar.show(
          context,
          message: 'El cliente no tiene línea de crédito activa.',
          type: SnackbarType.error,
        );
        return;
      }
      final config = context.read<AppConfigProvider>();
      final ratio = config.getDouble('points_to_soles_ratio', 0.01);
      final totalNecesario = _calcularTotalFinal(pos, ratio);
      if (_creditDisponible < totalNecesario) {
        AppSnackbar.show(
          context,
          message:
              'Crédito insuficiente. Disponible: S/ ${_creditDisponible.toStringAsFixed(2)}',
          type: SnackbarType.error,
        );
        return;
      }
    }

    setState(() => _isProcessingSale = true);

    try {
      final config = context.read<AppConfigProvider>();
      final pointsToSolesRatio = config.getDouble(
        'points_to_soles_ratio',
        0.01,
      );
      final earningRate = config.getDouble('points_earning_rate', 0.03);

      final puntosUsados = _clampPointsValue(
        pos.puntosAUsar,
        pos,
        pointsToSolesRatio,
      );
      final totalFinal = _calcularTotalFinal(pos, pointsToSolesRatio);
      final totalProfit = _calcularGananciaTotal(pos);
      final descuentoExtra = _getCustomDiscountAmount(pos);

      await _checkoutService.processSale(
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
        AppSnackbar.show(
          context,
          message:
              isDraft ? 'Borrador guardado.' : 'Venta procesada exitosamente.',
          type: SnackbarType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppSnackbar.show(context, message: 'Error: $e', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
    }
  }

  Future<void> _showBatchEditSheet(CartItemModel item) async {
    final pos = context.read<PosProvider>();
    if (pos.selectedWarehouseId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un almacén primero',
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
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => PosBatchEditSheet(
              productName: item.product.name,
              variantLabel: item.variantLabel,
              totalRequired: item.quantity,
              batches: batches,
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

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final config = context.watch<AppConfigProvider>();
    final pointsToSolesRatio = config.getDouble('points_to_soles_ratio', 0.01);
    final earningRate = config.getDouble('points_earning_rate', 0.03);
    final puntosSeguros = _clampPointsValue(
      pos.puntosAUsar,
      pos,
      pointsToSolesRatio,
    );
    final descuentoExtra = _getCustomDiscountAmount(pos);
    final descuentoExcedido =
        descuentoExtra >
        (pos.totalAmount - (puntosSeguros * pointsToSolesRatio));

    final isCredito = pos.paymentMethod == 'CRÉDITO';
    final totalFinal = _calcularTotalFinal(pos, pointsToSolesRatio);

    final creditoInsuficiente =
        isCredito &&
        pos.selectedClientId != null &&
        _creditInfo != null &&
        _creditDisponible < totalFinal;
    final creditoSinCliente = isCredito && pos.selectedClientId == null;
    final isCajaAccount = _accountsList.any(
      (a) => a['id'] == _selectedAccountId && a['type'] == 'CAJA',
    );
    final noCajaAbierta =
        !isCredito &&
        _selectedAccountId != null &&
        isCajaAccount &&
        _activeShift == null;

    final puedeVender =
        pos.itemCount > 0 &&
        !descuentoExcedido &&
        !creditoInsuficiente &&
        !creditoSinCliente &&
        !noCajaAbierta;

    final bodyContent = Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosSectionLabel('Productos en caja'),
              PosCartItemsSection(
                pos: pos,
                onShowBatchEditSheet: _showBatchEditSheet,
              ),
              const SizedBox(height: 20),

              PosSectionLabel('Cliente'),
              AdminSaleClientSection(
                controller: _clienteCtrl,
                onSearchChanged: _onClientSearchChanged,
                searching: _searchingClients,
                matches: _clientMatches,
                selectedClientId: pos.selectedClientId,
                onClientTap: _selectClient,
                saldoActualCliente: pos.saldoActualCliente,
                creditInfo: _creditInfo,
                isCredito: isCredito,
              ),

              AdminSalePointsSection(
                show:
                    pos.selectedClientId != null &&
                    pos.saldoActualCliente > 0 &&
                    !isCredito,
                saldoActualCliente: pos.saldoActualCliente,
                maxPuntosAplicables: _maxPuntosAplicables(
                  pos,
                  pointsToSolesRatio,
                ),
                pointsToSolesRatio: pointsToSolesRatio,
                pointsController: _puntosCtrl,
                onPointsChanged: (p) {
                  final next = _clampPointsValue(p, pos, pointsToSolesRatio);
                  pos.setPuntosAUsar(next);
                  _puntosCtrl.value = TextEditingValue(
                    text: next.toString(),
                    selection: TextSelection.collapsed(
                      offset: next.toString().length,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              PosSectionLabel('Configuración de venta'),
              PaymentWarehouseAccountCard(
                paymentMethod: pos.paymentMethod,
                warehouseList: _warehouseList,
                selectedWarehouseId: pos.selectedWarehouseId,
                accountsList: _accountsList,
                selectedAccountId: _selectedAccountId,
                activeShift: _activeShift,
                isCredito: isCredito,
                onCreditoToggle: (isCredito) {
                  if (isCredito) {
                    pos.setPaymentMethod('CRÉDITO');
                    pos.setPuntosAUsar(0);
                    _puntosCtrl.text = '0';
                  } else {
                    if (_selectedAccountId != null) {
                      final acc = _accountsList.firstWhere(
                        (a) => a['id'] == _selectedAccountId,
                        orElse: () => {},
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
                      orElse: () => {},
                    );
                    final accName = acc['name'] as String? ?? 'OTRO';
                    pos.setPaymentMethod(accName);
                  }
                  _checkActiveShift();
                },
              ),
              const SizedBox(height: 20),

              if (isCredito)
                _CreditWarningCard(
                  clienteSeleccionado: pos.selectedClientId != null,
                  creditActivo: _creditActivo,
                  creditDisponible: _creditDisponible,
                  totalFinal: totalFinal,
                  creditInfo: _creditInfo,
                ),
              if (isCredito) const SizedBox(height: 20),

              if (!isCredito)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppColors.radius),
                    border: Border.all(
                      color:
                          descuentoExcedido
                              ? AppColors.danger
                              : AppColors.border,
                    ),
                    boxShadow: AppColors.cardShadow(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PosSectionLabel('Descuento extra'),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusSm + 2,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _descuentoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusSm + 2,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => setState(
                                            () => _isDiscountPercentage = false,
                                          ),
                                      child: Container(
                                        color:
                                            !_isDiscountPercentage
                                                ? AppColors.teal.withValues(
                                                  alpha: 0.1,
                                                )
                                                : Colors.transparent,
                                        alignment: Alignment.center,
                                        child: Text(
                                          'S/',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                !_isDiscountPercentage
                                                    ? AppColors.teal
                                                    : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(width: 1, color: AppColors.border),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => setState(
                                            () => _isDiscountPercentage = true,
                                          ),
                                      child: Container(
                                        color:
                                            _isDiscountPercentage
                                                ? AppColors.teal.withValues(
                                                  alpha: 0.1,
                                                )
                                                : Colors.transparent,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                _isDiscountPercentage
                                                    ? AppColors.teal
                                                    : AppColors.textMuted,
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
                                  'No puede superar los S/ ${(pos.totalAmount - (puntosSeguros * pointsToSolesRatio)).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (!isCredito) const SizedBox(height: 16),

              PosTotalSummarySection(
                subtotalAntesDePuntos: pos.totalAmount,
                puntosAplicables: isCredito ? 0 : puntosSeguros,
                descuentoPuntos:
                    isCredito ? 0 : puntosSeguros * pointsToSolesRatio,
                descuentoExtra: isCredito ? 0 : _getCustomDiscountAmount(pos),
                totalFinal: totalFinal,
                pointsToSolesRatio: pointsToSolesRatio,
                earningRate: earningRate,
                isCredito: isCredito,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: PosConfirmButton(
                      loading: _isProcessingSale,
                      enabled: puedeVender,
                      label: isCredito ? 'Vender a crédito' : 'Confirmar venta',
                      onPressed: () => _processSale(pos, isDraft: false),
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
                                      pos.itemCount == 0 ||
                                      descuentoExcedido)
                                  ? null
                                  : () => _processSale(pos, isDraft: true),
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
                          child: const Icon(Icons.save_as_rounded, size: 22),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        PosProcessingOverlay(isVisible: _isProcessingSale),
      ],
    );

    return AdminLayout(
      title: 'Caja POS',
      showBackButton: true,
      body: bodyContent,
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
