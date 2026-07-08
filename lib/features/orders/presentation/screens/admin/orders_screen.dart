import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/core/providers/app_config_provider.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/orders/order_detail_sheet.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/orders/admin_order_card.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

class OrdersScreen extends StatefulWidget {
  final String? customTitle;

  const OrdersScreen({super.key, this.customTitle});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  OrderModel? _selectedOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders(reset: true);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<OrdersProvider>().setSearchQuery(value);
      }
    });
  }

  // ─── GENERACIÓN DE TICKET PDF ─────────────────────────────────────────────

  Future<void> _printOrderTicket(OrderModel order) async {
    try {
      await context.read<OrdersProvider>().generatePdfTicket(order);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al generar ticket: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  // ─── ACTUALIZAR ESTADO DE PEDIDO ─────────────────────────────────────────

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    if (context.read<OrdersProvider>().isOrderProcessing(order.id)) return;

    // Aviso si el método de pago es "POR ACORDAR" al completar
    if (newStatus == 'COMPLETED' &&
        (order.paymentMethod == 'POR ACORDAR' ||
            order.paymentMethod.trim().isEmpty)) {
      final selectedMethod = await _showPaymentMethodBottomSheet(order);
      if (selectedMethod == null) return; // Cancelado por el usuario

      // Actualizamos la orden temporalmente para mandarla a guardar con el nuevo método
      order = order.copyWith(paymentMethod: selectedMethod);
    }

    // Diálogo de confirmación enriquecido
    final confirm = await _showConfirmDialog(order, newStatus);
    if (confirm != true) return;

    if (!mounted) return;

    try {
      await context.read<OrdersProvider>().updateOrderStatus(order, newStatus);

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              newStatus == 'COMPLETED'
                  ? 'Pedido completado correctamente'
                  : 'Estado actualizado correctamente',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(OrderModel order, String newStatus) {
    final isCompleting = newStatus == 'COMPLETED';
    final isCancelling = newStatus == 'CANCELLED';
    final isReturning = newStatus == 'RETURNED';
    final isCredit = order.paymentMethod == 'CRÉDITO';
    final pendingPoints = order.pointsEarned;
    final config = context.read<AppConfigProvider>();
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isCompleting
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCompleting
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    color:
                        isCompleting
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCompleting
                        ? 'Confirmar cobro'
                        : (isReturning ? 'Devolver pedido' : 'Cancelar pedido'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente: ${order.displayCustomerName}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      isCompleting ? 'Monto a cobrar: ' : 'Total del pedido: ',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'S/ ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color:
                            isCompleting
                                ? AppColors.primary
                                : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                if (isLoyaltyEnabled &&
                    isCompleting &&
                    !isCredit &&
                    pendingPoints > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          'El cliente ganará $pendingPoints monedas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCompleting && isCredit) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Se registrará como deuda de crédito.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCancelling || isReturning) ...[
                  const SizedBox(height: 10),
                  Text(
                    isReturning
                        ? 'Se reintegrará el stock y se reembolsará el pago. Esta acción no se puede deshacer.'
                        : 'Esta acción no se puede deshacer. El stock NO se reintegrará automáticamente si ya fue descontado.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCompleting
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  isCompleting
                      ? 'Confirmar cobro'
                      : (isReturning ? 'Sí, devolver' : 'Sí, cancelar'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showOrderDetails(OrderModel order, bool isWide) async {
    if (isWide) {
      setState(() {
        _selectedOrder = order;
      });
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: OrderDetailSheet(order: order),
          ),
    );
    if (result == true) {
      if (mounted) context.read<OrdersProvider>().loadOrders(background: true);
    }
  }

  void _onOrderEmbeddedPop(bool wasModified) {
    if (wasModified && mounted) {
      context.read<OrdersProvider>().loadOrders(background: true);
    }
    setState(() {
      _selectedOrder = null;
    });
  }

  Future<String?> _showPaymentMethodBottomSheet(OrderModel order) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Selecciona cómo pagó el cliente:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Monto a cobrar: S/ ${order.totalAmount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        _PaymentOptionButton(
          label: 'EFECTIVO',
          icon: Icons.payments_outlined,
          onSelect: () => Navigator.pop(context, 'EFECTIVO'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'YAPE',
          icon: Icons.phone_android_rounded,
          onSelect: () => Navigator.pop(context, 'YAPE'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'PLIN',
          icon: Icons.phone_android_rounded,
          onSelect: () => Navigator.pop(context, 'PLIN'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'TARJETA',
          icon: Icons.credit_card_rounded,
          onSelect: () => Navigator.pop(context, 'TARJETA'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'CRÉDITO',
          icon: Icons.schedule_rounded,
          onSelect: () => Navigator.pop(context, 'CRÉDITO'),
        ),
        const SizedBox(height: 24),
      ],
    );

    if (isWide) {
      return showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: SizedBox(width: 400, child: content),
            ),
      );
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: content,
          ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

    return AdminLayout(
      title: widget.customTitle ?? 'Gestión de Pedidos',
      showBackButton: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          return Consumer<OrdersProvider>(
            builder: (context, provider, _) {
              final content = CustomScrollView(
                slivers: [
                  if (provider.isBackgroundLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        color: AppColors.teal,
                        minHeight: 2,
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    floating: true,
                    delegate: _OrdersFiltersHeaderDelegate(
                      searchCtrl: _searchCtrl,
                      onSearchChanged: _onSearchChanged,
                      provider: provider,
                      buildFilterChip: _buildFilterChip,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildListSliver(
                      provider,
                      isWide,
                      isLoyaltyEnabled,
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 45,
                      child: Container(
                        color: Colors.grey.shade50,
                        child: content,
                      ),
                    ),
                    Container(width: 1, color: Colors.grey.shade200),
                    Expanded(
                      flex: 55,
                      child:
                          _selectedOrder == null
                              ? const AppEmptyState(
                                icon: Icons.receipt_long_rounded,
                                title: 'Ningún pedido seleccionado',
                                message:
                                    'Selecciona un pedido de la lista para ver o editar sus detalles.',
                              )
                              : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: OrderDetailSheet(
                                  key: ValueKey(_selectedOrder!.id),
                                  order: _selectedOrder!,
                                  isEmbedded: true,
                                  onPop: _onOrderEmbeddedPop,
                                ),
                              ),
                    ),
                  ],
                );
              }

              return content;
            },
          );
        },
      ),
    );
  }

  Widget _buildListSliver(
    OrdersProvider provider,
    bool isWide,
    bool isLoyaltyEnabled,
  ) {
    final totalPages = provider.totalPages;
    final pageItems = provider.orders;

    if (provider.isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppShimmer(height: 140),
          ),
          childCount: 5,
        ),
      );
    }

    if (provider.errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          color: Colors.red,
          title: 'Ocurrió un error',
          message: provider.errorMessage,
        ),
      );
    }

    if (pageItems.isEmpty) {
      return const SliverFillRemaining(
        child: AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No se encontraron pedidos.',
          message: 'Intenta cambiar los filtros o la búsqueda.',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // Contador
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Row(
            children: [
              Text(
                'Mostrando resultados',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Pág. ${provider.currentPage + 1} / $totalPages',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Lista
        ...pageItems.map((order) {
          final isSelected = isWide && _selectedOrder?.id == order.id;
          return AdminOrderCard(
            order: order,
            isProcessing: provider.isOrderProcessing(order.id),
            isGeneratingPDF: provider.isGeneratingPDF(order.id),
            isSelected: isSelected,
            isLoyaltyEnabled: isLoyaltyEnabled,
            onTap: () => _showOrderDetails(order, isWide),
            onUpdateStatus: (o, s) => _updateOrderStatus(o, s),
            onPrint: () => _printOrderTicket(order),
          );
        }),

        // Paginación
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: AdminPageBlocks(
              currentPage: provider.currentPage,
              totalPages: totalPages,
              onPageChanged: provider.goToPage,
            ),
          ),
      ]),
    );
  }
}

// ─── DELGATE PARA EL HEADER STICKY DE BÚSQUEDA Y FILTROS ─────────────────────

class _OrdersFiltersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchCtrl;
  final Function(String) onSearchChanged;
  final OrdersProvider provider;
  final Widget Function({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  })
  buildFilterChip;

  _OrdersFiltersHeaderDelegate({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.provider,
    required this.buildFilterChip,
  });

  @override
  double get minExtent => 140.0;
  @override
  double get maxExtent => 140.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o ID de pedido...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                ),
                suffixIcon:
                    searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            searchCtrl.clear();
                            provider.setSearchQuery('');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
            ),
          ),
          // Filtros
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                buildFilterChip(
                  label: 'Todos',
                  isSelected: provider.statusFilter == 'ALL',
                  onSelected: (_) => provider.setStatusFilter('ALL'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Borradores',
                  isSelected: provider.statusFilter == 'PENDING',
                  onSelected: (_) => provider.setStatusFilter('PENDING'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Completados',
                  isSelected: provider.statusFilter == 'COMPLETED',
                  onSelected: (_) => provider.setStatusFilter('COMPLETED'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Cancelados',
                  isSelected: provider.statusFilter == 'CANCELLED',
                  onSelected: (_) => provider.setStatusFilter('CANCELLED'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Devueltos',
                  isSelected: provider.statusFilter == 'RETURNED',
                  onSelected: (_) => provider.setStatusFilter('RETURNED'),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: PopupMenuButton<String>(
                    initialValue: provider.paymentStatusFilter,
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (val) {
                      provider.setPaymentStatusFilter(val);
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: 'ALL',
                            child: Text('Cobros: Todos'),
                          ),
                          PopupMenuItem(value: 'PAID', child: Text('Pagados')),
                          PopupMenuItem(
                            value: 'PENDING',
                            child: Text('Por cobrar'),
                          ),
                          PopupMenuItem(
                            value: 'PARTIAL',
                            child: Text('Parciales'),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getPaymentStatusLabel(
                              provider.paymentStatusFilter,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DateFilterCalendar(
                  dateRange: provider.dateRange,
                  onDateRangeSelected: (picked) {
                    provider.setDateRange(picked);
                  },
                  onClear: () {
                    provider.setDateRange(null);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'PAID':
        return 'Pagados';
      case 'PENDING':
        return 'Por cobrar';
      case 'PARTIAL':
        return 'Parciales';
      default:
        return 'Cobros: Todos';
    }
  }

  @override
  bool shouldRebuild(covariant _OrdersFiltersHeaderDelegate oldDelegate) {
    return oldDelegate.provider != provider ||
        oldDelegate.searchCtrl.text != searchCtrl.text;
  }
}

// ─── Helpers: Modal de Opciones de Pago ────────────────────────────────────

class _PaymentOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onSelect;

  const _PaymentOptionButton({
    required this.label,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
