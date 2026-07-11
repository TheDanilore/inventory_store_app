import 'package:flutter/material.dart';

class MovementsSummaryHeader extends StatelessWidget {
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final double debtPercent;
  final double totalCharged;
  final double totalPaid;

  const MovementsSummaryHeader({
    super.key,
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final primaryContainer = theme.colorScheme.primaryContainer;

    // Si está en riesgo, colores más oscuros/intensos para contraste
    final riskColor1 = Colors.red.shade800;
    final riskColor2 = Colors.red.shade600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isAtRisk
                  ? [riskColor1, riskColor2]
                  : [primaryColor, primaryContainer.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isAtRisk ? Colors.red : primaryColor).withValues(
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
                  customerName.isNotEmpty
                      ? customerName.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Deuda actual destacada
          Text(
            'Deuda actual',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'S/ ${currentDebt.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),

          // Barra de progreso
          const SizedBox(height: 16),
          Semantics(
            label:
                'Crédito utilizado: ${(debtPercent * 100).toInt()}% de un límite de S/ ${creditLimit.toStringAsFixed(2)}',
            value: '${(debtPercent * 100).toInt()} por ciento',
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: debtPercent,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(debtPercent * 100).toStringAsFixed(0)}% usado',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Límite: S/ ${creditLimit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),

          // Fila: Total cargado vs total pagado
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Total cargado',
                  value: 'S/ ${totalCharged.toStringAsFixed(2)}',
                  icon: Icons.arrow_upward_rounded,
                  color:
                      isAtRisk
                          ? Colors.white
                          : Colors.orange.shade100, 
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  label: 'Total pagado',
                  value: 'S/ ${totalPaid.toStringAsFixed(2)}',
                  icon: Icons.arrow_downward_rounded,
                  color:
                      isAtRisk
                          ? Colors.white
                          : Colors.green.shade100,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9), 
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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
  }
}
