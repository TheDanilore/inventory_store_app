import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:url_launcher/url_launcher.dart';

enum TopCustomersDisplayMode { desktop, tablet, mobile }

class TopCustomersCard extends StatelessWidget {
  final List<CustomerEntity> customers;
  final TopCustomersDisplayMode displayMode;

  const TopCustomersCard({
    super.key,
    required this.customers,
    required this.displayMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: AppColors.border),
          if (customers.isEmpty)
            _buildEmptyState(context)
          else
            _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                        fontSize: displayMode == TopCustomersDisplayMode.desktop ? 16 : 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amberLight,
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
                const Text(
                  'Mayores compradores por volumen de facturación histórica',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slateLight.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 32,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aún no hay clientes registrados con compras completadas.',
              style: TextStyle(
                color: AppColors.textSecondary,
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
        return _buildDesktopTable(context);
      case TopCustomersDisplayMode.tablet:
        return _buildTabletList(context);
      case TopCustomersDisplayMode.mobile:
        return _buildMobileList(context);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DESKTOP: TABLA DE ALTA DENSIDAD CON HOVER Y MICROINTERACCIONES
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopTable(BuildContext context) {
    final maxRevenue = customers.first.totalRevenue > 0
        ? customers.first.totalRevenue
        : 1.0;

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: AppColors.background.withValues(alpha: 0.6),
          child: const Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '#',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
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
                    color: AppColors.textSecondary,
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
                    color: AppColors.textSecondary,
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
                    color: AppColors.textSecondary,
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
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 80),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        // Table Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: customers.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.border),
          itemBuilder: (context, index) {
            final customer = customers[index];
            final rank = index + 1;
            final averageTicket = customer.orderCount > 0
                ? customer.totalRevenue / customer.orderCount
                : 0.0;
            final sharePercent = ((customer.totalRevenue / maxRevenue) * 100)
                .clamp(0, 100)
                .toDouble();

            return _DesktopCustomerRow(
              rank: rank,
              customer: customer,
              averageTicket: averageTicket,
              sharePercent: sharePercent,
              onTap: () => _openCustomerActionSheet(context, customer),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TABLET: LISTA EXPANDIDA EN 2 COLUMNAS / TARJETAS ENLAZADAS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTabletList(BuildContext context) {
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
          final averageTicket = customer.orderCount > 0
              ? customer.totalRevenue / customer.orderCount
              : 0.0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openCustomerActionSheet(context, customer),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  color: AppColors.surface,
                ),
                child: Row(
                  children: [
                    _buildRankBadge(rank),
                    const SizedBox(width: 14),
                    _buildAvatar(customer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${customer.orderCount} compras realizadas · Ticket medio S/ ${averageTicket.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tealDark,
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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final rank = index + 1;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openCustomerActionSheet(context, customer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _buildRankBadge(rank),
                  const SizedBox(width: 12),
                  _buildAvatar(customer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
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
                                color: AppColors.primaryLight,
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.tealDark,
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
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPONENTES ATÓMICOS: RANK MEDAL & AVATAR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildRankBadge(int rank) {
    Color bg;
    Color fg;
    String text;

    if (rank == 1) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      text = '1';
    } else if (rank == 2) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      text = '2';
    } else if (rank == 3) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
      text = '3';
    } else {
      bg = AppColors.background;
      fg = AppColors.textSecondary;
      text = '$rank';
    }

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fg.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildAvatar(CustomerEntity customer) {
    final initials = customer.fullName.isNotEmpty
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

    final content = _CustomerDetailView(customer: customer);

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
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
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: AppColors.border,
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
// FILA DE ESCRITORIO CON HOVER REACTIVO
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopCustomerRow extends StatefulWidget {
  final int rank;
  final CustomerEntity customer;
  final double averageTicket;
  final double sharePercent;
  final VoidCallback onTap;

  const _DesktopCustomerRow({
    required this.rank,
    required this.customer,
    required this.averageTicket,
    required this.sharePercent,
    required this.onTap,
  });

  @override
  State<_DesktopCustomerRow> createState() => _DesktopCustomerRowState();
}

class _DesktopCustomerRowState extends State<_DesktopCustomerRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _isHovered
              ? AppColors.primaryLight.withValues(alpha: 0.3)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 44,
                child: Row(
                  children: [
                    if (widget.rank <= 3) ...[
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: widget.rank == 1
                            ? const Color(0xFFF59E0B)
                            : widget.rank == 2
                                ? const Color(0xFF64748B)
                                : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${widget.rank}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.rank <= 3
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
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
                        widget.customer.fullName.isNotEmpty
                            ? widget.customer.fullName[0].toUpperCase()
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
                            widget.customer.fullName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.customer.phone != null &&
                              widget.customer.phone!.isNotEmpty)
                            Text(
                              widget.customer.phone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
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
                        color: AppColors.slateLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.customer.orderCount} ord.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate,
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
                  'S/ ${widget.averageTicket.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Total Facturado
              Expanded(
                flex: 3,
                child: Text(
                  'S/ ${widget.customer.totalRevenue.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.tealDark,
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
                    onPressed: widget.onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALLE DE CLIENTE VIP EN MODAL / BOTTOM SHEET
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.documentNumber != null &&
                              customer.documentNumber!.isNotEmpty
                          ? '${customer.documentType ?? 'DOC'}: ${customer.documentNumber}'
                          : 'Cliente Destacado VIP',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Estadísticas de compra del cliente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Comprado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pedidos Despachados',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openWhatsApp(customer.phone!),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
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
