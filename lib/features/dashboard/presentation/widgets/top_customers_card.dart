import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:url_launcher/url_launcher.dart';

enum TopCustomersDisplayMode { desktop, tablet, mobile }

class TopCustomersCard extends StatelessWidget {
  final List<CustomerEntity> customers;
  final TopCustomersDisplayMode displayMode;
  final VoidCallback? onHide;

  const TopCustomersCard({
    super.key,
    required this.customers,
    required this.displayMode,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.darkSurface
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: isDark ? [] : AppColors.cardShadow(opacity: 0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          if (customers.isEmpty)
            _buildEmptyState(context)
          else
            _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.amber.withValues(alpha: 0.2),
                  AppColors.amber.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.amberDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Clientes que más compran',
                      style: TextStyle(
                        fontSize:
                            displayMode == TopCustomersDisplayMode.desktop
                                ? 16
                                : 15,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.amberDark.withValues(alpha: 0.25)
                                : AppColors.amberLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: AppColors.amberDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Mayores compradores por volumen de facturación histórica',
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.go('/customers'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Text(
              'Ver todos',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            label: const Icon(Icons.arrow_forward_rounded, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? const Color(0xFF1E293B)
                        : AppColors.slateLight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 32,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no hay clientes registrados con compras completadas.',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (displayMode) {
      case TopCustomersDisplayMode.desktop:
        return _DesktopTable(
          customers: customers,
          onCustomerTap:
              (customer) => _openCustomerActionSheet(context, customer),
        );
      case TopCustomersDisplayMode.tablet:
        return _buildTabletList(context);
      case TopCustomersDisplayMode.mobile:
        return _buildMobileList(context);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLET: LISTA EXPANDIDA EN 2 COLUMNAS / TARJETAS ENLAZADAS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTabletList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: customers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final customer = customers[index];
          final rank = index + 1;
          final averageTicket =
              customer.orderCount > 0
                  ? customer.totalRevenue / customer.orderCount
                  : 0.0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openCustomerActionSheet(context, customer),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                  color:
                      isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.surface,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            (customers.isNotEmpty && customers.first.totalRevenue > 0
                                    ? customer.totalRevenue /
                                        customers.first.totalRevenue
                                    : 1.0)
                                .clamp(0.04, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF2563EB))
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                  children: [
                    _buildRankBadge(rank, isDark: isDark),
                    const SizedBox(width: 14),
                    _buildAvatar(customer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? const Color(0xFFF8FAFC)
                                      : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${customer.orderCount} compras realizadas · Ticket medio S/ ${averageTicket.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color:
                                isDark
                                    ? const Color(0xFF34D399)
                                    : AppColors.tealDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Facturado',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MÓVIL: TARJETAS VERTICALES CON TOUCH TARGET DE 48DP Y ACCIÓN DIRECTA
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder:
          (_, _) => Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final rank = index + 1;

        final ratio =
            (customers.isNotEmpty && customers.first.totalRevenue > 0
                    ? customer.totalRevenue / customers.first.totalRevenue
                    : 1.0)
                .clamp(0.04, 1.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openCustomerActionSheet(context, customer),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF2563EB))
                            .withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      _buildRankBadge(rank, isDark: isDark),
                      const SizedBox(width: 12),
                      _buildAvatar(customer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.fullName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark
                                        ? const Color(0xFFF8FAFC)
                                        : AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? AppColors.primary.withValues(
                                              alpha: 0.2,
                                            )
                                            : AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${customer.orderCount} ord.',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (customer.phone != null &&
                                    customer.phone!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    customer.phone!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          isDark
                                              ? const Color(0xFF94A3B8)
                                              : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color:
                                  isDark
                                      ? const Color(0xFF34D399)
                                      : AppColors.tealDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Total facturado',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPONENTES ATÓMICOS: RANK MEDAL & AVATAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildRankBadge(int rank, {bool isDark = false}) {
    if (rank == 1) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '1',
          style: TextStyle(
            color: Color(0xFF78350F),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFCBD5E1), Color(0xFF64748B)],
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.25),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '2',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEDD5), Color(0xFFFB923C), Color(0xFF9A3412)],
          ),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.25),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '3',
          style: TextStyle(
            color: Color(0xFF431407),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    final bg = isDark ? const Color(0xFF1E293B) : AppColors.background;
    final fg = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '$rank',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildAvatar(CustomerEntity customer) {
    final initials =
        customer.fullName.isNotEmpty
            ? customer.fullName.substring(0, 1).toUpperCase()
            : 'C';

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.75),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MODAL CAMALEÓNICO: BOTTOMSHEET EN MÓVIL / DIALOG EN DESKTOP
  // ─────────────────────────────────────────────────────────────────────────────
  void _openCustomerActionSheet(BuildContext context, CustomerEntity customer) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = _CustomerDetailView(customer: customer);

    if (isDesktop) {
      showDialog(
        context: context,
        useRootNavigator: true,
        builder:
            (ctx) => Dialog(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: content,
              ),
            ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    // Drag handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    content,
                  ],
                ),
              ),
            ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLA DE ESCRITORIO CON EXCLUSIÓN MUTUA DE HOVER (0% RIESGO DE DOBLE SOMBREADO)
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopTable extends StatefulWidget {
  final List<CustomerEntity> customers;
  final ValueChanged<CustomerEntity> onCustomerTap;

  const _DesktopTable({required this.customers, required this.onCustomerTap});

  @override
  State<_DesktopTable> createState() => _DesktopTableState();
}

class _DesktopTableState extends State<_DesktopTable> {
  int? _hoveredRank;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onExit: (_) {
        if (_hoveredRank != null) {
          setState(() => _hoveredRank = null);
        }
      },
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color:
                isDark
                    ? AppColors.darkSurfaceElevated
                    : AppColors.background.withValues(alpha: 0.6),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'CLIENTE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PEDIDOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TICKET MEDIO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TOTAL FACTURADO',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 80),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          // Table Rows con exclusión mutua instantánea (sin desvanecimientos solapados)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.customers.length,
            separatorBuilder:
                (_, _) => Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
            itemBuilder: (context, index) {
              final customer = widget.customers[index];
              final rank = index + 1;
              final averageTicket =
                  customer.orderCount > 0
                      ? customer.totalRevenue / customer.orderCount
                      : 0.0;
              final isHovered = _hoveredRank == rank;
              final maxRevenue =
                  widget.customers.isNotEmpty &&
                          widget.customers.first.totalRevenue > 0
                      ? widget.customers.first.totalRevenue
                      : 1.0;
              final ratio =
                  (customer.totalRevenue / maxRevenue).clamp(0.04, 1.0);

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) {
                  if (_hoveredRank != rank) {
                    setState(() => _hoveredRank = rank);
                  }
                },
                child: GestureDetector(
                  onTap: () => widget.onCustomerTap(customer),
                  child: Stack(
                    children: [
                      // Proportional participation bar behind row
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF2563EB))
                                  .withValues(alpha: isHovered ? 0.12 : 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        color:
                            isHovered
                                ? (isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.primaryLight.withValues(
                                      alpha: 0.45,
                                    ))
                                : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                      children: [
                        // Rank
                        SizedBox(
                          width: 44,
                          child: Row(
                            children: [
                              if (rank <= 3) ...[
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color:
                                      rank == 1
                                          ? const Color(0xFFF59E0B)
                                          : rank == 2
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '$rank',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      rank <= 3
                                          ? (isDark
                                              ? const Color(0xFFF8FAFC)
                                              : AppColors.textPrimary)
                                          : (isDark
                                              ? const Color(0xFF94A3B8)
                                              : AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Customer Avatar + Name
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  customer.fullName.isNotEmpty
                                      ? customer.fullName[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.fullName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isDark
                                                ? const Color(0xFFF8FAFC)
                                                : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (customer.phone != null &&
                                        customer.phone!.isNotEmpty)
                                      Text(
                                        customer.phone!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Orders count
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF1E293B)
                                          : AppColors.slateLight.withValues(
                                            alpha: 0.5,
                                          ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${customer.orderCount} ord.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? const Color(0xFF94A3B8)
                                            : AppColors.slate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Average Ticket
                        Expanded(
                          flex: 3,
                          child: Text(
                            'S/ ${averageTicket.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        // Total Facturado
                        Expanded(
                          flex: 3,
                          child: Text(
                            'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color:
                                  isDark
                                      ? const Color(0xFF34D399)
                                      : AppColors.tealDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Action Button
                        SizedBox(
                          width: 80,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Ver detalle de cliente',
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              onPressed: () => widget.onCustomerTap(customer),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALLE DE CLIENTE VIP EN MODAL / BOTTOM SHEET CON BOTÓN DE CIERRE
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerDetailView extends StatelessWidget {
  final CustomerEntity customer;

  const _CustomerDetailView({required this.customer});

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/51$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  customer.fullName.isNotEmpty
                      ? customer.fullName[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.documentNumber != null &&
                              customer.documentNumber!.isNotEmpty
                          ? '${customer.documentType ?? 'DOC'}: ${customer.documentNumber}'
                          : 'Cliente Destacado VIP',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón de cierre explícito para mouse en Desktop
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Estadísticas de compra del cliente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkSurfaceElevated : AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Comprado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark
                                  ? const Color(0xFF34D399)
                                  : AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedidos Despachados',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${customer.orderCount} órdenes',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Acciones rápidas (WhatsApp / Llamar / Ver módulo de clientes)
          Row(
            children: [
              if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPhone(customer.phone!),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Llamar'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openWhatsApp(customer.phone!),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/customers');
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Ver en Clientes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
