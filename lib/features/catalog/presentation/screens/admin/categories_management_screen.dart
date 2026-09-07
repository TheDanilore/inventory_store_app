import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_state.dart';
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

// ── Intents para atajos de teclado estilo Pro Tool ───────────────────────────
class _NewCategoryIntent extends Intent {
  const _NewCategoryIntent();
}

class _SearchFocusIntent extends Intent {
  const _SearchFocusIntent();
}

class _NextCategoryIntent extends Intent {
  const _NextCategoryIntent();
}

class _PrevCategoryIntent extends Intent {
  const _PrevCategoryIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

// ─────────────────────────────────────────────────────────────────────────────

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  // ── Search ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();

  // ── Paleta de colores por categoría ─────────────────────────────────────
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

  // ── Scroll / FAB ─────────────────────────────────────────────────────────
  final _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  // ── Desktop Form State ───────────────────────────────────────────────────
  final _desktopNameCtrl = TextEditingController();
  final _desktopDescCtrl = TextEditingController();
  final _desktopNameFocusNode = FocusNode();
  CategoryEntity? _editingCategory;
  bool _isSavingDesktop = false;
  bool _isSplitViewActive = false;

  /// Color de acento del formulario, reacciona al nombre en tiempo real.
  Color _previewColor = const Color(0xFF6366F1);

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

    // Live color preview mientras escribe el nombre
    _desktopNameCtrl.addListener(() {
      final newColor = _getCategoryColor(_desktopNameCtrl.text.trim());
      if (newColor != _previewColor) {
        setState(() => _previewColor = newColor);
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
    _desktopNameCtrl.dispose();
    _desktopDescCtrl.dispose();
    _desktopNameFocusNode.dispose();
    super.dispose();
  }

  // ── Acciones ─────────────────────────────────────────────────────────────

  void _showCategoryForm([CategoryEntity? category]) {
    // Si el panel de Split View está activo y visible en pantalla
    if (_isSplitViewActive) {
      setState(() {
        _editingCategory = category;
        _desktopNameCtrl.text = category?.name ?? '';
        _desktopDescCtrl.text = category?.description ?? '';
        _previewColor = _getCategoryColor(category?.name ?? '');
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _desktopNameFocusNode.requestFocus();
      });
      return;
    }

    // Si NO está activo el Split View (Tablet, móvil o Desktop con sidebar expandido)
    final cubit = context.read<CategoriesCubit>();
    final isTabletOrDesktop = MediaQuery.sizeOf(context).width >= 600;

    if (isTabletOrDesktop) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BlocProvider.value(
                value: cubit,
                child: CategoryFormSheet(category: category),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => BlocProvider.value(
          value: cubit,
          child: CategoryFormSheet(category: category),
        ),
      );
    }
  }

  void _handleNextCategory() {
    if (_searchFocusNode.hasFocus || _desktopNameFocusNode.hasFocus) return;
    final categories = context.read<CategoriesCubit>().state.categories;
    if (categories.isEmpty) return;
    final currentIndex = _editingCategory == null
        ? -1
        : categories.indexWhere((c) => c.id == _editingCategory!.id);
    final nextIndex = (currentIndex + 1).clamp(0, categories.length - 1);
    _showCategoryForm(categories[nextIndex]);
  }

  void _handlePrevCategory() {
    if (_searchFocusNode.hasFocus || _desktopNameFocusNode.hasFocus) return;
    final categories = context.read<CategoriesCubit>().state.categories;
    if (categories.isEmpty) return;
    final currentIndex = _editingCategory == null
        ? categories.length
        : categories.indexWhere((c) => c.id == _editingCategory!.id);
    final prevIndex = (currentIndex - 1).clamp(0, categories.length - 1);
    _showCategoryForm(categories[prevIndex]);
  }

  void _clearDesktopForm() {
    setState(() {
      _editingCategory = null;
      _desktopNameCtrl.clear();
      _desktopDescCtrl.clear();
      _previewColor = _categoryColors[0];
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
      _desktopNameFocusNode.requestFocus();
      return;
    }

    setState(() => _isSavingDesktop = true);
    final cubit = context.read<CategoriesCubit>();

    try {
      final success = await cubit.saveCategory(
        existingCategory: _editingCategory,
        name: name,
        description: _desktopDescCtrl.text.trim(),
        isActive: _editingCategory?.isActive ?? true,
      );

      if (mounted) {
        if (success) {
          AppSnackbar.show(
            context,
            message: _editingCategory == null
                ? 'Categoría creada correctamente.'
                : 'Categoría actualizada correctamente.',
            type: SnackbarType.success,
          );
          _clearDesktopForm();
        }
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
    HapticFeedback.lightImpact();
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

  Future<void> _confirmDeleteCategory(
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
    if (confirm != true) return;
    if (!mounted) return;
    final success = await cubit.deleteCategory(cat.id!);
    if (success && mounted) {
      if (_editingCategory?.id == cat.id) _clearDesktopForm();
      AppSnackbar.show(
        context,
        message: 'Categoría eliminada exitosamente.',
        type: SnackbarType.success,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const _NewCategoryIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const _NewCategoryIntent(),
        const SingleActivator(LogicalKeyboardKey.slash):
            const _SearchFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const _SearchFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const _SearchFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _NextCategoryIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _PrevCategoryIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewCategoryIntent: CallbackAction<_NewCategoryIntent>(
            onInvoke: (_) {
              _showCategoryForm();
              return null;
            },
          ),
          _SearchFocusIntent: CallbackAction<_SearchFocusIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          _NextCategoryIntent: CallbackAction<_NextCategoryIntent>(
            onInvoke: (_) {
              _handleNextCategory();
              return null;
            },
          ),
          _PrevCategoryIntent: CallbackAction<_PrevCategoryIntent>(
            onInvoke: (_) {
              _handlePrevCategory();
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              if (_searchFocusNode.hasFocus) {
                _searchFocusNode.unfocus();
              } else if (_editingCategory != null ||
                  _desktopNameCtrl.text.isNotEmpty) {
                _clearDesktopForm();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: AdminLayout(
            title: 'Categorías',
            showBackButton: true,
            actions: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                  onPressed: () => context
                      .read<CategoriesCubit>()
                      .loadCategories(forceRefresh: true),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: () => context
                      .read<CategoriesCubit>()
                      .loadCategories(forceRefresh: true),
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
                  onPressed: _showCategoryForm,
                  icon: Icon(
                    _editingCategory != null
                        ? Icons.edit_note_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _editingCategory != null
                        ? 'Editando...'
                        : 'Nueva Categoría',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _editingCategory != null
                        ? _previewColor
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
            floatingActionButton: isMobile
                ? FloatingActionButton.extended(
                    onPressed: () => _showCategoryForm(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    tooltip: 'Crear nueva categoría',
                    icon: const Icon(Icons.add_rounded),
                    label: ValueListenableBuilder<bool>(
                      valueListenable: _isFabExtended,
                      builder: (context, extended, _) => AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: extended
                            ? const Text(
                                'Nueva',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  )
                : null,
            body: BlocConsumer<CategoriesCubit, CategoriesState>(
              listenWhen: (prev, curr) =>
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
              builder: (context, state) {
                final cubit = context.read<CategoriesCubit>();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktopLayout = constraints.maxWidth >= 960;
                    _isSplitViewActive = isDesktopLayout;
                    return isDesktopLayout
                        ? _buildDesktopLayout(context, state, cubit)
                        : _buildMobileLayout(context, state, cubit);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Desktop Layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    BuildContext context,
    CategoriesState state,
    CategoriesCubit cubit,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 38, child: _buildDesktopFormCard()),
              const SizedBox(width: 24),
              Expanded(
                flex: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AnimatedSearchBar(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: cubit.onSearchChanged,
                      onClear: () {
                        _searchCtrl.clear();
                        cubit.clearSearch();
                      },
                      hasQuery: state.searchQuery.isNotEmpty,
                    ),
                    const SizedBox(height: 10),
                    _buildStatsBar(cubit),
                    const SizedBox(height: 10),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () =>
                            cubit.loadCategories(forceRefresh: true),
                        color: AppColors.primary,
                        child: state.viewState == ViewState.loading
                            ? const CategoriesSkeleton(itemCount: 6)
                            : cubit.state.categories.isEmpty
                                ? _buildEmptyState(cubit, state)
                                : _buildDesktopList(cubit),
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

  Widget _buildStatsBar(CategoriesCubit cubit) {
    final categories = cubit.state.categories;
    final total = categories.length;
    final active = categories.where((c) => c.isActive).length;
    final inactive = total - active;

    return Row(
      children: [
        Text(
          '$total ${total == 1 ? 'categoría' : 'categorías'}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (total > 0) ...[
          const SizedBox(width: 10),
          _StatPill(label: '$active activas', color: AppColors.teal),
          if (inactive > 0) ...[
            const SizedBox(width: 6),
            _StatPill(label: '$inactive inactivas', color: AppColors.textMuted),
          ],
        ],
      ],
    );
  }

  // ── Desktop Form Card ─────────────────────────────────────────────────────

  Widget _buildDesktopFormCard() {
    final isEditing = _editingCategory != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing
              ? _previewColor.withValues(alpha: 0.35)
              : AppColors.border,
          width: isEditing ? 1.5 : 1.0,
        ),
        boxShadow: isEditing
            ? [
                BoxShadow(
                  color: _previewColor.withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppColors.cardShadow(opacity: 0.04),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Accent Header ───────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: _previewColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(
                  color: _previewColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                // Swatch animado – preview del ícono de la categoría
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _previewColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _previewColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.style_rounded,
                    color: _previewColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                          key: ValueKey(isEditing),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                            color: isEditing
                                ? _previewColor
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isEditing
                              ? 'Modificando "${_editingCategory!.name}"'
                              : 'Organiza tu catálogo con categorías claras.',
                          key: ValueKey(
                              isEditing ? _editingCategory!.id : 'new'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEditing)
                  Tooltip(
                    message: 'Escape para cancelar',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Esc',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Campos del formulario ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                AppTextField(
                  controller: _desktopNameCtrl,
                  focusNode: _desktopNameFocusNode,
                  label: 'Nombre de la Categoría',
                  icon: Icons.label_outlined,
                  hintText: 'Ej: Agroquímicos, Fertilizantes, Semillas...',
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      _isSavingDesktop ? null : _saveDesktopCategory(),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _desktopDescCtrl,
                  label: 'Descripción (Opcional)',
                  icon: Icons.notes_rounded,
                  hintText:
                      'Ej: Productos de protección y nutrición vegetal...',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEditing) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _isSavingDesktop ? null : _clearDesktopForm,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: isEditing ? 1 : 2,
                      child: AppPrimaryButton(
                        label: isEditing
                            ? 'Guardar Cambios'
                            : 'Crear Categoría',
                        loading: _isSavingDesktop,
                        onPressed:
                            _isSavingDesktop ? null : _saveDesktopCategory,
                        backgroundColor:
                            isEditing ? _previewColor : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _KbdBadge(label: 'Enter'),
                    const SizedBox(width: 5),
                    const Text(
                      'guardar',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile Layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    CategoriesState state,
    CategoriesCubit cubit,
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
              _AnimatedSearchBar(
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
              _buildStatsBar(cubit),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.loadCategories(forceRefresh: true),
            color: AppColors.primary,
            child: state.viewState == ViewState.loading
                ? const CategoriesSkeleton(itemCount: 6)
                : cubit.state.categories.isEmpty
                    ? _buildEmptyState(cubit, state)
                    : _buildMobileList(cubit, state),
          ),
        ),
      ],
    );
  }

  // ── Desktop List ──────────────────────────────────────────────────────────

  Widget _buildDesktopList(CategoriesCubit cubit) {
    final categories = cubit.state.categories;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = _editingCategory?.id == cat.id;
        final catColor = _getCategoryColor(cat.name);

        return TweenAnimationBuilder<double>(
          key: ValueKey(cat.id),
          duration:
              Duration(milliseconds: 220 + (index * 35).clamp(0, 380)),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (_, value, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: _CategoryDesktopRow(
            category: cat,
            catColor: catColor,
            isSelected: isSelected,
            onEdit: () => _showCategoryForm(cat),
            onDelete: () => _confirmDeleteCategory(cat, cubit),
            onToggle: (val) => _handleToggleStatus(cat, val, cubit),
          ),
        );
      },
    );
  }

  // ── Mobile List ───────────────────────────────────────────────────────────

  Widget _buildMobileList(CategoriesCubit cubit, CategoriesState state) {
    final categories = cubit.state.categories;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final catColor = _getCategoryColor(cat.name);

        return TweenAnimationBuilder<double>(
          key: ValueKey(cat.id),
          duration:
              Duration(milliseconds: 220 + (index * 35).clamp(0, 380)),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (_, value, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: Dismissible(
            key: Key(cat.id ?? cat.name),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              return await AppConfirmDialog.show(
                context,
                title: 'Eliminar Categoría',
                message:
                    '¿Eliminar "${cat.name}"?\n'
                    'Se validará que no tenga productos vinculados.',
                confirmText: 'Eliminar',
                confirmColor: AppColors.error,
              );
            },
            onDismissed: (_) => _confirmDeleteCategory(cat, cubit),
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
                  Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 22),
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
            child: _CategoryMobileCard(
              category: cat,
              catColor: catColor,
              onEdit: () => _showCategoryForm(cat),
              onDelete: () => _confirmDeleteCategory(cat, cubit),
              onToggle: (val) => _handleToggleStatus(cat, val, cubit),
            ),
          ),
        );
      },
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(CategoriesCubit cubit, CategoriesState state) {
    final isSearch = cubit.state.searchQuery.isNotEmpty;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearch
                      ? Icons.search_off_rounded
                      : Icons.category_outlined,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSearch
                    ? 'Sin resultados para\n"${cubit.state.searchQuery}"'
                    : 'Aún no hay categorías',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isSearch
                    ? 'Intenta con otro término de búsqueda.'
                    : 'Organiza tus productos creando la primera categoría.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isSearch) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _showCategoryForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Crear categoría'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Row: hover + selected state + acciones Pro Tool
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryDesktopRow extends StatefulWidget {
  final CategoryEntity category;
  final Color catColor;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _CategoryDesktopRow({
    required this.category,
    required this.catColor,
    required this.isSelected,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<_CategoryDesktopRow> createState() => _CategoryDesktopRowState();
}

class _CategoryDesktopRowState extends State<_CategoryDesktopRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final color = widget.catColor;
    final selected = widget.isSelected;
    final hovered = _isHovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 64,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.06)
                : hovered
                    ? AppColors.background
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.35)
                  : AppColors.border,
              width: selected ? 1.5 : 1.0,
            ),
            boxShadow: hovered || selected
                ? AppColors.cardShadow(opacity: 0.04)
                : null,
          ),
          child: Row(
            children: [
              // ── Selected accent bar ─────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: selected ? 4 : 0,
                height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              // ── Color icon ──────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                    left: selected ? 12 : 14, right: 12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.style_rounded, color: color, size: 18),
                ),
              ),

              // ── Nombre + descripción ────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cat.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color:
                            selected ? color : AppColors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.description?.isNotEmpty == true
                          ? cat.description!
                          : 'Sin descripción',
                      style: TextStyle(
                        fontSize: 12,
                        color: cat.description?.isNotEmpty == true
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Productos count badge ───────────────────────────────────
              if (cat.productsCount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${cat.productsCount} prod.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

              // ── Status Badge ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cat.isActive
                        ? AppColors.teal.withValues(alpha: 0.1)
                        : AppColors.textMuted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cat.isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cat.isActive
                          ? AppColors.teal
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),

              // ── Acciones ─────────────────────────────────────────────────
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: hovered || selected ? 1.0 : 0.3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Editar categoría',
                        child: _RowIconBtn(
                          icon: Icons.edit_outlined,
                          color: AppColors.textSecondary,
                          onTap: widget.onEdit,
                        ),
                      ),
                      Tooltip(
                        message: 'Eliminar categoría',
                        child: _RowIconBtn(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                          onTap: widget.onDelete,
                        ),
                      ),
                      Semantics(
                        label: 'Estado de ${cat.name}',
                        child: Switch(
                          value: cat.isActive,
                          onChanged: widget.onToggle,
                          activeThumbColor: AppColors.teal,
                          activeTrackColor:
                              AppColors.teal.withValues(alpha: 0.35),
                          inactiveThumbColor: AppColors.textMuted,
                          inactiveTrackColor: AppColors.border,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Card: Apple HIG, color left bar, táctil
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryMobileCard extends StatelessWidget {
  final CategoryEntity category;
  final Color catColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _CategoryMobileCard({
    required this.category,
    required this.catColor,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final color = catColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: Row(
            children: [
              // Color accent left bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: cat.isActive ? 1 : 0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              // Icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.style_rounded, color: color, size: 22),
                ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: cat.isActive
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                        const SizedBox(height: 3),
                        Text(
                          '${cat.productsCount} productos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RowIconBtn(
                      icon: Icons.edit_outlined,
                      color: AppColors.textSecondary,
                      onTap: onEdit,
                    ),
                    _RowIconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      onTap: onDelete,
                    ),
                    Semantics(
                      label: 'Estado de ${cat.name}',
                      child: Switch(
                        value: cat.isActive,
                        onChanged: onToggle,
                        activeThumbColor: color,
                        activeTrackColor: color.withValues(alpha: 0.35),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared compact icon button
// ─────────────────────────────────────────────────────────────────────────────

class _RowIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RowIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        icon: Icon(icon, color: color, size: 19),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        splashRadius: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Search Bar con focusNode externo
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  const _AnimatedSearchBar({
    required this.controller,
    required this.focusNode,
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
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

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
        boxShadow: _isFocused ? AppColors.cardShadow(opacity: 0.08) : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar categoría…',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _isFocused ? AppColors.primary : AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: widget.hasQuery
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textMuted, size: 18),
                  onPressed: widget.onClear,
                )
              : Tooltip(
                  message: 'Atajo de teclado: /',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        '/',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Pill
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard Badge
// ─────────────────────────────────────────────────────────────────────────────

class _KbdBadge extends StatelessWidget {
  final String label;

  const _KbdBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}


