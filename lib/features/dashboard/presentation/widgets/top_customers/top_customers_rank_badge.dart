import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Insignia de rango (medalla 1, 2, 3 o número) con gradientes y sombras pre-compiladas
class TopCustomerRankBadge extends StatelessWidget {
  final int rank;
  final bool isDark;

  const TopCustomerRankBadge({
    super.key,
    required this.rank,
    this.isDark = false,
  });

  // Constantes de estilo en memoria para cero asignaciones por frame
  static const _goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const _silverGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Color(0xFFCBD5E1), Color(0xFF64748B)],
  );

  static const _bronzeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFEDD5), Color(0xFFFB923C), Color(0xFF9A3412)],
  );

  @override
  Widget build(BuildContext context) {
    if (rank == 1) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: _goldGradient,
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
          gradient: _silverGradient,
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
          gradient: _bronzeGradient,
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
}

/// Avatar de cliente con inicial y degradado institucional
class TopCustomerAvatar extends StatelessWidget {
  final CustomerEntity customer;
  final double size;

  const TopCustomerAvatar({super.key, required this.customer, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initials =
        customer.fullName.isNotEmpty
            ? customer.fullName.substring(0, 1).toUpperCase()
            : 'C';

    return Container(
      width: size,
      height: size,
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
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
