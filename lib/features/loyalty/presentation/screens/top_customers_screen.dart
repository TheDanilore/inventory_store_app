import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/animated_entrance.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/glass_roulette_dialog.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/premium_customer_card.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/top_customers_shimmer_list.dart';

class TopCustomersScreen extends StatefulWidget {
  const TopCustomersScreen({super.key});

  @override
  State<TopCustomersScreen> createState() => _TopCustomersScreenState();
}

class _TopCustomersScreenState extends State<TopCustomersScreen> {
  void _openRoulette() {
    final state = context.read<TopCustomersCubit>().state;
    if (state.participants.length < 2) {
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
      pageBuilder: (context, animation, secondaryAnimation) {
        return const GlassRouletteDialog();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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
    final state = context.watch<TopCustomersCubit>().state;
    final cubit = context.read<TopCustomersCubit>();
    final theme = Theme.of(context);

    return AdminLayout(
      title: 'Top Clientes',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading ? null : _openRoulette,
        icon: const Icon(Icons.casino_rounded, color: Colors.white),
        label: const Text(
          'Ruleta de Sorteo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Filtros Modernos
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listado de Mejores Clientes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Chips de Filtro
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            [5, 10, 15, 20, 30, 50, 100].map((val) {
                              final isSelected = state.limit == val;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    'Top $val',
                                    style: TextStyle(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected:
                                      state.isLoading
                                          ? null
                                          : (selected) {
                                            if (selected) cubit.setLimit(val);
                                          },
                                  selectedColor: AppColors.primary,
                                  backgroundColor: theme.colorScheme.surface,
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : theme.colorScheme.outlineVariant
                                                .withValues(alpha: 0.3),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido Principal (Shimmer o Listado)
              Expanded(
                child:
                    state.isLoading
                        ? const TopCustomersShimmerList()
                        : state.participants.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group_off_rounded,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay clientes con compras.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 700;

                            if (isWide) {
                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ).copyWith(bottom: 100),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 450,
                                      mainAxisExtent: 96,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 0,
                                    ),
                                itemCount: state.participants.length,
                                itemBuilder: (context, index) {
                                  final c = state.participants[index];
                                  return AnimatedEntrance(
                                    index: index,
                                    child: PremiumCustomerCard(
                                      customer: c,
                                      position: index + 1,
                                    ),
                                  );
                                },
                              );
                            } else {
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ).copyWith(bottom: 100),
                                itemCount: state.participants.length,
                                itemBuilder: (context, index) {
                                  final c = state.participants[index];
                                  return AnimatedEntrance(
                                    index: index,
                                    child: PremiumCustomerCard(
                                      customer: c,
                                      position: index + 1,
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
