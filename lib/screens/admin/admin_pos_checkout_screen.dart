import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class AdminPosCheckoutScreen extends StatefulWidget {
  const AdminPosCheckoutScreen({super.key});

  @override
  State<AdminPosCheckoutScreen> createState() => _AdminPosCheckoutScreenState();
}

class _AdminPosCheckoutScreenState extends State<AdminPosCheckoutScreen> {
  final _supabase = Supabase.instance.client;

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

  // Almacén
  List<WarehouseModel> _warehouseList = [];

  // Crédito del cliente seleccionado
  Map<String, dynamic>?
  _creditInfo; // {id, credit_limit, current_debt, is_active}

  // Venta
  bool _isProcessingSale = false;

  final List<String> _paymentMethods = [
    'EFECTIVO',
    'YAPE',
    'PLIN',
    'TARJETA',
    'TRANSFERENCIA',
    'CRÉDITO',
  ];

  static const Map<String, IconData> _paymentIcons = {
    'EFECTIVO': Icons.payments_rounded,
    'YAPE': Icons.smartphone_rounded,
    'PLIN': Icons.phone_android_rounded,
    'TARJETA': Icons.credit_card_rounded,
    'TRANSFERENCIA': Icons.account_balance_rounded,
    'CRÉDITO': Icons.handshake_rounded,
  };

  @override
  void initState() {
    super.initState();
    final pos = Provider.of<PosProvider>(context, listen: false);
    _clienteCtrl.text = pos.selectedClientName ?? '';
    _puntosCtrl.text = pos.puntosAUsar.toString();
    _loadWarehouses(pos);
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

  Future<void> _loadWarehouses(PosProvider pos) async {
    try {
      final response = await _supabase
          .from('warehouses')
          .select()
          .eq('is_active', true)
          .order('name');
      final list =
          (response as List).map((w) => WarehouseModel.fromJson(w)).toList();
      if (mounted) {
        setState(() {
          _warehouseList = list;
          if (pos.selectedWarehouseId == null && list.isNotEmpty) {
            pos.setWarehouse(list.first.id);
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando almacenes: $e');
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
      // CORRECCIÓN: filtramos clientes activos y por rol customer
      final response = await _supabase
          .from('profiles')
          .select(
            'id, full_name, phone, document_number, wallet_balance, role, is_active',
          )
          .eq('is_active', true)
          .or(
            'full_name.ilike.%$text%,document_number.ilike.%$text%,phone.ilike.%$text%',
          )
          .limit(10);
      if (currentVersion == _clientSearchVersion && mounted) {
        setState(() {
          _clientMatches = List<Map<String, dynamic>>.from(response);
          _searchingClients = false;
        });
      }
    } catch (e) {
      if (currentVersion == _clientSearchVersion && mounted) {
        setState(() => _searchingClients = false);
      }
    }
  }

  /// Seleccionar cliente y cargar su info de crédito en paralelo
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

    // Cargar crédito del cliente en segundo plano
    try {
      final creditResp =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', client['id'] as String)
              .maybeSingle();
      if (mounted) {
        setState(() => _creditInfo = creditResp);
      }
    } catch (e) {
      debugPrint('Error cargando crédito: $e');
    }
  }

  // ─── HELPERS CRÉDITO ─────────────────────────────────────────────────────

  double get _creditDisponible {
    if (_creditInfo == null) return 0;
    if (_creditInfo!['is_active'] != true) return 0;
    final limit = (_creditInfo!['credit_limit'] as num).toDouble();
    final debt = (_creditInfo!['current_debt'] as num).toDouble();
    return (limit - debt).clamp(0.0, double.infinity);
  }

  bool get _creditActivo =>
      _creditInfo != null && _creditInfo!['is_active'] == true;

  // ─── LÓGICA PUNTOS / TOTALES ────────────────────────────────────────────

  double _wholesalePriceOf(CartItemModel item) =>
      item.wholesalePrice ?? item.product.wholesalePrice ?? item.unitPrice;

  double _maxDiscountSoles(PosProvider pos) {
    double total = 0;
    for (final item in pos.items.values) {
      final margin = (item.unitPrice - _wholesalePriceOf(item)).clamp(
        0.0,
        double.infinity,
      );
      total += margin * item.quantity;
    }
    return total;
  }

  int _maxPuntosAplicables(PosProvider pos, double ratio) =>
      (_maxDiscountSoles(pos) / ratio).toInt();

  int _clampPointsValue(int requested, PosProvider pos, double ratio) {
    final maxPuntos = _maxPuntosAplicables(pos, ratio);
    final limit =
        pos.saldoActualCliente > maxPuntos ? maxPuntos : pos.saldoActualCliente;
    if (requested < 0) return 0;
    if (requested > limit) return limit;
    return requested;
  }

  double _getCustomDiscountAmount(PosProvider pos) {
    double val = double.tryParse(_descuentoCtrl.text) ?? 0.0;
    if (val <= 0) return 0.0;
    if (_isDiscountPercentage) {
      return pos.totalAmount * (val / 100);
    }
    return val;
  }

  double _calcularTotalFinal(PosProvider pos, double ratio) {
    final puntos = _clampPointsValue(pos.puntosAUsar, pos, ratio);
    final descuentoPuntos = puntos * ratio;
    final descuentoExtra = _getCustomDiscountAmount(pos);
    final total = pos.totalAmount - descuentoPuntos - descuentoExtra;
    return total < 0 ? 0.0 : total;
  }

  double _calcularGananciaTotal(PosProvider pos) {
    double profit = 0;
    for (final item in pos.items.values) {
      // Usamos unitCost del item (igual que lo que se guarda en order_items.unit_cost)
      profit += (item.unitPrice - item.product.unitCost) * item.quantity;
    }
    return profit;
  }

  // ─── PROCESAR VENTA ─────────────────────────────────────────────────────
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

    // ── Validaciones previas para CRÉDITO ────────────────────────────────
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

    // No tiene sentido guardar un BORRADOR como crédito (el crédito se activa al completar)
    // Así que si es borrador + crédito, lo guardamos como POR ACORDAR en el insert
    // y mantenemos el método como CRÉDITO para cuando se active desde orders_screen.

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
      final puntosGanados =
          isDraft ? 0 : (totalFinal * earningRate / pointsToSolesRatio).toInt();

      final orderStatus = isDraft ? 'PENDING' : 'COMPLETED';

      // ─── 1. OBTENER PERFIL DEL USUARIO ADMIN ────────────────────────────
      final authUserId = _supabase.auth.currentUser?.id;
      final profileResp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId!)
              .single();
      final String currentProfileId = profileResp['id'];

      // ─── 2. STOCK (FEFO) — solo en venta directa, no borrador ───────────
      List<Map<String, dynamic>> batchUpdates = [];
      List<Map<String, dynamic>> movementInserts = [];

      if (!isDraft) {
        for (final item in pos.items.values) {
          final safeVariantId = item.variantId!;

          final batches = await _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity, batch_number')
              .eq('variant_id', safeVariantId)
              .eq('warehouse_id', pos.selectedWarehouseId!)
              .gt('available_quantity', 0)
              .order('expiry_date', ascending: true, nullsFirst: false);

          int remaining = item.quantity;
          for (final batch in (batches as List)) {
            if (remaining <= 0) break;
            final int available = (batch['available_quantity'] as num).toInt();
            final int take = (remaining > available) ? available : remaining;

            batchUpdates.add({
              'id': batch['id'],
              'new_quantity': available - take,
            });
            movementInserts.add({
              'variant_id': safeVariantId,
              'warehouse_id': pos.selectedWarehouseId,
              'stock_batch_id': batch['id'],
              'quantity': -take,
              'previous_stock': available,
              'new_stock': available - take,
              'unit_cost': item.product.unitCost,
              'reason': 'SALE',
              'notes': 'Venta POS - ${pos.paymentMethod}',
              'created_by': currentProfileId,
            });
            remaining -= take;
          }

          if (remaining > 0) {
            throw Exception('Stock insuficiente para ${item.product.name}');
          }
        }
      }

      // ─── 3. CREAR ORDEN ──────────────────────────────────────────────────
      // Determinamos payment_status y amount_paid según el método
      String paymentStatus;
      double amountPaid;

      if (isDraft) {
        // El borrador aún no se ha cobrado
        paymentStatus = 'PENDING';
        amountPaid = 0;
      } else if (isCredito) {
        // Crédito: el total va a deuda, no se cobró en caja
        paymentStatus = 'PENDING';
        amountPaid = 0;
      } else {
        // Todos los demás métodos: cobrado al contado
        paymentStatus = 'PAID';
        amountPaid = totalFinal;
      }

      final orderResp =
          await _supabase
              .from('orders')
              .insert({
                'customer_id': pos.selectedClientId,
                // Si no hay cliente registrado pero se escribió un nombre libre, lo guardamos
                'customer_name':
                    pos.selectedClientId == null
                        ? (_clienteCtrl.text.trim().isNotEmpty
                            ? _clienteCtrl.text.trim()
                            : null)
                        : null,
                'warehouse_id': pos.selectedWarehouseId,
                'total_amount': totalFinal,
                'total_profit': totalProfit,
                'discount_amount': descuentoExtra,
                'payment_method': pos.paymentMethod,
                'payment_status': paymentStatus,
                'amount_paid': amountPaid,
                'status': orderStatus,
                'points_used': isDraft ? 0 : puntosUsados,
                'points_earned': puntosGanados,
                'created_by': currentProfileId,
              })
              .select('id')
              .single();

      final orderId = orderResp['id'];

      // ─── 4. GUARDAR ITEMS ────────────────────────────────────────────────
      for (final item in pos.items.values) {
        await _supabase.from('order_items').insert({
          'order_id': orderId,
          'product_id': item.product.id,
          'variant_id': item.variantId,
          'quantity': item.quantity,
          'unit_cost': item.product.unitCost,
          'applied_price': item.unitPrice,
          'net_profit':
              (item.unitPrice - item.product.unitCost) * item.quantity,
        });
      }

      // ─── 5. ACTUALIZAR LOTES Y REGISTRAR KARDEX ─────────────────────────
      if (!isDraft) {
        for (final up in batchUpdates) {
          await _supabase
              .from('warehouse_stock_batches')
              .update({'available_quantity': up['new_quantity']})
              .eq('id', up['id']);
        }
        for (final mov in movementInserts) {
          mov['order_id'] = orderId;
          await _supabase.from('inventory_movements').insert(mov);
        }
      }

      // ─── 6. PUNTOS (WALLET) — solo en venta directa con cliente ─────────
      if (!isDraft && pos.selectedClientId != null) {
        // 6a. Canjear puntos usados
        if (puntosUsados > 0) {
          // Descontar del saldo en profiles.wallet_balance
          final profileData =
              await _supabase
                  .from('profiles')
                  .select('wallet_balance')
                  .eq('id', pos.selectedClientId!)
                  .single();
          final currentBalance = (profileData['wallet_balance'] as num).toInt();
          final newBalance = (currentBalance - puntosUsados).clamp(
            0,
            currentBalance,
          );

          await _supabase
              .from('profiles')
              .update({'wallet_balance': newBalance})
              .eq('id', pos.selectedClientId!);

          await _supabase.from('wallet_movements').insert({
            'profile_id': pos.selectedClientId,
            'order_id': orderId,
            'points': -puntosUsados,
            'movement_type': 'REDEEMED',
            'description': 'Canje de monedas en venta POS #$orderId',
          });
        }

        // 6b. Acumular puntos ganados
        if (puntosGanados > 0) {
          final profileData =
              await _supabase
                  .from('profiles')
                  .select('wallet_balance')
                  .eq('id', pos.selectedClientId!)
                  .single();
          final currentBalance = (profileData['wallet_balance'] as num).toInt();

          await _supabase
              .from('profiles')
              .update({'wallet_balance': currentBalance + puntosGanados})
              .eq('id', pos.selectedClientId!);

          await _supabase.from('wallet_movements').insert({
            'profile_id': pos.selectedClientId,
            'order_id': orderId,
            'points': puntosGanados,
            'movement_type': 'EARNED',
            'description': 'Monedas ganadas en venta POS #$orderId',
          });
        }
      }

      // ─── 7. CRÉDITO — cargar deuda al cliente ───────────────────────────
      if (!isDraft && isCredito && pos.selectedClientId != null) {
        // Re-leemos la deuda actual en el momento de insertar (dato fresco)
        final latestCredit =
            await _supabase
                .from('customer_credits')
                .select('id, current_debt')
                .eq('profile_id', pos.selectedClientId!)
                .single();

        final creditId = latestCredit['id'] as String;
        final currentDebt = (latestCredit['current_debt'] as num).toDouble();
        final newDebt = currentDebt + totalFinal;

        await _supabase
            .from('customer_credits')
            .update({
              'current_debt': newDebt,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', creditId);

        await _supabase.from('credit_movements').insert({
          'credit_id': creditId,
          'order_id': orderId,
          'movement_type': 'CHARGE',
          'amount': totalFinal,
          'payment_method': 'CRÉDITO',
          'notes': 'Cargo por venta POS',
          'created_by': currentProfileId,
        });
      }

      pos.clearPos();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // ignore: use_build_context_synchronously
      AppSnackbar.show(context, message: 'Error: $e', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
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

    // CRÉDITO insuficiente bloquea el botón de venta directa
    final creditoInsuficiente =
        isCredito &&
        pos.selectedClientId != null &&
        _creditInfo != null &&
        _creditDisponible < totalFinal;

    // Sin cliente en modo crédito bloquea la venta
    final creditoSinCliente = isCredito && pos.selectedClientId == null;

    final puedeVender =
        pos.itemCount > 0 &&
        !descuentoExcedido &&
        !creditoInsuficiente &&
        !creditoSinCliente;

    return AdminLayout(
      title: 'Caja POS',
      showBackButton: true,
      body:
          _isProcessingSale
              ? const _ProcessingOverlay()
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. PRODUCTOS EN CAJA ──────────────────────────────
                    _SectionLabel(
                      icon: Icons.shopping_cart_rounded,
                      label: 'Productos en caja',
                      trailing: Text(
                        '${pos.itemCount} item${pos.itemCount != 1 ? "s" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CartItemsList(pos: pos),
                    const SizedBox(height: 20),

                    // ── 2. CLIENTE ────────────────────────────────────────
                    _SectionLabel(
                      icon: Icons.person_search_rounded,
                      label: 'Cliente',
                      trailing: const Text(
                        'Opcional',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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

                    // ── 3. PUNTOS ─────────────────────────────────────────
                    AdminSalePointsSection(
                      // Solo mostrar puntos si NO es venta a crédito (no tiene sentido combinar)
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
                        final next = _clampPointsValue(
                          p,
                          pos,
                          pointsToSolesRatio,
                        );
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

                    // ── 4. PAGO Y ALMACÉN ─────────────────────────────────
                    _SectionLabel(
                      icon: Icons.tune_rounded,
                      label: 'Configuración de venta',
                    ),
                    const SizedBox(height: 8),
                    _PaymentAndWarehouseCard(
                      paymentMethod: pos.paymentMethod,
                      paymentMethods: _paymentMethods,
                      paymentIcons: _paymentIcons,
                      warehouseList: _warehouseList,
                      selectedWarehouseId: pos.selectedWarehouseId,
                      onPaymentChanged: (v) {
                        pos.setPaymentMethod(v!);
                        // Si cambia de crédito, limpiar puntos
                        if (v != 'CRÉDITO') {
                          // no-op, puntos se siguen mostrando
                        } else {
                          // Al seleccionar crédito, limpiamos puntos (incompatibles)
                          pos.setPuntosAUsar(0);
                          _puntosCtrl.text = '0';
                        }
                        setState(() {});
                      },
                      onWarehouseChanged: (v) => pos.setWarehouse(v),
                    ),
                    const SizedBox(height: 20),

                    // ── AVISO DE CRÉDITO ──────────────────────────────────
                    if (isCredito)
                      _CreditWarningCard(
                        clienteSeleccionado: pos.selectedClientId != null,
                        creditActivo: _creditActivo,
                        creditDisponible: _creditDisponible,
                        totalFinal: totalFinal,
                        creditInfo: _creditInfo,
                      ),
                    if (isCredito) const SizedBox(height: 20),

                    // ── DESCUENTO EXTRA (ocultar en crédito) ─────────────
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
                            const _SectionLabel(
                              icon: Icons.discount_rounded,
                              label: 'Descuento extra',
                            ),
                            const SizedBox(height: 12),
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
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
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
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap:
                                                () => setState(
                                                  () =>
                                                      _isDiscountPercentage =
                                                          false,
                                                ),
                                            child: Container(
                                              color:
                                                  !_isDiscountPercentage
                                                      ? AppColors.teal
                                                          .withValues(
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
                                        Container(
                                          width: 1,
                                          color: AppColors.border,
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap:
                                                () => setState(
                                                  () =>
                                                      _isDiscountPercentage =
                                                          true,
                                                ),
                                            child: Container(
                                              color:
                                                  _isDiscountPercentage
                                                      ? AppColors.teal
                                                          .withValues(
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

                    // ── 5. RESUMEN TOTAL ──────────────────────────────────
                    AdminSaleTotalSummarySection(
                      subtotalAntesDePuntos: pos.totalAmount,
                      puntosAplicables: isCredito ? 0 : puntosSeguros,
                      descuentoPuntos:
                          isCredito ? 0 : puntosSeguros * pointsToSolesRatio,
                      descuentoExtra:
                          isCredito ? 0 : _getCustomDiscountAmount(pos),
                      totalFinal: totalFinal,
                      pointsToSolesRatio: pointsToSolesRatio,
                      earningRate: earningRate,
                      isCredito: isCredito,
                    ),
                    const SizedBox(height: 16),

                    // ── 6. BOTONES DE ACCIÓN ──────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: AdminSaleConfirmButton(
                            loading: _isProcessingSale,
                            enabled: puedeVender,
                            label:
                                isCredito
                                    ? 'Vender a crédito'
                                    : 'Confirmar venta',
                            onPressed: () => _processSale(pos, isDraft: false),
                          ),
                        ),
                        // El borrador NO se muestra si es crédito (no tiene sentido)
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
                                        : () =>
                                            _processSale(pos, isDraft: true),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.teal,
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(
                                    color: AppColors.teal.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radius,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.save_as_rounded,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}

// ─── CREDIT WARNING CARD ─────────────────────────────────────────────────────

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
    // Sin cliente seleccionado
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

    // Cliente sin crédito activo
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
              _CreditRow(
                label: 'Límite',
                value: 'S/ ${limit.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 12),
              _CreditRow(
                label: 'Deuda actual',
                value: 'S/ ${debt.toStringAsFixed(2)}',
                valueColor: Colors.deepOrange,
              ),
              const SizedBox(width: 12),
              _CreditRow(
                label: 'Disponible',
                value: 'S/ ${creditDisponible.toStringAsFixed(2)}',
                valueColor: insuficiente ? Colors.red : Colors.green.shade800,
                bold: true,
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

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _CreditRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PROCESSING OVERLAY ───────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Procesando venta…',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Por favor espera un momento',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION LABEL ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _SectionLabel({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: AppColors.teal),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ─── CART ITEMS LIST ─────────────────────────────────────────────────────────

class _CartItemsList extends StatelessWidget {
  final PosProvider pos;
  const _CartItemsList({required this.pos});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        children: [
          ...pos.items.values.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == pos.items.length - 1;
            return Column(
              children: [
                _CartItemRow(item: item, pos: pos),
                if (!isLast)
                  const Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 60,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItemModel item;
  final PosProvider pos;

  const _CartItemRow({required this.item, required this.pos});

  Future<void> _mostrarDialogoCantidad(BuildContext context) async {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Cantidad exacta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText: 'Stock máximo: ${item.availableStock}',
                helperStyle: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty > 0) {
                    pos.setQuantity(item.cartKey, newQty);
                  }
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child:
                item.imageUrl != null
                    ? Image.network(
                      item.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                    : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (item.variantLabel != null)
                  Text(
                    item.variantLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Selector de cantidad
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap:
                                item.quantity > 1
                                    ? () => pos.setQuantity(
                                      item.cartKey,
                                      item.quantity - 1,
                                    )
                                    : null,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(6),
                            ),
                            child: Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.remove_rounded,
                                size: 14,
                                color:
                                    item.quantity > 1
                                        ? AppColors.textSecondary
                                        : AppColors.textHint,
                              ),
                            ),
                          ),
                          Material(
                            color: AppColors.tealLight.withValues(alpha: 0.3),
                            child: InkWell(
                              onTap: () => _mostrarDialogoCantidad(context),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                alignment: Alignment.center,
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap:
                                item.quantity < item.availableStock
                                    ? () => pos.setQuantity(
                                      item.cartKey,
                                      item.quantity + 1,
                                    )
                                    : null,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(6),
                            ),
                            child: Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add_rounded,
                                size: 14,
                                color:
                                    item.quantity < item.availableStock
                                        ? AppColors.textSecondary
                                        : AppColors.textHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'S/ ${item.unitPrice.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${item.totalItemPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => pos.removeProduct(item.cartKey),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PAYMENT & WAREHOUSE CARD ────────────────────────────────────────────────

class _PaymentAndWarehouseCard extends StatelessWidget {
  final String paymentMethod;
  final List<String> paymentMethods;
  final Map<String, IconData> paymentIcons;
  final List<WarehouseModel> warehouseList;
  final String? selectedWarehouseId;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<String?> onWarehouseChanged;

  const _PaymentAndWarehouseCard({
    required this.paymentMethod,
    required this.paymentMethods,
    required this.paymentIcons,
    required this.warehouseList,
    required this.selectedWarehouseId,
    required this.onPaymentChanged,
    required this.onWarehouseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  paymentMethods.map((method) {
                    final selected = paymentMethod == method;
                    final isCredito = method == 'CRÉDITO';
                    return GestureDetector(
                      onTap: () => onPaymentChanged(method),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color:
                              selected
                                  ? (isCredito
                                      ? Colors.deepOrange
                                      : AppColors.teal)
                                  : AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                selected
                                    ? (isCredito
                                        ? Colors.deepOrange
                                        : AppColors.teal)
                                    : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              paymentIcons[method] ?? Icons.payment_rounded,
                              size: 14,
                              color:
                                  selected
                                      ? Colors.white
                                      : (isCredito
                                          ? Colors.deepOrange
                                          : AppColors.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              method,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    selected
                                        ? Colors.white
                                        : (isCredito
                                            ? Colors.deepOrange
                                            : AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),

          if (warehouseList.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),
            const Text(
              'Almacén de origen',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedWarehouseId,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                  items:
                      warehouseList.map((w) {
                        return DropdownMenuItem<String>(
                          value: w.id,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warehouse_rounded,
                                size: 16,
                                color: AppColors.teal,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                w.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: onWarehouseChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── CLIENT SECTION ───────────────────────────────────────────────────────────

typedef ClientTapCallback = void Function(Map<String, dynamic> client);

class AdminSaleClientSection extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final bool searching;
  final List<Map<String, dynamic>> matches;
  final String? selectedClientId;
  final ClientTapCallback onClientTap;
  final int saldoActualCliente;
  final Map<String, dynamic>? creditInfo; // NUEVO
  final bool isCredito; // NUEVO

  const AdminSaleClientSection({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.searching,
    required this.matches,
    required this.selectedClientId,
    required this.onClientTap,
    required this.saldoActualCliente,
    required this.creditInfo,
    required this.isCredito,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: selectedClientId != null ? AppColors.teal : AppColors.border,
          width: selectedClientId != null ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, teléfono o documento…',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (searching)
            const _ClientSearchState(
              icon: null,
              isLoading: true,
              message: 'Buscando clientes…',
            )
          else if (selectedClientId != null)
            _SelectedClientBanner(
              saldo: saldoActualCliente,
              creditInfo: creditInfo,
              isCredito: isCredito,
            )
          else if (controller.text.trim().isEmpty)
            const _ClientSearchState(
              icon: Icons.person_search_rounded,
              message: 'Busca un cliente o ingresa un nombre para el ticket.',
            )
          else if (matches.isEmpty)
            _ClientSearchState(
              icon: Icons.person_add_alt_1_rounded,
              message: 'Venta libre a nombre de: "${controller.text.trim()}"',
              isHighlight: true,
            )
          else
            _ClientMatchesList(
              matches: matches,
              selectedClientId: selectedClientId,
              onClientTap: onClientTap,
            ),
        ],
      ),
    );
  }
}

class _ClientSearchState extends StatelessWidget {
  final IconData? icon;
  final bool isLoading;
  final String message;
  final bool isHighlight;

  const _ClientSearchState({
    this.icon,
    this.isLoading = false,
    required this.message,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlight ? AppColors.teal : AppColors.textMuted;
    return Row(
      children: [
        if (isLoading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.teal),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedClientBanner extends StatelessWidget {
  final int saldo;
  final Map<String, dynamic>? creditInfo;
  final bool isCredito;

  const _SelectedClientBanner({
    required this.saldo,
    required this.creditInfo,
    required this.isCredito,
  });

  @override
  Widget build(BuildContext context) {
    // En modo crédito, mostramos info del crédito en vez de saldo de puntos
    if (isCredito && creditInfo != null) {
      final isActive = creditInfo!['is_active'] == true;
      final limit = (creditInfo!['credit_limit'] as num).toDouble();
      final debt = (creditInfo!['current_debt'] as num).toDouble();
      final disponible = (limit - debt).clamp(0.0, double.infinity);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle_rounded : Icons.block_rounded,
              color: isActive ? AppColors.success : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente seleccionado · ${isActive ? "Crédito activo" : "Sin crédito activo"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.success : Colors.red,
                    ),
                  ),
                  if (isActive)
                    Text(
                      'Disponible: S/ ${disponible.toStringAsFixed(2)} de S/ ${limit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: disponible > 0 ? AppColors.success : Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Modo normal: mostrar saldo de monedas
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cliente seleccionado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                if (saldo > 0)
                  Text(
                    '$saldo monedas disponibles',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientMatchesList extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final String? selectedClientId;
  final ClientTapCallback onClientTap;

  const _ClientMatchesList({
    required this.matches,
    required this.selectedClientId,
    required this.onClientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          separatorBuilder:
              (_, __) => const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, index) {
            final client = matches[index];
            final name = client['full_name'] as String? ?? 'Cliente';
            final doc = client['document_number'] as String?;
            final phone = client['phone'] as String?;
            final wallet = (client['wallet_balance'] as num?)?.toInt() ?? 0;
            final isSelected = selectedClientId == client['id'];

            return GestureDetector(
              onTap: () => onClientTap(client),
              child: Container(
                color: isSelected ? AppColors.tealLight : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teal : AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.teal : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  isSelected
                                      ? AppColors.tealDark
                                      : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            [
                              if (doc != null && doc.isNotEmpty) 'Doc: $doc',
                              if (phone != null && phone.isNotEmpty)
                                'Tel: $phone',
                              if (wallet > 0) '$wallet monedas',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: isSelected ? AppColors.teal : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── POINTS SECTION ───────────────────────────────────────────────────────────

class AdminSalePointsSection extends StatelessWidget {
  final bool show;
  final int saldoActualCliente;
  final int maxPuntosAplicables;
  final double pointsToSolesRatio;
  final TextEditingController pointsController;
  final ValueChanged<int> onPointsChanged;

  const AdminSalePointsSection({
    super.key,
    required this.show,
    required this.saldoActualCliente,
    required this.maxPuntosAplicables,
    required this.pointsToSolesRatio,
    required this.pointsController,
    required this.onPointsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(color: const Color(0xFFFDE68A)),
          boxShadow: AppColors.cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.amberLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    size: 17,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Canjear monedas',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amberDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CoinInfoChip(
                  label: 'Disponible',
                  value: '$saldoActualCliente monedas',
                  valueColor: AppColors.amberDark,
                ),
                const SizedBox(width: 8),
                _CoinInfoChip(
                  label: 'Máx. aplicable',
                  value: '$maxPuntosAplicables monedas',
                  valueColor: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                'Equivale a S/ ${(maxPuntosAplicables * pointsToSolesRatio).toStringAsFixed(2)} de descuento máximo',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.toll_rounded,
                      size: 18,
                      color: AppColors.amber,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        suffixText: 'monedas',
                        suffixStyle: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged:
                          (val) => onPointsChanged(int.tryParse(val) ?? 0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _CoinInfoChip({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TOTAL SUMMARY ────────────────────────────────────────────────────────────

class AdminSaleTotalSummarySection extends StatelessWidget {
  final double subtotalAntesDePuntos;
  final int puntosAplicables;
  final double descuentoPuntos;
  final double descuentoExtra;
  final double totalFinal;
  final double pointsToSolesRatio;
  final double earningRate;
  final bool isCredito; // NUEVO

  const AdminSaleTotalSummarySection({
    super.key,
    required this.subtotalAntesDePuntos,
    required this.puntosAplicables,
    required this.descuentoPuntos,
    required this.descuentoExtra,
    required this.totalFinal,
    required this.pointsToSolesRatio,
    required this.earningRate,
    required this.isCredito,
  });

  @override
  Widget build(BuildContext context) {
    final puntosGanadosEstimados =
        (totalFinal * earningRate / pointsToSolesRatio).toInt();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        children: [
          if (puntosAplicables > 0 || descuentoExtra > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppColors.radius),
                ),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value: 'S/ ${subtotalAntesDePuntos.toStringAsFixed(2)}',
                  ),
                  if (puntosAplicables > 0) ...[
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Monedas usadas',
                      value: '$puntosAplicables monedas',
                      valueColor: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Descuento monedas',
                      value: '- S/ ${descuentoPuntos.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                      isBold: true,
                    ),
                  ],
                  if (descuentoExtra > 0) ...[
                    const SizedBox(height: 6),
                    _SummaryRow(
                      label: 'Descuento aplicado',
                      value: '- S/ ${descuentoExtra.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                      isBold: true,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: 'Tasa de acumulación',
                    value: '${(earningRate * 100).toStringAsFixed(1)}%',
                    valueColor: AppColors.textMuted,
                  ),
                ],
              ),
            ),

          // Total final
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isCredito
                        ? [
                          Colors.deepOrange.shade600,
                          Colors.deepOrange.shade800,
                        ]
                        : const [Color(0xFF0D9488), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  puntosAplicables > 0
                      ? const BorderRadius.vertical(
                        bottom: Radius.circular(AppColors.radius),
                      )
                      : BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCredito ? 'TOTAL A CRÉDITO' : 'TOTAL A PAGAR',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCredito
                          ? 'Se cargará a la deuda del cliente'
                          : 'Incluye todos los descuentos',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    // Puntos a ganar (no aplica en crédito)
                    if (!isCredito && puntosGanadosEstimados > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+$puntosGanadosEstimados monedas al cliente',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'S/ ${totalFinal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── CONFIRM BUTTON ───────────────────────────────────────────────────────────

class AdminSaleConfirmButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final String label; // NUEVO: texto configurable
  final VoidCallback? onPressed;

  const AdminSaleConfirmButton({
    super.key,
    required this.loading,
    required this.enabled,
    required this.onPressed,
    this.label = 'Confirmar venta',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (enabled && !loading) ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient:
              (enabled && !loading)
                  ? const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: (!enabled || loading) ? AppColors.border : null,
          borderRadius: BorderRadius.circular(AppColors.radius),
          boxShadow:
              (enabled && !loading)
                  ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              Icon(
                Icons.check_circle_rounded,
                color: enabled ? Colors.white : AppColors.textMuted,
                size: 20,
              ),
            const SizedBox(width: 10),
            Text(
              loading ? 'Procesando…' : label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.white : AppColors.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────────

class AdminSaleStockSection extends StatelessWidget {
  final int currentStock;
  const AdminSaleStockSection({super.key, required this.currentStock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            currentStock > 0 ? AppColors.successLight : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            currentStock > 0
                ? Icons.inventory_2_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: currentStock > 0 ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            'Stock disponible: $currentStock unidades',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: currentStock > 0 ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSaleVariantSection extends StatelessWidget {
  final List<ProductVariantModel> variants;
  final ProductVariantModel? selectedVariant;
  final ProductModel product;
  final ValueChanged<ProductVariantModel?> onChanged;

  const AdminSaleVariantSection({
    super.key,
    required this.variants,
    required this.selectedVariant,
    required this.product,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Variante',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ProductVariantModel>(
              value: selectedVariant,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
              items:
                  variants.map((variant) {
                    final normalPrice = variant.salePrice ?? product.salePrice;
                    final wholesalePrice =
                        variant.wholesalePrice ?? product.wholesalePrice;
                    final minQty =
                        variant.wholesaleMinQuantity ??
                        product.wholesaleMinQuantity;
                    return DropdownMenuItem(
                      value: variant,
                      child: Text(
                        '${variant.label}: S/ $normalPrice${wholesalePrice != null ? ' · May: S/ $wholesalePrice ($minQty)' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class AdminSaleQuantitySection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool isQuantityOverStock;
  final int currentStock;

  const AdminSaleQuantitySection({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.isQuantityOverStock,
    required this.currentStock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(
              color: isQuantityOverStock ? AppColors.danger : AppColors.border,
              width: isQuantityOverStock ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.tag_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cantidad a vender',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isQuantityOverStock)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  size: 13,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 5),
                Text(
                  'Supera el stock disponible ($currentStock).',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AdminSaleWholesaleHint extends StatelessWidget {
  final TextEditingController quantityController;
  final ProductVariantModel? selectedVariant;
  final ProductModel product;
  final bool useWholesalePrice;
  final bool canUseWholesalePrice;

  const AdminSaleWholesaleHint({
    super.key,
    required this.quantityController,
    required this.selectedVariant,
    required this.product,
    required this.useWholesalePrice,
    required this.canUseWholesalePrice,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final quantity = int.tryParse(quantityController.text) ?? 0;
        final wholesalePrice =
            selectedVariant?.wholesalePrice ?? product.wholesalePrice;
        final minQty =
            selectedVariant?.wholesaleMinQuantity ??
            product.wholesaleMinQuantity;
        final hasWholesalePrice = wholesalePrice != null;

        final isPositive = useWholesalePrice && (quantity >= (minQty));
        final label =
            !hasWholesalePrice
                ? 'No hay precio por mayor configurado en esta variante ni en el producto'
                : !canUseWholesalePrice
                ? 'Necesitas $minQty unidades para aplicar precio por mayor'
                : useWholesalePrice
                ? (quantity >= (minQty)
                    ? 'Precio por mayor habilitado (Mín: $minQty)'
                    : 'Necesitas $minQty unidades para precio por mayor')
                : 'Precio base activo. Activa el switch para precio por mayor';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isPositive ? AppColors.successLight : AppColors.blueLight,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                isPositive
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: isPositive ? AppColors.success : AppColors.blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.success : AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminSaleStoreSection extends StatelessWidget {
  final List<WarehouseModel> warehouses;
  final String? selectedWarehouseId;
  final ValueChanged<String?> onChanged;

  const AdminSaleStoreSection({
    super.key,
    required this.warehouses,
    required this.selectedWarehouseId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedWarehouseId,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          items:
              warehouses.map((w) {
                return DropdownMenuItem<String>(
                  value: w.id,
                  child: Text(
                    w.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
