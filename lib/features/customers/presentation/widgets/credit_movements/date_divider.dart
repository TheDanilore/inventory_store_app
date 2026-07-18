import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateDivider extends StatelessWidget {
  final DateTime? date;

  const DateDivider({super.key, required this.date});

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
        const Expanded(child: Divider(color: Color(0xFFF1F5F9))), // AppColors.surface approx
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // AppColors.surface approx
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B), // AppColors.textMuted approx
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFF1F5F9))),
      ],
    );
  }
}
