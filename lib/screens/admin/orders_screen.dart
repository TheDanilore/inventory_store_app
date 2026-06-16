import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/orders/order_detail_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/orders/admin_order_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/orders/orders_filter_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/orders_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

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
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Método de pago pendiente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Este pedido tiene el método de pago como \'POR ACORDAR\'. '
                'Abre el detalle del pedido y selecciona la cuenta o método '
                'de cobro antes de completarlo.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
      return;
    }

    // Diálogo de confirmación enriquecido
    final confirm = await _showConfirmDialog(order, newStatus);
    if (confirm != true) return;

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
    final isCredit = order.paymentMethod == 'CRÉDITO';
    final pendingPoints = order.pointsEarned;

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
                    isCompleting ? 'Confirmar cobro' : 'Cancelar pedido',
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
                if (isCompleting && !isCredit && pendingPoints > 0) ...[
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
                if (isCancelling) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Esta acción no se puede deshacer. El stock NO se reintegrará automáticamente si ya fue descontado.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  isCompleting ? 'Confirmar cobro' : 'Sí, cancelar',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showOrderDetails(OrderModel order) async {
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

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Gestión de Pedidos',
      showBackButton: true,
      body: Consumer<OrdersProvider>(
        builder: (context, provider, _) {
          final totalPages = provider.totalPages;
          final pageItems = provider.orders;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Barra de progreso (recargas en background) ──────────────────
              if (provider.isBackgroundLoading)
                const LinearProgressIndicator(
                  color: AppColors.teal,
                  minHeight: 2,
                ),

              // ── Buscador ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente o ID de pedido...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                    ),
                    suffixIcon:
                        _searchCtrl.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.cancel_rounded,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
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

              // ── Filtros ─────────────────────────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    OrdersFilterDropdown(
                      value: provider.statusFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('Todos los estados'),
                        ),
                        DropdownMenuItem(
                          value: 'COMPLETED',
                          child: Text('Completados'),
                        ),
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('Borradores'),
                        ),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('Cancelados'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          provider.setStatusFilter(val);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    OrdersFilterDropdown(
                      value: provider.paymentStatusFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('Todos los cobros'),
                        ),
                        DropdownMenuItem(value: 'PAID', child: Text('Pagados')),
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('Por cobrar'),
                        ),
                        DropdownMenuItem(
                          value: 'PARTIAL',
                          child: Text('Parciales'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          provider.setPaymentStatusFilter(val);
                        }
                      },
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
              const SizedBox(height: 16),

              // ── Lista de pedidos ─────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => provider.loadOrders(reset: true),
                  child: Builder(
                    builder: (context) {
                      if (provider.isLoading) {
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, _) => const AppShimmer(height: 140),
                        );
                      }

                      if (provider.errorMessage.isNotEmpty) {
                        return _buildErrorState(provider.errorMessage);
                      }

                      if (pageItems.isEmpty) {
                        return _buildEmptyState();
                      }

                      return Column(
                        children: [
                          // Contador
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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

                          // Lista paginada
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: pageItems.length,
                              separatorBuilder:
                                  (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final order = pageItems[index];
                                return AdminOrderCard(
                                  order: order,
                                  isProcessing: provider.isOrderProcessing(
                                    order.id,
                                  ),
                                  isGeneratingPDF: provider.isGeneratingPDF,
                                  onTap: () => _showOrderDetails(order),
                                  onUpdateStatus:
                                      (o, s) => _updateOrderStatus(o, s),
                                  onPrint: () => _printOrderTicket(order),
                                );
                              },
                            ),
                          ),

                          // Controles de Paginación
                          if (totalPages > 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                              child: AdminPageBlocks(
                                currentPage: provider.currentPage,
                                totalPages: totalPages,
                                onPageChanged: provider.goToPage,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron pedidos.',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta cambiar los filtros o la búsqueda.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
