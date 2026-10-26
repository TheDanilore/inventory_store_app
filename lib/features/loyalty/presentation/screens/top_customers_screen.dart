import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers/loyalty_top_customers_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/animated_entrance.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/glass_roulette_dialog.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/premium_customer_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/ranked_customer_row.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/top_customers_shimmer_list.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class TopCustomersScreen extends StatefulWidget {
  const TopCustomersScreen({super.key});

  @override
  State<TopCustomersScreen> createState() => _TopCustomersScreenState();
}

class _TopCustomersScreenState extends State<TopCustomersScreen> {
  static const _limits = [5, 10, 20, 50, 100];

  void _openRoulette() {
    final cubit = context.read<LoyaltyTopCustomersCubit>();
    if (cubit.state.participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se necesitan al menos 2 clientes para el sorteo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar Ruleta',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:
          (context, _, _) => BlocProvider.value(
            value: cubit,
            child: const GlassRouletteDialog(),
          ),
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoyaltyTopCustomersCubit>().state;
    final cubit = context.read<LoyaltyTopCustomersCubit>();
    final list = state.participants;

    return AdminLayout(
      title: 'Top Clientes',
      showBackButton: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: _Header(
                        wide: wide,
                        limit: state.limit,
                        loading: state.isLoading,
                        onSpin: _openRoulette,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _LimitPills(
                        limits: _limits,
                        selected: state.limit,
                        enabled: !state.isLoading,
                        onSelected: cubit.setLimit,
                      ),
                    ),
                  ),
                  if (state.isLoading)
                    const SliverToBoxAdapter(child: TopCustomersShimmerList())
                  else if (list.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _StatsStrip(list: list),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: _Podium(top: list.take(3).toList(), wide: wide),
                      ),
                    ),
                    if (list.length > 3)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                          child: _RankingList(list: list, wide: wide),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool wide;
  final int limit;
  final bool loading;
  final VoidCallback onSpin;

  const _Header({
    required this.wide,
    required this.limit,
    required this.loading,
    required this.onSpin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Clientes',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quienes más compran en tu negocio. Prémialos con un sorteo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final button = FilledButton.icon(
      onPressed: loading ? null : onSpin,
      icon: const Icon(Icons.casino_rounded, size: 20),
      label: Text('Sortear entre el Top $limit'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Expanded(child: title), const SizedBox(width: 16), button],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: button),
      ],
    );
  }
}

class _LimitPills extends StatelessWidget {
  final List<int> limits;
  final int selected;
  final bool enabled;
  final ValueChanged<int> onSelected;

  const _LimitPills({
    required this.limits,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final v in limits)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                label: Text('Top $v'),
                selected: selected == v,
                onSelected: enabled ? (_) => onSelected(v) : null,
                labelStyle: TextStyle(
                  fontWeight: selected == v ? FontWeight.w800 : FontWeight.w600,
                  color:
                      selected == v
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: theme.colorScheme.surface,
                side: BorderSide(
                  color:
                      selected == v
                          ? AppColors.primary
                          : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final List<CustomerEntity> list;
  const _StatsStrip({required this.list});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(
      symbol: 'S/ ',
      decimalDigits: 1,
    );
    final total = list.fold<double>(0, (s, c) => s + c.totalRevenue.toDouble());
    final avg = list.isEmpty ? 0.0 : total / list.length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatPill(
          icon: Icons.groups_rounded,
          label: 'En el ranking',
          value: '${list.length}',
          color: AppColors.info,
        ),
        _StatPill(
          icon: Icons.payments_rounded,
          label: 'Facturado por el grupo',
          value: currency.format(total),
          color: AppColors.teal,
        ),
        _StatPill(
          icon: Icons.stacked_line_chart_rounded,
          label: 'Promedio por cliente',
          value: currency.format(avg),
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<CustomerEntity> top;
  final bool wide;
  const _Podium({required this.top, required this.wide});

  @override
  Widget build(BuildContext context) {
    Widget card(int i, {bool featured = false}) => AnimatedEntrance(
      index: i,
      child: PremiumCustomerCard(
        customer: top[i],
        position: i + 1,
        featured: featured,
      ),
    );

    if (wide) {
      // Orden visual del podio: 2º · 1º · 3º (el 1º sobresale).
      final order =
          top.length >= 3 ? [1, 0, 2] : List.generate(top.length, (i) => i);
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var k = 0; k < order.length; k++) ...[
            if (k > 0) const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: order[k] == 0 ? 0 : 28),
                child: card(order[k], featured: order[k] == 0),
              ),
            ),
          ],
        ],
      );
      if (top.length == 1) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: card(0, featured: true),
          ),
        );
      }
      return row;
    }

    // Móvil: el 1º ocupa todo el ancho; 2º y 3º lado a lado.
    return Column(
      children: [
        card(0, featured: true),
        if (top.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card(1)),
              const SizedBox(width: 12),
              Expanded(child: top.length > 2 ? card(2) : const SizedBox()),
            ],
          ),
        ],
      ],
    );
  }
}

class _RankingList extends StatelessWidget {
  final List<CustomerEntity> list;
  final bool wide;
  const _RankingList({required this.list, required this.wide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRevenue = list.fold<double>(
      0,
      (m, c) => c.totalRevenue.toDouble() > m ? c.totalRevenue.toDouble() : m,
    );
    final rest = list.skip(3).toList();
    final border = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'Ranking completo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'Puestos 4 – ${list.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rest.length; i++) ...[
            Divider(height: 1, color: border),
            AnimatedEntrance(
              index: i + 3,
              child: RankedCustomerRow(
                customer: rest[i],
                position: i + 4,
                maxRevenue: maxRevenue,
                showShare: wide,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no hay clientes con compras.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando registres ventas, tus mejores clientes aparecerán aquí.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
