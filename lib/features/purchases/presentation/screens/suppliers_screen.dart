import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_form_modal.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
// Note: We use SupplierEntity instead of SupplierModel in the UI now

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<SuppliersCubit>().setSearchQuery(query);
    });
  }

  void _openSupplierModal(BuildContext context, [SupplierEntity? supplier]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierFormModal(
        supplierToEdit: supplier,
        onSaved: () => context.read<SuppliersCubit>().loadSuppliers(refresh: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SuppliersCubit, SuppliersState>(
      listener: (context, state) {
        if (state is SuppliersError) {
          AppSnackbar.show(context, message: state.message, type: SnackbarType.error);
          context.read<SuppliersCubit>().clearError();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent, // Background provided by AdminLayout
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
            // Buscador
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, RUC o contacto...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            // Lista
            Expanded(
              child: BlocBuilder<SuppliersCubit, SuppliersState>(
                builder: (context, state) {
                  final isLoading = state is SuppliersLoading || state is SuppliersInitial;
                  
                  // Extract state values to avoid duplicate logic
                  List<SupplierEntity> suppliers = [];
                  String searchQuery = '';
                  int currentPage = 0;
                  int totalPages = 1;
                  
                  if (state is SuppliersLoaded) {
                    suppliers = state.suppliers;
                    searchQuery = state.searchQuery;
                    currentPage = state.currentPage;
                    totalPages = state.totalPages;
                  } else if (state is SuppliersLoading) {
                    suppliers = state.currentSuppliers;
                    searchQuery = state.searchQuery;
                    currentPage = state.currentPage;
                    totalPages = state.totalCount == 0 ? 1 : (state.totalCount / 8).ceil();
                  } else if (state is SuppliersError) {
                    suppliers = state.currentSuppliers;
                    searchQuery = state.searchQuery;
                    currentPage = state.currentPage;
                    totalPages = state.totalCount == 0 ? 1 : (state.totalCount / 8).ceil();
                  }

                  if (isLoading && suppliers.isEmpty) {
                    return const _SuppliersSkeleton();
                  }

                  if (suppliers.isEmpty) {
                    return Center(
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
                            searchQuery.isNotEmpty
                                ? 'No hay resultados para la búsqueda'
                                : 'No hay proveedores registrados',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Página ${currentPage + 1} de $totalPages',
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
                          onRefresh: () async => context.read<SuppliersCubit>().loadSuppliers(refresh: true),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: suppliers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final supplier = suppliers[index];
                              return SupplierCard(
                                // Notice SupplierCard might need to be updated to take SupplierEntity instead of SupplierModel
                                supplier: supplier,
                                onEdit: () => _openSupplierModal(context, supplier),
                                onToggleStatus: () => context.read<SuppliersCubit>().toggleSupplierStatus(supplier),
                              );
                            },
                          ),
                        ),
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: AdminPageBlocks(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            onPageChanged: context.read<SuppliersCubit>().setPage,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
      itemBuilder: (_, _) {
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
