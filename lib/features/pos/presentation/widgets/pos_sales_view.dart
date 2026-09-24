import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_detail_sheet.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:intl/intl.dart';

/// Vista de Ventas POS embebida en el layout principal de Caja.
///
/// Optimizaciones de Alto Rendimiento (Stripe / Linear Architecture):
/// - **Paginación Infinita con Scroll Controller:** Carga incremental de 20 en 20 sin saturar la RAM.
/// - **Búsqueda Remota en Servidor con Debounce (350ms):** Búsqueda real en PostgreSQL/Supabase con `.ilike`.
/// - **Métricas Reales Agregadas:** Resumen consolidado del día vía Supabase sin depender de filtros locales.
/// - **Aislamiento de Renderizado (RepaintBoundary + buildWhen):** Cero rebuilds superfluos desde PosCubit.
/// - **Badges Reactivos de Estado:** Reflejan verazmente si la orden fue completada, anulada o devuelta.
class PosSalesView extends StatefulWidget {
  final VoidCallback? onOpenCashShifts;

  const PosSalesView({
    super.key,
    this.onOpenCashShifts,
  });

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

class _PosSalesViewState extends State<PosSalesView> {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');

  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  String? _reprintingOrderId;
  OrderEntity? _selectedOrder;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final posCubit = context.read<PosCubit>();
    if (posCubit.state.recentOrders.isEmpty) {
      posCubit.fetchRecentOrders();
    } else {
      posCubit.fetchDailySalesSummary();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll * 0.85) {
      context.read<PosCubit>().loadMoreRecentOrders();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<PosCubit>().fetchRecentOrders(query: val.trim(), forceRefresh: true);
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounceTimer?.cancel();
    context.read<PosCubit>().fetchRecentOrders(query: '', forceRefresh: true);
  }

  void _navigateOrder(int step, List<OrderEntity> orders) {
    if (orders.isEmpty) return;
    if (_selectedOrder == null) {
      setState(() => _selectedOrder = orders.first);
      return;
    }
    final currentIndex = orders.indexWhere((o) => o.id == _selectedOrder!.id);
    if (currentIndex == -1) {
      setState(() => _selectedOrder = orders.first);
      return;
    }
    final nextIndex = (currentIndex + step).clamp(0, orders.length - 1);
    setState(() => _selectedOrder = orders[nextIndex]);
  }

  Future<void> _reimprimirTicket(String orderId) async {
    if (_reprintingOrderId != null) return;
    setState(() => _reprintingOrderId = orderId);

    try {
      final posCubit = context.read<PosCubit>();
      final config = context.read<AppConfigCubit>();

      final detailsRes = await posCubit.fetchOrderDetailsForTicket(orderId);

      await detailsRes.fold(
        (failure) async {
          if (mounted) {
            AppSnackbar.show(
              context,
              message: 'Error al cargar comprobante: ${failure.message}',
              type: SnackbarType.error,
            );
          }
        },
        (result) async {
          await OrderPdfGenerator.printTicket(
            result.order,
            items: result.items,
            businessName: config.businessName,
            taxId: config.businessTaxId,
            address: config.businessAddress,
            phone: config.businessPhone,
          );
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al generar ticket',
        tag: 'PosSalesView',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al generar ticket térmico.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _reprintingOrderId = null);
    }
  }

  void _openOrderDetail(OrderEntity order, bool isDesktop, bool isTablet) {
    if (isDesktop) {
      setState(() => _selectedOrder = order);
      return;
    }

    if (isTablet) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
              color: AppColors.background,
              child: OrderDetailSheet(
                order: order,
                isEmbedded: true,
                onPop: (_) => Navigator.of(ctx).pop(),
                onOrderUpdated: (updated) {
                  context.read<PosCubit>().fetchRecentOrders(forceRefresh: true);
                },
              ),
            ),
          ),
        ),
      );
      return;
    }

    // Móvil: Apple HIG Draggable Modal BottomSheet con esquinas de 24px
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.90,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: OrderDetailSheet(
                order: order,
                onPop: (_) => Navigator.of(ctx).pop(),
                onOrderUpdated: (updated) {
                  context.read<PosCubit>().fetchRecentOrders(forceRefresh: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      buildWhen: (prev, current) =>
          prev.recentOrders != current.recentOrders ||
          prev.isLoadingRecentOrders != current.isLoadingRecentOrders ||
          prev.isLoadingMoreOrders != current.isLoadingMoreOrders ||
          prev.hasMoreOrders != current.hasMoreOrders ||
          prev.recentOrdersError != current.recentOrdersError ||
          prev.dailyTotalAmount != current.dailyTotalAmount ||
          prev.dailyTotalCount != current.dailyTotalCount ||
          prev.salesSearchQuery != current.salesSearchQuery,
      builder: (context, state) {
        final orders = state.recentOrders;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet = constraints.maxWidth >= 700 && constraints.maxWidth < 1024;
            final isMobile = constraints.maxWidth < 700;

            final fullWidthListView = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, isMobile),
                _buildMetricsAndSearch(
                  context,
                  state.dailyTotalAmount,
                  state.dailyTotalCount,
                  isMobile,
                ),
                Expanded(
                  child: state.isLoadingRecentOrders
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : state.recentOrdersError.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Error al cargar las ventas:\n${state.recentOrdersError}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () => context.read<PosCubit>().fetchRecentOrders(forceRefresh: true),
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: const Text('Reintentar'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF142B1A),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : orders.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 52,
                                        color: AppColors.textMuted.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        state.salesSearchQuery.isNotEmpty
                                            ? 'No se encontraron ventas para "${state.salesSearchQuery}".'
                                            : 'No se encontraron ventas registradas.',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    isMobile ? 16 : 20,
                                    6,
                                    isMobile ? 16 : 20,
                                    24,
                                  ),
                                  itemCount: orders.length + (state.isLoadingMoreOrders ? 1 : 0),
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    if (index >= orders.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final order = orders[index];
                                    // RepaintBoundary aísla cada card: al seleccionar
                                    // o reimprimir una orden, solo esa card se repinta.
                                    return RepaintBoundary(
                                      child: _buildOrderCard(
                                        context,
                                        order,
                                        isDesktop,
                                        isTablet,
                                        isMobile,
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            );

            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                if (isDesktop && !_searchFocusNode.hasFocus) ...{
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                    _navigateOrder(1, orders);
                  },
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                    _navigateOrder(-1, orders);
                  },
                },
                const SingleActivator(LogicalKeyboardKey.keyP, alt: true): () {
                  if (_selectedOrder != null) {
                    _reimprimirTicket(_selectedOrder!.id);
                  }
                },
                // Alt+K enfoca el buscador de ventas
                const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
                  _searchFocusNode.requestFocus();
                },
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (_selectedOrder != null) {
                    setState(() => _selectedOrder = null);
                  }
                },
              },
              child: Container(
                color: AppColors.background,
                child: Stack(
                  children: [
                    // 1. Lista a pantalla completa aislada de repintados
                    RepaintBoundary(
                      child: fullWidthListView,
                    ),

                    // 2. Slide-Over Side Sheet Inspector en Desktop con RepaintBoundary
                    if (isDesktop && _selectedOrder != null) ...[
                      // Backdrop con dismiss
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedOrder = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            color: Colors.black.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                      // Panel lateral deslizante tipo Stripe / Linear
                      Align(
                        alignment: Alignment.centerRight,
                        child: RepaintBoundary(
                          child: Container(
                            width: constraints.maxWidth >= 1400 ? 640 : 560,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                  offset: const Offset(-8, 0),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Cabecera del Slide-Over
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppColors.border.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.receipt_long_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Detalle del Comprobante',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: const Text(
                                          'ESC',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 20),
                                        tooltip: 'Cerrar detalle (Esc)',
                                        onPressed: () => setState(() => _selectedOrder = null),
                                        style: IconButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Detalle embebido completo
                                Expanded(
                                  child: OrderDetailSheet(
                                    key: ValueKey(_selectedOrder!.id),
                                    order: _selectedOrder!,
                                    isEmbedded: true,
                                    onPop: (_) {
                                      setState(() => _selectedOrder = null);
                                    },
                                    onOrderUpdated: (updated) {
                                      setState(() => _selectedOrder = updated);
                                      context.read<PosCubit>().fetchRecentOrders(forceRefresh: true);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 10 : 14,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF142B1A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Color(0xFF142B1A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMobile ? 'Ventas POS' : 'Historial de Ventas POS',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                if (!isMobile)
                  const Text(
                    'Consulta comprobantes emitidos, audita productos y reimprime tickets',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Botón Turnos de Caja
          if (isMobile)
            IconButton(
              tooltip: 'Turnos de Caja',
              icon: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 20),
              onPressed: () async {
                if (widget.onOpenCashShifts != null) {
                  widget.onOpenCashShifts!();
                  return;
                }
                await context.push('/all-cash-shifts');
                if (context.mounted) {
                  context.read<PosCubit>().refreshAccountsAndShift();
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                if (widget.onOpenCashShifts != null) {
                  widget.onOpenCashShifts!();
                  return;
                }
                await context.push('/all-cash-shifts');
                if (context.mounted) {
                  context.read<PosCubit>().refreshAccountsAndShift();
                }
              },
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: const Text('Turnos de Caja'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          const SizedBox(width: 8),

          // Botón Refrescar
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Actualizar ventas y totales',
            onPressed: () => context.read<PosCubit>().fetchRecentOrders(forceRefresh: true),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsAndSearch(
    BuildContext context,
    double totalVentasHoy,
    int totalTickets,
    bool isMobile,
  ) {
    final metricTotal = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL VENTAS (HOY)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'S/ ${totalVentasHoy.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final metricTickets = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TICKETS EMITIDOS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$totalTickets ventas',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final searchField = Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onSubmitted: (val) {
          _debounceTimer?.cancel();
          context.read<PosCubit>().fetchRecentOrders(query: val.trim(), forceRefresh: true);
        },
        decoration: InputDecoration(
          hintText: 'Buscar por cliente o código de comprobante... (Alt+K)',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: _clearSearch,
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: metricTotal),
                const SizedBox(width: 10),
                Expanded(child: metricTickets),
              ],
            ),
            const SizedBox(height: 10),
            searchField,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          metricTotal,
          const SizedBox(width: 12),
          metricTickets,
          const SizedBox(width: 16),
          Expanded(child: searchField),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toUpperCase();
    Color bgColor;
    Color textColor;
    String label;

    switch (s) {
      case 'COMPLETED':
      case 'DELIVERED':
        bgColor = AppColors.successLight;
        textColor = AppColors.successDark;
        label = 'Completado';
        break;
      case 'CANCELLED':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC62828);
        label = 'Anulado';
        break;
      case 'REFUNDED':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        label = 'Devuelto';
        break;
      case 'PENDING':
      default:
        bgColor = const Color(0xFFE3F2FD);
        textColor = const Color(0xFF1565C0);
        label = 'Pendiente';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderEntity order,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final isSelected = isDesktop && _selectedOrder?.id == order.id;
    final isReprinting = _reprintingOrderId == order.id;
    final clientName = order.customerName.isNotEmpty ? order.customerName : 'Cliente General';
    final dateStr = order.createdAt != null ? _dateFormat.format(order.createdAt!) : 'Reciente';
    final idShort = order.id.length > 12 ? order.id.substring(0, 12) : order.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openOrderDetail(order, isDesktop, isTablet),
        borderRadius: BorderRadius.circular(14),
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF142B1A).withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF142B1A) : AppColors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF142B1A).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: isSelected ? 10 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: isMobile
              ? _buildMobileCardContent(order, clientName, idShort, dateStr, isReprinting)
              : _buildDesktopCardContent(order, clientName, idShort, dateStr, isReprinting, isSelected, isDesktop, isTablet),
        ),
      ),
    );
  }

  Widget _buildMobileCardContent(
    OrderEntity order,
    String clientName,
    String idShort,
    String dateStr,
    bool isReprinting,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Icono + Nombre del Cliente + Estado Real
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  clientName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 8),

          // Fila 2: ID y Fecha (en una sola línea limpia)
          Row(
            children: [
              Text(
                'ID: $idShort',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
              const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
          const SizedBox(height: 10),

          // Fila 3: Total a la izquierda + Botón Reimprimir y Chevron a la derecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL COBRADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'S/ ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: isReprinting ? null : () => _reimprimirTicket(order.id),
                    icon: isReprinting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_rounded, size: 14),
                    label: const Text('Reimprimir', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCardContent(
    OrderEntity order,
    String clientName,
    String idShort,
    String dateStr,
    bool isReprinting,
    bool isSelected,
    bool isDesktop,
    bool isTablet,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          // Icono
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF142B1A).withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_rounded,
              color: isSelected ? const Color(0xFF142B1A) : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Datos Cliente + Estado + Fecha
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clientName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? const Color(0xFF142B1A) : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'ID: $idShort',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                    const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Monto
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/ ${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'Total cobrado',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Botón Ver Detalle
          OutlinedButton.icon(
            onPressed: () => _openOrderDetail(order, isDesktop, isTablet),
            icon: const Icon(Icons.visibility_outlined, size: 15),
            label: const Text('Ver Detalle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botón Reimprimir
          FilledButton.tonalIcon(
            onPressed: isReprinting ? null : () => _reimprimirTicket(order.id),
            icon: isReprinting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded, size: 15),
            label: const Text('Reimprimir'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
