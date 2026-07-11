import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_card.dart';

class CustomerCreditsScreen extends StatefulWidget {
  const CustomerCreditsScreen({super.key});

  @override
  State<CustomerCreditsScreen> createState() => _CustomerCreditsScreenState();
}

class _CustomerCreditsScreenState extends State<CustomerCreditsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerCreditListCubit>()..loadAccounts(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Cuentas por Cobrar'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    context.read<CustomerCreditListCubit>().loadAccounts();
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // Búsqueda
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<CustomerCreditListCubit>().search('');
                        },
                      ),
                    ),
                    onChanged: (val) {
                      context.read<CustomerCreditListCubit>().search(val);
                    },
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: BlocBuilder<
                      CustomerCreditListCubit,
                      CustomerCreditListState
                    >(
                      builder: (context, state) {
                        if (state is CustomerCreditListLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (state is CustomerCreditListError) {
                          return Center(
                            child: Text(
                              state.message,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          );
                        } else if (state is CustomerCreditListLoaded) {
                          final credits = state.accounts;
                          if (credits.isEmpty) {
                            return AppEmptyState(
                              title: 'Sin créditos',
                              message: 'No hay cuentas por cobrar.',
                              icon: Icons.account_balance_wallet,
                            );
                          }
                          return ListView.separated(
                            itemCount: credits.length,
                            separatorBuilder:
                                (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final account = credits[index];
                              return CreditAccountCard(
                                account: account,
                                onTap: () {
                                  context.push(
                                    '/customer-credit-movements/${account.id}?name=${Uri.encodeComponent(account.customerName ?? '')}',
                                  );
                                },
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
        },
      ),
    );
  }
}
