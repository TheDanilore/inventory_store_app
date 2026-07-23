import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/features/catalog/presentation/bloc/categories_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories_state.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';

import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/categories_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/categories/category_form_sheet.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  final _searchCtrl = TextEditingController();

  static const _categoryColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // sky
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // violet
  ];

  Color _getCategoryColor(String name) {
    if (name.isEmpty) return _categoryColors[0];
    return _categoryColors[name.hashCode.abs() % _categoryColors.length];
  }

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  // Desktop Form State
  final _desktopNameCtrl = TextEditingController();
  final _desktopDescCtrl = TextEditingController();
  CategoryEntity? _editingCategory;
  bool _isSavingDesktop = false;

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
      if (query.isNotEmpty) {
        _searchCtrl.text = query;
      }
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _desktopNameCtrl.dispose();
    _desktopDescCtrl.dispose();
    super.dispose();
  }

  void _showCategoryForm([CategoryEntity? category]) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      setState(() {
        _editingCategory = category;
        _desktopNameCtrl.text = category?.name ?? '';
        _desktopDescCtrl.text = category?.description ?? '';
      });
      return;
    }

    final cubit = context.read<CategoriesCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => BlocProvider.value(
            value: cubit,
            child: CategoryFormSheet(category: category),
          ),
    );
  }

  void _clearDesktopForm() {
    setState(() {
      _editingCategory = null;
      _desktopNameCtrl.clear();
      _desktopDescCtrl.clear();
    });
  }

  Future<void> _saveDesktopCategory() async {
    final name = _desktopNameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El nombre de la categoría es obligatorio.',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _isSavingDesktop = true);
    final cubit = context.read<CategoriesCubit>();

    try {
      await cubit.saveCategory(
        existingCategory: _editingCategory,
        name: name,
        description: _desktopDescCtrl.text.trim(),
        isActive: _editingCategory?.isActive ?? true,
      );

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              _editingCategory == null
                  ? 'Categoría creada correctamente.'
                  : 'Categoría actualizada correctamente.',
          type: SnackbarType.success,
        );
        _clearDesktopForm();
      }
    } finally {
      if (mounted) setState(() => _isSavingDesktop = false);
    }
  }

  Future<void> _handleToggleStatus(
    CategoryEntity cat,
    bool val,
    CategoriesCubit cubit,
  ) async {
    if (!val) {
      final confirm = await AppConfirmDialog.show(
        context,
        title: 'Desactivar Categoría',
        message:
            '¿Estás seguro de desactivar la categoría "${cat.name}"? Los productos asociados podrían dejar de ser visibles para los clientes.',
        confirmText: 'Desactivar',
        confirmColor: AppColors.error,
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    cubit.toggleStatus(cat, val);
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Categorías',
      showBackButton: true,
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          final cubit = context.read<CategoriesCubit>();
          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
                return _buildDesktopLayout(context, state, cubit);
              }
              return _buildMobileLayout(context, state, cubit);
            },
          );
        },
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showCategoryForm(),
            backgroundColor: AppColors.primary,
            tooltip: 'Crear nueva categoría',
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: ValueListenableBuilder<bool>(
              valueListenable: _isFabExtended,
              builder: (context, isExtended, _) {
                return AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child:
                      isExtended
                          ? const Text(
                            'Nueva',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : const SizedBox.shrink(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    CategoriesState state,
    CategoriesCubit cubit,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Formulario ERP Embebido (40%)
              Expanded(
                flex: 40,
                child: _buildDesktopFormCard(),
              ),
              const SizedBox(width: 24),
              // Columna Derecha: Consola de Categorías (60%)
              Expanded(
                flex: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnimatedSearchBar(
                      controller: _searchCtrl,
                      onChanged: cubit.onSearchChanged,
                      onClear: () {
                        _searchCtrl.clear();
                        cubit.clearSearch();
                      },
                      hasQuery: state.searchQuery.isNotEmpty,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${cubit.state.categories.length} categorías',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => cubit.loadCategories(forceRefresh: true),
                        color: AppColors.primary,
                        child:
                            state.viewState == ViewState.loading
                                ? const CategoriesSkeleton(itemCount: 6)
                                : cubit.state.categories.isEmpty
                                ? _buildEmptyState(cubit, state)
                                : _buildCategoriesGrid(cubit, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFormCard() {
    final isEditing = _editingCategory != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Modifica la información de la categoría.'
                          : 'Crea una nueva categoría para organizar productos.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _desktopNameCtrl,
            label: 'Nombre de la Categoría',
            icon: Icons.label_outlined,
            hintText: 'Ej: Agroquímicos, Fertilizantes, Semillas...',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _desktopDescCtrl,
            label: 'Descripción (Opcional)',
            icon: Icons.notes_rounded,
            hintText: 'Ej: Productos de protección y nutrición vegetal...',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (isEditing)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSavingDesktop ? null : _clearDesktopForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              if (isEditing) const SizedBox(width: 12),
              Expanded(
                flex: isEditing ? 1 : 2,
                child: AppPrimaryButton(
                  label: isEditing ? 'Guardar Cambios' : 'Crear Categoría',
                  loading: _isSavingDesktop,
                  onPressed: _isSavingDesktop ? null : _saveDesktopCategory,
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    CategoriesState state,
    CategoriesCubit cubit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _AnimatedSearchBar(
            controller: _searchCtrl,
            onChanged: cubit.onSearchChanged,
            onClear: () {
              _searchCtrl.clear();
              cubit.clearSearch();
            },
            hasQuery: state.searchQuery.isNotEmpty,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            'Total: ${cubit.state.categories.length} categorías',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.loadCategories(forceRefresh: true),
            color: AppColors.primary,
            child:
                state.viewState == ViewState.loading
                    ? const CategoriesSkeleton(itemCount: 6)
                    : cubit.state.categories.isEmpty
                    ? _buildEmptyState(cubit, state)
                    : _buildCategoriesGrid(cubit, state),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(CategoriesCubit cubit, CategoriesState state) {
    return ListView(
      controller: _scrollController,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.category_outlined,
                  size: 64,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                cubit.state.searchQuery.isNotEmpty
                    ? 'No se encontraron resultados'
                    : 'Aún no tienes categorías',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cubit.state.searchQuery.isNotEmpty
                    ? 'Intenta con otro término de búsqueda'
                    : 'Organiza tus productos creando la primera categoría.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (cubit.state.searchQuery.isEmpty)
                ElevatedButton.icon(
                  onPressed: () => _showCategoryForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear categoría'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(CategoriesCubit cubit, CategoriesState state) {
    final crossAxisCount = MediaQuery.of(context).size.width >= 600 ? 2 : 1;

    return GridView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: cubit.state.categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 88,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final cat = cubit.state.categories[index];
        final catColor = _getCategoryColor(cat.name);

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow(opacity: 0.03),
            ),
            child: Row(
              children: [
                // Area de Info (Izquierda)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.style_rounded, color: catColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cat.description?.isNotEmpty == true
                                    ? cat.description!
                                    : 'Sin descripción',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (cat.productsCount != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${cat.productsCount} productos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Area de Acciones (Derecha)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Editar categoría',
                        onPressed: () => _showCategoryForm(cat),
                      ),
                      Semantics(
                        label: 'Estado de la categoría ${cat.name}',
                        child: Switch(
                          value: cat.isActive,
                          onChanged:
                              (val) => _handleToggleStatus(cat, val, cubit),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(
                            alpha: 0.4,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
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

class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  const _AnimatedSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _isFocused ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused ? AppColors.primary : AppColors.border,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow:
            _isFocused ? AppColors.cardShadow(opacity: 0.1) : null,
      ),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar categoría por nombre...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _isFocused ? AppColors.primary : AppColors.textMuted,
            ),
            suffixIcon:
                widget.hasQuery
                    ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: widget.onClear,
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}
