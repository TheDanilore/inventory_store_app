import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/top_customers/top_customers_rank_badge.dart';

/// Tabla de escritorio de alto rendimiento con hover granular por fila
class TopCustomersDesktopTable extends StatelessWidget {
  final List<CustomerEntity> customers;
  final ValueChanged<CustomerEntity> onCustomerTap;

  const TopCustomersDesktopTable({
    super.key,
    required this.customers,
    required this.onCustomerTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxRevenue =
        customers.isNotEmpty && customers.first.totalRevenue > 0
            ? customers.first.totalRevenue
            : 1.0;

    return Column(
      children: [
        // Table Header (Stateless / Constante)
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

        // Filas con layout directo sin shrinkWrap de ListView
        Column(
          children: [
            for (int i = 0; i < customers.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              TopCustomerTableRow(
                customer: customers[i],
                rank: i + 1,
                ratio: (customers[i].totalRevenue / maxRevenue).clamp(
                  0.04,
                  1.0,
                ),
                averageTicket:
                    customers[i].orderCount > 0
                        ? customers[i].totalRevenue / customers[i].orderCount
                        : 0.0,
                isDark: isDark,
                onTap: () => onCustomerTap(customers[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Fila individual de tabla con estado de hover 100% aislado (evita rebuilds en la tabla padre)
class TopCustomerTableRow extends StatefulWidget {
  final CustomerEntity customer;
  final int rank;
  final double ratio;
  final double averageTicket;
  final bool isDark;
  final VoidCallback onTap;

  const TopCustomerTableRow({
    super.key,
    required this.customer,
    required this.rank,
    required this.ratio,
    required this.averageTicket,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<TopCustomerTableRow> createState() => _TopCustomerTableRowState();
}

class _TopCustomerTableRowState extends State<TopCustomerTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final rank = widget.rank;
    final isDark = widget.isDark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            // Barra de participación proporcional
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF2563EB))
                        .withValues(alpha: _isHovered ? 0.12 : 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Container(
              color:
                  _isHovered
                      ? (isDark
                          ? AppColors.darkSurfaceElevated
                          : AppColors.primaryLight.withValues(alpha: 0.45))
                      : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Rango
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
                  // Avatar + Nombre
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        TopCustomerAvatar(customer: customer, size: 32),
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
                  // Órdenes
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
                  // Ticket medio
                  Expanded(
                    flex: 3,
                    child: Text(
                      'S/ ${widget.averageTicket.toStringAsFixed(2)}',
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
                  // Total facturado
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
                  // Botón de detalle
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
          ],
        ),
      ),
    );
  }
}
