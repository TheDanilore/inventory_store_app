import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/categories_empty_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/categories_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/categories_stats_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/category_desktop_row.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/category_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/category_mobile_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/category_search_bar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  static const _categoryColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // violet
  ];

  static Color _getCategoryColor(String name) {
    if (name.isEmpty) return _categoryColors[0];
    return _categoryColors[name.hashCode.abs() % _categoryColors.length];
  }

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 10 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = context.read<CategoriesCubit>().state.searchQuery;
      if (query.isNotEmpty) _searchCtrl.text = query;
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showCategoryForm([CategoryEntity? category]) {
    CategoryFormSheet.showAdaptive(context, category: category);
  }

  Future<void> _handleToggleStatus(
    CategoryEntity cat,
    bool val,
    CategoriesCubit cubit,
  ) async {
    AppFeedbackService.lightImpact();
    if (!val) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: 'Desactivar Categoría',
        message:
            '¿Estás seguro de desactivar la categoría "${cat.name}"? '
            'Los productos asociados podrían dejar de ser visibles para los clientes.',
        confirmText: 'Desactivar',
        confirmColor: AppColors.error,
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    cubit.toggleStatus(cat, val);
  }

  Future<bool> _confirmDeleteCategory(
    CategoryEntity cat,
    CategoriesCubit cubit,
  ) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'Eliminar Categoría',
      message:
          '¿Estás seguro de eliminar la categoría "${cat.name}"?\n'
          'Se validará que no tenga productos vinculados.',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirm != true) return false;
    if (!mounted) return false;

    final success = await cubit.deleteCategory(cat.id!);
    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Categoría eliminada exitosamente.',
        type: SnackbarType.success,
      );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            _showCategoryForm,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            _showCategoryForm,
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true):
            _showCategoryForm,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyK, alt: true):
            () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape):
            () => _searchFocusNode.unfocus(),
      },
      child: Focus(
        autofocus: true,
        child: AdminLayout(
          title: 'Categorías',
          actions: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed:
                    () => context.read<CategoriesCubit>().loadCategories(
                      forceRefresh: true,
                    ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed:
                    () => context.read<CategoriesCubit>().loadCategories(
                      forceRefresh: true,
                    ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: const Text(
                  'Actualizar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showCategoryForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Nueva Categoría',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
          floatingActionButton:
              isMobile
                  ? FloatingActionButton.extended(
                    onPressed: () => _showCategoryForm(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    tooltip:
                        'Crear nueva categoría (${AppShortcutLabels.newRecord})',
                    icon: const Icon(Icons.add_rounded),
                    label: ValueListenableBuilder<bool>(
                      valueListenable: _isFabExtended,
                      builder:
                          (context, extended, _) => AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child:
                                extended
                                    ? const Text(
                                      'Nueva',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                    : const SizedBox.shrink(),
                          ),
                    ),
                  )
                  : null,
          body: BlocConsumer<CategoriesCubit, CategoriesState>(
            listenWhen:
                (prev, curr) =>
                    curr.errorMessage != null &&
                    curr.errorMessage != prev.errorMessage,
            listener: (context, state) {
              if (state.errorMessage != null) {
                AppSnackbar.show(
                  context,
                  message: state.errorMessage!,
                  type: SnackbarType.error,
                );
              }
            },
            buildWhen:
                (prev, curr) =>
                    prev.viewState != curr.viewState ||
                    prev.categories != curr.categories ||
                    prev.searchQuery != curr.searchQuery,
            builder: (context, state) {
              final cubit = context.read<CategoriesCubit>();
              final isLoading =
                  state.viewState == ViewState.loading &&
                  state.categories.isEmpty;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 960;
                  return isDesktop
                      ? _buildDesktopView(context, state, cubit, isLoading)
                      : _buildMobileView(context, state, cubit, isLoading);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopView(
    BuildContext context,
    CategoriesState state,
    CategoriesCubit cubit,
    bool isLoading,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategorySearchBar(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                onChanged: cubit.onSearchChanged,
                onClear: () {
                  _searchCtrl.clear();
                  cubit.clearSearch();
                },
                hasQuery: state.searchQuery.isNotEmpty,
              ),
              const SizedBox(height: 12),
              CategoriesStatsBar(categories: state.categories),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.loadCategories(forceRefresh: true),
                  color: AppColors.primary,
                  child:
                      isLoading
                          ? const CategoriesSkeleton(itemCount: 6)
                          : state.categories.isEmpty
                          ? CategoriesEmptyState(
                            isSearch: state.searchQuery.isNotEmpty,
                            searchQuery: state.searchQuery,
                            onCreateCategory: () => _showCategoryForm(),
                          )
                          : ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: state.categories.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final cat = state.categories[index];
                              return CategoryDesktopRow(
                                key: ValueKey(cat.id ?? cat.name),
                                category: cat,
                                catColor: _getCategoryColor(cat.name),
                                onEdit: () => _showCategoryForm(cat),
                                onDelete:
                                    () => _confirmDeleteCategory(cat, cubit),
                                onToggle:
                                    (val) =>
                                        _handleToggleStatus(cat, val, cubit),
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileView(
    BuildContext context,
    CategoriesState state,
    CategoriesCubit cubit,
    bool isLoading,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategorySearchBar(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                onChanged: cubit.onSearchChanged,
                onClear: () {
                  _searchCtrl.clear();
                  cubit.clearSearch();
                },
                hasQuery: state.searchQuery.isNotEmpty,
              ),
              const SizedBox(height: 8),
              CategoriesStatsBar(categories: state.categories),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.loadCategories(forceRefresh: true),
            color: AppColors.primary,
            child:
                isLoading
                    ? const CategoriesSkeleton(itemCount: 6)
                    : state.categories.isEmpty
                    ? CategoriesEmptyState(
                      isSearch: state.searchQuery.isNotEmpty,
                      searchQuery: state.searchQuery,
                      onCreateCategory: () => _showCategoryForm(),
                    )
                    : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: state.categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cat = state.categories[index];
                        return Dismissible(
                          key: ValueKey(cat.id ?? cat.name),
                          direction: DismissDirection.endToStart,
                          confirmDismiss:
                              (_) => _confirmDeleteCategory(cat, cubit),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.error,
                                  size: 22,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          child: CategoryMobileCard(
                            category: cat,
                            catColor: _getCategoryColor(cat.name),
                            onEdit: () => _showCategoryForm(cat),
                            onDelete: () => _confirmDeleteCategory(cat, cubit),
                            onToggle:
                                (val) => _handleToggleStatus(cat, val, cubit),
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
