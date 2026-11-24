import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Skeleton único con un solo AnimationController compartido para proteger CPU/GPU
/// en teléfonos de gama baja o antiguos (usado únicamente en carga fría sin caché).
class _SingleTickerSkeletonPulse extends StatefulWidget {
  final Widget Function(BuildContext context, Color pulseColor) builder;

  const _SingleTickerSkeletonPulse({required this.builder});

  @override
  State<_SingleTickerSkeletonPulse> createState() =>
      _SingleTickerSkeletonPulseState();
}

class _SingleTickerSkeletonPulseState extends State<_SingleTickerSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final begin =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final end = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(begin, end, _controller.value)!;
        return widget.builder(context, color);
      },
    );
  }
}

/// Esqueleto ultraligero para la vista en tabla en Desktop y Tablet (1 único Ticker).
class DesktopTableSkeleton extends StatelessWidget {
  const DesktopTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: _SingleTickerSkeletonPulse(
          builder: (context, pulseColor) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: List.generate(
                  6,
                  (index) => Container(
                    height: 44,
                    margin: EdgeInsets.only(bottom: index == 5 ? 0 : 10),
                    decoration: BoxDecoration(
                      color: pulseColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Esqueleto ultraligero para tarjetas o lista móvil (1 único Ticker).
class CustomersCardSkeleton extends StatelessWidget {
  const CustomersCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _SingleTickerSkeletonPulse(
          builder: (context, pulseColor) {
            return Column(
              children: List.generate(
                5,
                (index) => Container(
                  height: 112,
                  margin: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
                  decoration: BoxDecoration(
                    color: pulseColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
