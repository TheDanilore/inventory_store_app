import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/providers/admin/supplier_credit_movements_provider.dart';

// Widgets extraídos
import 'package:inventory_store_app/screens/admin/widgets/supplier_credit_movements/summary_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/supplier_credit_movements/movement_card.dart';

class SupplierCreditMovementsScreen extends StatelessWidget {
  final String creditId;
  final String supplierName;
  final double currentDebt;
  final double creditLimit;

  const SupplierCreditMovementsScreen({
    super.key,
    required this.creditId,
    required this.supplierName,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SupplierCreditMovementsProvider>(
      create:
          (_) => SupplierCreditMovementsProvider(
            creditId: creditId,
            supplierName: supplierName,
          ),
      child: _SupplierCreditMovementsView(
        supplierName: supplierName,
        currentDebt: currentDebt,
        creditLimit: creditLimit,
      ),
    );
  }
}

class _SupplierCreditMovementsView extends StatefulWidget {
  final String supplierName;
  final double currentDebt;
  final double creditLimit;

  const _SupplierCreditMovementsView({
    required this.supplierName,
    required this.currentDebt,
    required this.creditLimit,
  });

  @override
  State<_SupplierCreditMovementsView> createState() =>
      _SupplierCreditMovementsViewState();
}

class _SupplierCreditMovementsViewState
    extends State<_SupplierCreditMovementsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierCreditMovementsProvider>().addListener(
        _onProviderChange,
      );
    });
  }

  @override
  void dispose() {
    // We don't remove listener explicitly on dispose because the provider will be disposed too,
    // but it's good practice if it wasn't provided locally.
    super.dispose();
  }

  void _onProviderChange() {
    final provider = context.read<SupplierCreditMovementsProvider>();
    if (provider.errorMessage != null && mounted) {
      AppSnackbar.show(
        context,
        message: provider.errorMessage!,
        type: SnackbarType.error,
      );
      provider.clearError();
    }
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showFilterSheet(
    BuildContext context,
    SupplierCreditMovementsProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Filtrar por fecha',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Este mes'),
                trailing:
                    provider.dateFilter == MovementDateFilter.thisMonth
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                onTap: () {
                  provider.setDateFilter(MovementDateFilter.thisMonth);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Mes pasado'),
                trailing:
                    provider.dateFilter == MovementDateFilter.lastMonth
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                onTap: () {
                  provider.setDateFilter(MovementDateFilter.lastMonth);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Todo el historial'),
                trailing:
                    provider.dateFilter == MovementDateFilter.allTime
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                onTap: () {
                  provider.setDateFilter(MovementDateFilter.allTime);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupplierCreditMovementsProvider>(
      builder: (context, provider, _) {
        final debtPercent =
            widget.creditLimit > 0
                ? (widget.currentDebt / widget.creditLimit).clamp(0.0, 1.0)
                : 0.0;

        return AdminLayout(
          title: 'Historial de Cuenta',
          showBackButton: true,
          showProfileButton: false,
          showDrawerButton: false,
          showSettingsButton: true,
          settingsActions: const [
            PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
            PopupMenuItem(value: 'filter', child: Text('Filtrar por fecha')),
          ],
          onSettingsSelected: (value) {
            if (value == 'export') {
              if (!provider.isExporting) provider.exportToPdf();
            } else if (value == 'filter') {
              _showFilterSheet(context, provider);
            }
          },
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SupplierCreditMovementsSummaryHeader(
                          supplierName: widget.supplierName,
                          currentDebt: widget.currentDebt,
                          creditLimit: widget.creditLimit,
                          debtPercent: debtPercent,
                          totalCharged: provider.totalCharged,
                          totalPaid: provider.totalPaid,
                        ),
                      ),

                      if (provider.isLoading)
                        const SliverFillRemaining(child: _MovementsSkeleton())
                      else if (provider.movements.isEmpty)
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final movement = provider.movements[index];
                              final showDateLabel =
                                  index == 0 ||
                                  !_sameDay(
                                    movement.createdAt,
                                    provider.movements[index - 1].createdAt,
                                  );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDateLabel) ...[
                                    const SizedBox(height: 16),
                                    _DateDivider(date: movement.createdAt),
                                    const SizedBox(height: 8),
                                  ],
                                  SupplierCreditMovementCard(
                                    movement: movement,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            }, childCount: provider.movements.length),
                          ),
                        ),
                    ],
                  ),
                ),
                if (provider.totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: AdminPageBlocks(
                      currentPage: provider.currentPage,
                      totalPages: provider.totalPages,
                      onPageChanged: (page) => provider.setPage(page),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

class _MovementsSkeleton extends StatelessWidget {
  const _MovementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
