import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/kardex_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/kardex/kardex_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

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

  @override
  Widget build(BuildContext context) {
    return Consumer<KardexProvider>(
      builder: (context, provider, _) {
        final start = provider.currentPage * KardexProvider.pageSize;
        final end =
            (start + KardexProvider.pageSize) > provider.totalCount
                ? provider.totalCount
                : (start + KardexProvider.pageSize);

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.white,
                child: Row(
                  children: [
                    // Dropdown de tipo
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: provider.typeFilter,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'ALL',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'ENTRY',
                                child: Text('Ingresos'),
                              ),
                              DropdownMenuItem(
                                value: 'EXIT',
                                child: Text('Salidas'),
                              ),
                              DropdownMenuItem(
                                value: 'SALE',
                                child: Text('Ventas'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                provider.setTypeFilter(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DateFilterCalendar(
                        dateRange: provider.dateRange,
                        onDateRangeSelected: (picked) {
                          provider.setDateRange(picked);
                        },
                        onClear: () {
                          provider.setDateRange(null);
                        },
                      ),
                    ),
                    if (provider.dateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          provider.setDateRange(null);
                        },
                      ),
                    ],
                  ],
                ),
              ),

              // --- LISTADO DE MOVIMIENTOS ---
              Expanded(
                child:
                    provider.isLoading
                        ? const KardexSkeleton()
                        : provider.movements.isEmpty
                        ? const AppEmptyState(
                          icon: Icons.history,
                          title: 'No hay movimientos',
                          message:
                              'Aún no se han registrado ingresos o salidas de inventario en estas fechas.',
                        )
                        : RefreshIndicator(
                          onRefresh: provider.refresh,
                          color: AppColors.primary,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Mostrando ${provider.totalCount == 0 ? 0 : start + 1}-$end de ${provider.totalCount}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Página ${provider.currentPage + 1} / ${provider.totalPages}',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // LISTA DE TARJETAS
                              Expanded(
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: provider.movements.length,
                                  itemBuilder: (context, index) {
                                    return KardexCard(
                                      item: provider.movements[index],
                                    );
                                  },
                                ),
                              ),

                              // CONTROLES DE PÁGINA
                              if (provider.totalPages > 1)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    10,
                                  ),
                                  child: AdminPageBlocks(
                                    currentPage: provider.currentPage,
                                    totalPages: provider.totalPages,
                                    onPageChanged: provider.setPage,
                                  ),
                                ),
                            ],
                          ),
                        ),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'fab_in',
                onPressed: () => _openEntryScreen(context),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text(
                  'Ingreso',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'fab_out',
                onPressed: () => _openExitScreen(context),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text(
                  'Salida',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        );
      },
    );
  }
}
