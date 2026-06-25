import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/kardex_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/kardex/kardex_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';

class KardexScreen extends StatelessWidget {
  const KardexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KardexProvider(),
      child: const _KardexView(),
    );
  }
}

class _KardexView extends StatefulWidget {
  const _KardexView();

  @override
  State<_KardexView> createState() => _KardexViewState();
}

class _KardexViewState extends State<_KardexView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KardexProvider>().addListener(_onProviderError);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onProviderError() {
    if (!mounted) return;
    final error = context.read<KardexProvider>().errorMessage;
    if (error != null) {
      AppSnackbar.show(context, message: error, type: SnackbarType.error);
      context.read<KardexProvider>().clearError();
    }
  }

  Future<void> _openExitScreen(BuildContext context) async {
    final provider = context.read<KardexProvider>();
    final result = await context.push('/admin/inventory-exit-form');
    if (result == true) {
      provider.refresh();
    }
  }

  Future<void> _openEntryScreen(BuildContext context) async {
    final provider = context.read<KardexProvider>();
    final result = await context.push('/admin/inventory-entry-form');
    if (result == true) {
      provider.refresh();
    }
  }

  void _showActionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Registrar Movimiento',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: Icon(
                        Icons.add_shopping_cart,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: const Text(
                      'Ingreso de inventario',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Registrar compras o retornos'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openEntryScreen(context);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red.shade700,
                      ),
                    ),
                    title: const Text(
                      'Salida de inventario',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Registrar mermas o retiros manuales'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openExitScreen(context);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFilterChip(KardexProvider provider, String label, String value) {
    final isSelected = provider.typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) => provider.setTypeFilter(value),
          selectedColor: AppColors.primary.withValues(alpha: 0.15),
          checkmarkColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
          labelStyle: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KardexProvider>(
      builder: (context, provider, _) {
        return AdminLayout(
          title: 'Kardex (Movimientos)',
          showBackButton: true,
          showSettingsButton: true,
          settingsActions: const [
            PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
          ],
          onSettingsSelected: (value) {
            if (value == 'export') {
              if (!provider.isExporting) provider.exportToPdf();
            }
          },
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: provider.refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // --- HEADER Y FILTROS ---
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildFilterChip(
                                        provider,
                                        'Todos',
                                        'ALL',
                                      ),
                                      _buildFilterChip(
                                        provider,
                                        'Ingresos',
                                        'ENTRY',
                                      ),
                                      _buildFilterChip(
                                        provider,
                                        'Salidas',
                                        'EXIT',
                                      ),
                                      _buildFilterChip(
                                        provider,
                                        'Ventas',
                                        'SALE',
                                      ),
                                      _buildFilterChip(
                                        provider,
                                        'Devoluciones',
                                        'RETURN',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              DateFilterCalendar(
                                dateRange: provider.dateRange,
                                onDateRangeSelected: (picked) {
                                  provider.setDateRange(picked);
                                },
                                onClear: () {
                                  provider.setDateRange(null);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- CONTEO ---
                      if (!provider.isLoading && provider.movements.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${provider.totalCount} movimientos encontrados',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // --- LISTADO ---
                      if (provider.isLoading && provider.movements.isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: KardexSkeleton()),
                        )
                      else if (provider.movements.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.history,
                            title: 'No hay movimientos',
                            message:
                                'Aún no se han registrado ingresos o salidas de inventario en estas fechas.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return KardexCard(
                                item: provider.movements[index],
                              );
                            }, childCount: provider.movements.length),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- PAGINACIÓN ANCLADA ---
              if (provider.totalPages > 1 && !provider.isLoading)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: AdminPageBlocks(
                      currentPage: provider.currentPage,
                      totalPages: provider.totalPages,
                      onPageChanged: (page) => provider.changePage(page),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showActionOptions(context),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Movimiento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}
