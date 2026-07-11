import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_movements_state.dart';

import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credit_movements/movements_summary_header.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credit_movements/movement_card.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CustomerCreditMovementsScreen extends StatelessWidget {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final Function(String orderId) onOpenOrder;

  const CustomerCreditMovementsScreen({
    super.key,
    required this.creditId,
    required this.customerName,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
    required this.onOpenOrder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => sl<CustomerCreditMovementsCubit>()..loadMovements(creditId),
      child: _CustomerCreditMovementsScreenContent(
        creditId: creditId,
        customerName: customerName,
        currentDebt: currentDebt,
        creditLimit: creditLimit,
        onOpenOrder: onOpenOrder,
      ),
    );
  }
}

class _CustomerCreditMovementsScreenContent extends StatefulWidget {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final Function(String orderId) onOpenOrder;

  const _CustomerCreditMovementsScreenContent({
    required this.creditId,
    required this.customerName,
    required this.currentDebt,
    required this.creditLimit,
    required this.onOpenOrder,
  });

  @override
  State<_CustomerCreditMovementsScreenContent> createState() =>
      _CustomerCreditMovementsScreenContentState();
}

class _CustomerCreditMovementsScreenContentState
    extends State<_CustomerCreditMovementsScreenContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<CustomerCreditMovementsCubit>().loadMore(widget.creditId);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtPercent =
        widget.creditLimit > 0
            ? (widget.currentDebt / widget.creditLimit).clamp(0.0, 1.0)
            : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Movimientos de Crédito'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          MovementsSummaryHeader(
            customerName: widget.customerName,
            currentDebt: widget.currentDebt,
            creditLimit: widget.creditLimit,
            debtPercent: debtPercent,
            totalCharged: 0.0,
            totalPaid: 0.0,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: EdgeInsets.zero,
              child: BlocBuilder<
                CustomerCreditMovementsCubit,
                CustomerCreditMovementsState
              >(
                builder: (context, state) {
                  if (state is CustomerCreditMovementsLoading ||
                      state is CustomerCreditMovementsInitial) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is CustomerCreditMovementsError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    );
                  } else if (state is CustomerCreditMovementsLoaded) {
                    final movements = state.movements;
                    if (movements.isEmpty) {
                      return const Center(
                        child: Text('No hay movimientos registrados'),
                      );
                    }
                    return ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          movements.length + (state.hasReachedMax ? 0 : 1),
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 12);
                      },
                      itemBuilder: (context, index) {
                        if (index >= movements.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final movement = movements[index];
                        return MovementCard(
                          movement: movement,
                          onOpenOrder: widget.onOpenOrder,
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
