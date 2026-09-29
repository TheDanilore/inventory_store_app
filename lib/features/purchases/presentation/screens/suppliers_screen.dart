import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/suppliers/supplier_form_modal.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<SuppliersCubit>().setSearchQuery(query);
    });
  }

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
  bool get _isInputFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  KeyEventResult _handleKeyShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable, aislar atajos
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nuevo Proveedor
    if (key == LogicalKeyboardKey.keyN) {
      _openSupplierModal(context);
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar directorio
    if (key == LogicalKeyboardKey.keyR) {
      context.read<SuppliersCubit>().loadSuppliers(refresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando directorio de proveedores...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [Esc] -> Limpiar búsqueda o desenfocar
    if (key == LogicalKeyboardKey.escape) {
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<SuppliersCubit>().setSearchQuery('');
      }
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _openSupplierModal(BuildContext context, [SupplierEntity? supplier]) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final cubit = context.read<SuppliersCubit>();
    final modal = BlocProvider.value(
      value: cubit,
      child: SupplierFormModal(
        supplierToEdit: supplier,
        onSaved: () {},
      ),
    );

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: modal,
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyShortcuts,
      child: BlocListener<SuppliersCubit, SuppliersState>(
        listener: (context, state) {
          if (state is SuppliersError) {
            AppSnackbar.show(
              context,
              message: state.message,
              type: SnackbarType.error,
            );
            context.read<SuppliersCubit>().clearError();
          }
        },
        child: AdminLayout(
          title: 'Directorio de Proveedores',
          showBackButton: true,
          // En escritorio ocultamos el FAB; se muestra botón en Toolbar
          floatingActionButton:
              isDesktop
                  ? null
                  : FloatingActionButton(
                    onPressed: () => _openSupplierModal(context),
                    backgroundColor: AppColors.teal,
                    tooltip: 'Nuevo Proveedor',
                    child: const Icon(Icons.add_business_rounded, color: Colors.white),
                  ),
          body: Column(
            children: [
              // --- TOOLBAR UNIFICADO DE BÚSQUEDA Y ACCIONES ---
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(child: _buildSearchField()),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            color: AppColors.textSecondary,
                            tooltip: 'Refrescar [R]',
                            onPressed: () => context
                                .read<SuppliersCubit>()
                                .loadSuppliers(refresh: true),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openSupplierModal(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_business_rounded, size: 18),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Nuevo Proveedor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildKeyHint('N'),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _buildSearchField(),
              ),

              // --- LISTADO / GRILLA RESPONSIVA ---
              Expanded(
                child: BlocBuilder<SuppliersCubit, SuppliersState>(
                  builder: (context, state) {
                    final isLoading =
                        state is SuppliersLoading || state is SuppliersInitial;

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
                      totalPages =
                          state.totalCount == 0
                              ? 1
                              : (state.totalCount / 8).ceil();
                    } else if (state is SuppliersError) {
                      suppliers = state.currentSuppliers;
                      searchQuery = state.searchQuery;
                      currentPage = state.currentPage;
                      totalPages =
                          state.totalCount == 0
                              ? 1
                              : (state.totalCount / 8).ceil();
                    }

                    if (isLoading && suppliers.isEmpty) {
                      return _buildSkeletons(isDesktop);
                    }

                    if (suppliers.isEmpty) {
                      return Center(
                        child: AppEmptyState(
                          icon: Icons.storefront_rounded,
                          title: searchQuery.isNotEmpty
                              ? 'No se encontraron resultados'
                              : 'No hay proveedores registrados',
                          message: searchQuery.isNotEmpty
                              ? 'Intenta con otro término o limpia el buscador.'
                              : 'Registra un nuevo proveedor para comenzar.',
                          action: searchQuery.isNotEmpty
                              ? OutlinedButton.icon(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    context
                                        .read<SuppliersCubit>()
                                        .setSearchQuery('');
                                  },
                                  icon: const Icon(Icons.clear_all_rounded),
                                  label: const Text('Limpiar búsqueda'),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => _openSupplierModal(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add_business_rounded),
                                  label: const Text('Nuevo Proveedor'),
                                ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => context
                          .read<SuppliersCubit>()
                          .loadSuppliers(refresh: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            sliver: isDesktop
                                ? SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 440,
                                      mainAxisExtent: 180,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final supplier = suppliers[index];
                                        return SupplierCard(
                                          supplier: supplier,
                                          onEdit: () => _openSupplierModal(
                                            context,
                                            supplier,
                                          ),
                                          onToggleStatus: () => context
                                              .read<SuppliersCubit>()
                                              .toggleSupplierStatus(supplier),
                                        );
                                      },
                                      childCount: suppliers.length,
                                    ),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final supplier = suppliers[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: SupplierCard(
                                            supplier: supplier,
                                            onEdit: () => _openSupplierModal(
                                              context,
                                              supplier,
                                            ),
                                            onToggleStatus: () => context
                                                .read<SuppliersCubit>()
                                                .toggleSupplierStatus(supplier),
                                          ),
                                        );
                                      },
                                      childCount: suppliers.length,
                                    ),
                                  ),
                          ),
                          if (totalPages > 1)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                child: AdminPageBlocks(
                                  currentPage: currentPage,
                                  totalPages: totalPages,
                                  onPageChanged:
                                      context.read<SuppliersCubit>().setPage,
                                ),
                              ),
                            )
                          else
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Buscar por nombre, RUC o contacto...',
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                color: AppColors.textMuted,
                onPressed: () {
                  _searchCtrl.clear();
                  context.read<SuppliersCubit>().setSearchQuery('');
                },
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildKeyHint('/'),
              ),
          ],
        ),
        filled: true,
        fillColor: AppColors.background,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildKeyHint(String char) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSkeletons(bool isDesktop) {
    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const AppShimmer(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const AppShimmer(
        width: double.infinity,
        height: 160,
        borderRadius: 16,
      ),
    );
  }
}
