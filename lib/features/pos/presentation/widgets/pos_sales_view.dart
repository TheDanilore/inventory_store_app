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
/// Implementa una arquitectura "camaleónica" multi-dispositivo:
/// - **Desktop (≥ 1024px):** Split View Master-Detail con inspector lateral y navegación por teclado.
/// - **Tablet (700px - 1023px):** Diálogo modal centrado con backdrop difuso.
/// - **Móvil (< 700px):** Tarjetas jerárquicas optimizadas y Apple HIG Draggable Modal BottomSheet.
class PosSalesView extends StatefulWidget {
  const PosSalesView({super.key});

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

class _PosSalesViewState extends State<PosSalesView> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _filter = '';
  String? _reprintingOrderId;
  OrderEntity? _selectedOrder;

  @override
  void initState() {
    super.initState();
    final posCubit = context.read<PosCubit>();
    if (posCubit.state.recentOrders.isEmpty) {
      posCubit.fetchRecentOrders();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
        height: MediaQuery.of(context).size.height * 0.90,
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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final allOrders = state.recentOrders;
        final filteredOrders = allOrders.where((order) {
          if (_filter.isEmpty) return true;
          final query = _filter.toLowerCase();
          final clientMatches = order.customerName.toLowerCase().contains(query);
          final idMatches = order.id.toLowerCase().contains(query);
          return clientMatches || idMatches;
        }).toList();

        final totalVentasHoy = filteredOrders.fold<double>(
          0.0,
          (sum, order) => sum + order.totalAmount,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet = constraints.maxWidth >= 700 && constraints.maxWidth < 1024;
            final isMobile = constraints.maxWidth < 700;

            final listPane = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, isMobile),
                _buildMetricsAndSearch(
                  context,
                  totalVentasHoy,
                  filteredOrders.length,
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
                                    'Error al cargar las ventas:\\n',
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
                          : filteredOrders.isEmpty
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
                                      const Text(
                                        'No se encontraron ventas registradas.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.fromLTRB(
                                    isMobile ? 16 : 20,
                                    4,
                                    isMobile ? 16 : 20,
                                    24,
                                  ),
                                  itemCount: filteredOrders.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    return _buildOrderCard(
                                      context,
                                      order,
                                      dateFormat,
                                      isDesktop,
                                      isTablet,
                                      isMobile,
                                    );
                                  },
                                ),
                ),
              ],
            );

            Widget mainContent;

            if (isDesktop) {
              final masterWidth = constraints.maxWidth >= 1400 ? 450.0 : 410.0;

              mainContent = Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: masterWidth, child: listPane),
                  Container(
                    width: 1,
                    color: AppColors.border.withValues(alpha: 0.8),
                  ),
                  Expanded(
                    child: _selectedOrder == null
                        ? _buildEmptyDetailPlaceholder()
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
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
                  ),
                ],
              );
            } else {
              mainContent = listPane;
            }

            return CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                if (isDesktop && !_searchFocusNode.hasFocus) ...{
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                    _navigateOrder(1, filteredOrders);
                  },
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                    _navigateOrder(-1, filteredOrders);
                  },
                },
                const SingleActivator(LogicalKeyboardKey.keyP, alt: true): () {
                  if (_selectedOrder != null) {
                    _reimprimirTicket(_selectedOrder!.id);
                  }
                },
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (_selectedOrder != null) {
                    setState(() => _selectedOrder = null);
                  }
                },
              },
              child: Container(
                color: AppColors.background,
                child: mainContent,
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
              onPressed: () => context.push('/all-cash-shifts'),
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
              onPressed: () => context.push('/all-cash-shifts'),
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
            tooltip: 'Actualizar ventas',
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        children: [
          const Icon(Icons.payments_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL VENTAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'S/ ',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final metricTickets = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
        onChanged: (val) => setState(() => _filter = val),
        decoration: InputDecoration(
          hintText: 'Filtrar por cliente o comprobante...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          suffixIcon: _filter.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _filter = '');
                  },
                )
              : null,
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
          SizedBox(width: 180, child: metricTotal),
          const SizedBox(width: 12),
          SizedBox(width: 180, child: metricTickets),
          const SizedBox(width: 16),
          Expanded(child: searchField),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderEntity order,
    DateFormat dateFormat,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final isSelected = isDesktop && _selectedOrder?.id == order.id;
    final isReprinting = _reprintingOrderId == order.id;
    final clientName = order.customerName.isNotEmpty ? order.customerName : 'Cliente General';
    final dateStr = order.createdAt != null ? dateFormat.format(order.createdAt!) : 'Reciente';
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
              : _buildDesktopCardContent(order, clientName, idShort, dateStr, isReprinting, isSelected, isDesktop),
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
          // Fila 1: Icono + Nombre del Cliente + Estado
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Completado',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successDark,
                  ),
                ),
              ),
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
                    'S/ ',
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
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Icono
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF142B1A).withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_rounded,
              color: isSelected ? const Color(0xFF142B1A) : AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),

          // Datos Cliente + Estado + Fecha
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? const Color(0xFF142B1A) : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Completado',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.successDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: $idShort • $dateStr',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Monto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const Text(
                'Total cobrado',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Botón Reimprimir
          IconButton(
            tooltip: 'Reimprimir ticket térmico',
            icon: isReprinting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded, size: 16),
            onPressed: isReprinting ? null : () => _reimprimirTicket(order.id),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isSelected ? const Color(0xFF142B1A) : AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyDetailPlaceholder() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF142B1A).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: Color(0xFF142B1A),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Detalle de la Venta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: const Text(
                  'Selecciona un comprobante de la lista para auditar los productos vendidos, lotes, medios de pago y emitir comprobantes térmicos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_outlined, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Text(
                      'Usa ↑ / ↓ para navegar y Enter para seleccionar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
