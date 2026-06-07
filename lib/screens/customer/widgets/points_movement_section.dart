import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PointsMovementSection extends StatelessWidget {
  final List<Map<String, dynamic>> movements;

  const PointsMovementSection({super.key, required this.movements});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F9D8F)),
              const SizedBox(width: 10),
              const Text(
                'Movimientos recientes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2A2A2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (movements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 42,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Todavía no tienes movimientos.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            ...movements.map(_PointsMovementCard.new),
        ],
      ),
    );
  }
}

class _PointsMovementCard extends StatelessWidget {
  final Map<String, dynamic> mov;

  const _PointsMovementCard(this.mov);

  DateTime _parseLocalDateTime(dynamic rawValue) {
    if (rawValue is DateTime) {
      return rawValue.toLocal();
    }

    final parsed = DateTime.tryParse(rawValue?.toString() ?? '');
    if (parsed == null) {
      return DateTime.now();
    }

    return parsed.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = (mov['points'] as int) > 0;
    final date = _parseLocalDateTime(mov['created_at']);
    final points = mov['points'] as int;
    final color =
        isPositive ? const Color(0xFF119E5D) : const Color(0xFFE34D4D);
    final icon =
        isPositive ? Icons.add_circle_rounded : Icons.remove_circle_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mov['description']?.toString() ?? 'Movimiento',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${isPositive ? '+' : ''}$points',
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}