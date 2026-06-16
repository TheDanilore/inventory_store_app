import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/supplier_model.dart';
import 'package:inventory_store_app/providers/admin/suppliers_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/suppliers/supplier_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/suppliers/supplier_form_modal.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SuppliersProvider(),
      child: const _SuppliersView(),
    );
  }
}

class _SuppliersView extends StatefulWidget {
  const _SuppliersView();

  @override
  State<_SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends State<_SuppliersView> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SuppliersProvider>().addListener(_onProviderError);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onProviderError() {
    if (!mounted) return;
    final error = context.read<SuppliersProvider>().errorMessage;
    if (error != null) {
      AppSnackbar.show(context, message: error, type: SnackbarType.error);
      context.read<SuppliersProvider>().clearError();
    }
  }

  void _onSearchChanged(String query, SuppliersProvider provider) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      provider.setSearchQuery(query);
    });
  }

  void _openSupplierModal(BuildContext context, [SupplierModel? supplier]) {
    final provider = context.read<SuppliersProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => SupplierFormModal(
            supplierToEdit: supplier,
            onSaved: () => provider.refresh(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SuppliersProvider>(
      builder: (context, provider, _) {
        return AdminLayout(
          title: 'Directorio de Proveedores',
          showBackButton: true,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openSupplierModal(context),
            backgroundColor: AppColors.teal,
            icon: const Icon(Icons.add_business_rounded, color: Colors.white),
            label: const Text(
              'Nuevo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              // ── Buscador ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => _onSearchChanged(val, provider),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, RUC o contacto...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // ── Lista ──
              Expanded(
                child:
                    provider.isLoading
                        ? const _SuppliersSkeleton()
                        : provider.suppliers.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                provider.searchQuery.isNotEmpty
                                    ? 'No hay resultados para la búsqueda'
                                    : 'No hay proveedores registrados',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                        : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Página ${provider.currentPage + 1} de ${provider.totalPages}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: () => provider.refresh(),
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    16,
                                  ),
                                  itemCount: provider.suppliers.length,
                                  separatorBuilder:
                                      (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final supplier = provider.suppliers[index];
                                    return SupplierCard(
                                      supplier: supplier,
                                      onEdit:
                                          () => _openSupplierModal(
                                            context,
                                            supplier,
                                          ),
                                      onToggleStatus:
                                          () => provider.toggleSupplierStatus(
                                            supplier,
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ),
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
            ],
          ),
        );
      },
    );
  }
}

class _SuppliersSkeleton extends StatelessWidget {
  const _SuppliersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Container(height: 1, color: AppColors.border),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 24,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 24,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
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
