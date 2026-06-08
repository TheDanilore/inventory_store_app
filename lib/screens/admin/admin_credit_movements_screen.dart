import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/credit_movement_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCreditMovementsScreen extends StatefulWidget {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;

  const AdminCreditMovementsScreen({
    super.key,
    required this.creditId,
    required this.customerName,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
  });

  @override
  State<AdminCreditMovementsScreen> createState() =>
      _AdminCreditMovementsScreenState();
}

class _AdminCreditMovementsScreenState
    extends State<AdminCreditMovementsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<CreditMovementModel> _movements = [];

  // Totales calculados localmente a partir de los movimientos
  double _totalCharged = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    try {
      final response = await _supabase
          .from('credit_movements_summary')
          .select()
          .eq('credit_id', widget.creditId)
          .order('created_at', ascending: false);

      final list =
          (response as List)
              .map((e) => CreditMovementModel.fromJson(e))
              .toList();

      double charged = 0;
      double paid = 0;

      for (final m in list) {
        if (m.isCharge) {
          charged += m.amount;
        } else {
          paid += m.amount;
        }
      }

      if (mounted) {
        setState(() {
          _movements = list;
          _totalCharged = charged;
          _totalPaid = paid;
        });
      }
    } catch (e) {
      debugPrint('Error cargando movimientos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtPercent =
        widget.creditLimit > 0
            ? (widget.currentDebt / widget.creditLimit).clamp(0.0, 1.0)
            : 0.0;

    debugPrint('currentDebt: ${widget.currentDebt}');
    debugPrint('creditLimit: ${widget.creditLimit}');
    debugPrint('debtPercent: $debtPercent');

    return AdminLayout(
      title: 'Historial de Crédito',
      showBackButton: true,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  // ── Encabezado con resumen ──────────────────────────────
                  SliverToBoxAdapter(
                    child: _SummaryHeader(
                      customerName: widget.customerName,
                      currentDebt: widget.currentDebt,
                      creditLimit: widget.creditLimit,
                      debtPercent: debtPercent,
                      totalCharged: _totalCharged,
                      totalPaid: _totalPaid,
                    ),
                  ),

                  // ── Lista de movimientos ────────────────────────────────
                  if (_movements.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Sin movimientos registrados',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          // Separador de fecha entre días distintos
                          final movement = _movements[index];
                          final showDateLabel =
                              index == 0 ||
                              !_sameDay(
                                movement.createdAt,
                                _movements[index - 1].createdAt,
                              );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateLabel) ...[
                                const SizedBox(height: 16),
                                _DateDivider(date: movement.createdAt),
                                const SizedBox(height: 8),
                              ],
                              _MovementCard(movement: movement),
                              const SizedBox(height: 8),
                            ],
                          );
                        }, childCount: _movements.length),
                      ),
                    ),
                ],
              ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ─── WIDGET: Encabezado con resumen ──────────────────────────────────────────
class _SummaryHeader extends StatelessWidget {
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final double debtPercent;
  final double totalCharged;
  final double totalPaid;

  const _SummaryHeader({
    required this.customerName,
    required this.currentDebt,
    required this.creditLimit,
    required this.debtPercent,
    required this.totalCharged,
    required this.totalPaid,
  });

  @override
  Widget build(BuildContext context) {
    final isAtRisk = debtPercent >= 0.8;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isAtRisk
                  ? [Colors.red.shade700, Colors.red.shade500]
                  : [AppColors.teal, AppColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isAtRisk ? Colors.red : AppColors.teal).withValues(
              alpha: 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del cliente
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  customerName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Cuenta de crédito',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Deuda actual destacada
          Text(
            'Deuda actual',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'S/ ${currentDebt.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),

          // Barra de progreso
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: debtPercent,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(debtPercent * 100).toStringAsFixed(0)}% usado',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
              Text(
                'Límite: S/ ${creditLimit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),

          // Fila: Total cargado vs total pagado
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Total cargado',
                  value: 'S/ ${totalCharged.toStringAsFixed(2)}',
                  icon: Icons.arrow_upward_rounded,
                  color: Colors.orange.shade200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  label: 'Total pagado',
                  value: 'S/ ${totalPaid.toStringAsFixed(2)}',
                  icon: Icons.arrow_downward_rounded,
                  color: Colors.green.shade200,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
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

// ─── WIDGET: Separador de fecha ───────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime? date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == null) {
      label = 'Fecha desconocida';
    } else {
      final d = DateTime(date!.year, date!.month, date!.day);
      if (d == today) {
        label = 'Hoy';
      } else if (d == yesterday) {
        label = 'Ayer';
      } else {
        label = DateFormat('d MMMM yyyy', 'es').format(date!);
      }
    }

    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// ─── WIDGET: Tarjeta de movimiento ───────────────────────────────────────────
class _MovementCard extends StatelessWidget {
  final CreditMovementModel movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isCharge = movement.movementType == 'CHARGE';
    final color = isCharge ? Colors.orange : Colors.green;
    final bgColor = isCharge ? Colors.orange.shade50 : Colors.green.shade50;
    final icon =
        isCharge ? Icons.shopping_cart_rounded : Icons.payments_rounded;
    final sign = isCharge ? '+' : '-';
    final timeStr =
        movement.createdAt != null
            ? DateFormat('HH:mm').format(movement.createdAt!.toLocal())
            : '--:--';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Ícono
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Info central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCharge ? 'Cargo por venta' : 'Pago registrado',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 4),

                  if (isCharge && movement.orderTotalAmount != null)
                    Text(
                      'Venta: S/ ${movement.orderTotalAmount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),

                  if (movement.orderNumber != null)
                    Text(
                      'Pedido #${movement.orderNumber!.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),

                  if (!isCharge && movement.orderPaymentMethod != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _MethodChip(method: movement.orderPaymentMethod!),
                    ),

                  if (movement.notes?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        movement.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 12,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          movement.createdByName ?? 'Sistema',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            // Monto
            Text(
              '$sign S/ ${movement.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String method;
  const _MethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.green.shade700,
        ),
      ),
    );
  }
}
