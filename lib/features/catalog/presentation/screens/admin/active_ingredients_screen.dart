import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients_state.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredients_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredient_form_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class ActiveIngredientsScreen extends StatefulWidget {
  const ActiveIngredientsScreen({super.key});

  @override
  State<ActiveIngredientsScreen> createState() =>
      _ActiveIngredientsScreenState();
}

class _ActiveIngredientsScreenState extends State<ActiveIngredientsScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);
  final _searchCtrl = TextEditingController();

  // Desktop Form State
  final _desktopNameCtrl = TextEditingController();
  final _desktopDescCtrl = TextEditingController();
  String? _editingIngredientId;

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
      if (!mounted) return;
      final cubit = context.read<IngredientsCubit>();
      cubit.loadIngredients();
      final query = cubit.state.searchQuery;
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

  void _showIngredientForm([String? id, String? name]) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      setState(() {
        _editingIngredientId = id;
        _desktopNameCtrl.text = name ?? '';
        _desktopDescCtrl.text = '';
      });
      return;
    }

    final cubit = context.read<IngredientsCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => BlocProvider.value(
            value: cubit,
            child: ActiveIngredientFormSheet(
              ingredientId: id,
              ingredientName: name,
            ),
          ),
    );
  }

  void _clearDesktopForm() {
    setState(() {
      _editingIngredientId = null;
      _desktopNameCtrl.clear();
      _desktopDescCtrl.clear();
    });
  }

  Future<void> _saveDesktopIngredient() async {
    final name = _desktopNameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El nombre del componente es obligatorio.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<IngredientsCubit>();
    final success = await cubit.saveIngredient(
      name,
      id: _editingIngredientId,
    );

    if (success && mounted) {
      AppSnackbar.show(
        context,
        message:
            _editingIngredientId == null
                ? 'Componente creado correctamente.'
                : 'Componente actualizado correctamente.',
        type: SnackbarType.success,
      );
      _clearDesktopForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Componentes Químicos',
      showBackButton: true,
      body: BlocBuilder<IngredientsCubit, IngredientsState>(
        builder: (context, state) {
          final cubit = context.read<IngredientsCubit>();
          final isSaving = state.isSaving;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
                return _buildDesktopLayout(context, state, cubit, isSaving);
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
            backgroundColor: AppColors.primary,
            onPressed: () => _showIngredientForm(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: ValueListenableBuilder<bool>(
              valueListenable: _isFabExtended,
              builder: (context, isExtended, _) {
                return AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child:
                      isExtended
                          ? const Text(
                            'Nuevo',
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
    IngredientsState state,
    IngredientsCubit cubit,
    bool isSaving,
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
                child: _buildDesktopFormCard(isSaving),
              ),
              const SizedBox(width: 24),
              // Columna Derecha: Lista de Componentes Químicos (60%)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total: ${state.ingredients.length} componentes',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (state.searchQuery.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              _searchCtrl.clear();
                              cubit.clearSearch();
                            },
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Limpiar búsqueda'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => cubit.loadIngredients(),
                        color: AppColors.primary,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildListContent(state, cubit),
                        ),
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

  Widget _buildDesktopFormCard(bool isSaving) {
    final isEditing = _editingIngredientId != null;

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
                  Icons.science_rounded,
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
                      isEditing ? 'Editar Componente' : 'Nuevo Componente',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Modifica la información del componente activo.'
                          : 'Ingresa los datos para registrar un componente químico.',
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
            label: 'Nombre del Componente',
            icon: Icons.label_outlined,
            hintText: 'Ej: Paracetamol, Amoxicilina...',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _desktopDescCtrl,
            label: 'Descripción (Opcional)',
            icon: Icons.notes_rounded,
            hintText: 'Ej: Analgésico y antipirético de uso común...',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (isEditing)
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : _clearDesktopForm,
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
                  label: isEditing ? 'Guardar Cambios' : 'Crear Componente',
                  loading: isSaving,
                  onPressed: isSaving ? null : _saveDesktopIngredient,
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
    IngredientsState state,
    IngredientsCubit cubit,
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
            'Total: ${state.ingredients.length} componentes',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.loadIngredients(),
            color: AppColors.primary,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildListContent(state, cubit),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(IngredientsState state, IngredientsCubit cubit) {
    if (state.viewState == ViewState.loading ||
        state.viewState == ViewState.initial) {
      return const ActiveIngredientsSkeleton(
        key: ValueKey('skeleton'),
        itemCount: 8,
      );
    }
    if (state.ingredients.isEmpty) {
      return ListView(
        controller: _scrollController,
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 60,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  state.searchQuery.isNotEmpty
                      ? 'No se encontraron componentes'
                      : 'No hay componentes registrados',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.ingredients.length,
      itemBuilder: (context, index) {
        final item = state.ingredients[index];
        return _IngredientCard(
          ingredient: item,
          onEdit: () => _showIngredientForm(item.id, item.name),
          onDelete: () => _confirmDeleteIngredient(context, cubit, item),
        );
      },
    );
  }

  Future<void> _confirmDeleteIngredient(
    BuildContext context,
    IngredientsCubit cubit,
    ActiveIngredientEntity ingredient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
          ),
          title: const Text(
            'Eliminar Componente',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            '¿Estás seguro de eliminar el componente "${ingredient.name}"? Esta acción no se puede deshacer.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await cubit.deleteIngredient(ingredient.id);
    }
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
            hintText: 'Buscar componente químico...',
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

class _IngredientCard extends StatefulWidget {
  final ActiveIngredientEntity ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IngredientCard({
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<_IngredientCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onHighlightChanged: (val) => setState(() => _isPressed = val),
        onHover: (hover) => setState(() => _isHovered = hover),
        onTap: widget.onEdit,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                if (_isHovered)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ingredient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.ingredient.description != null &&
                          widget.ingredient.description!.isNotEmpty)
                        Text(
                          widget.ingredient.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.info),
                      onPressed: widget.onEdit,
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      onPressed: widget.onDelete,
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
