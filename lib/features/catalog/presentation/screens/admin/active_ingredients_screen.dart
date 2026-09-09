import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/core/widgets/dialogs/adaptive_destructive_dialog.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredient_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredients_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Formatea nombres de ingredientes químicos a Title Case inteligente,
/// preservando siglas técnicas cortas (ej: "PREFONOFOS" -> "Prefonofos", "NPK" -> "NPK").
String _formatIngredientName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(RegExp(r'\s+'));
  return words.map((w) {
    if (w.isEmpty) return '';
    if (w.length == 1) return w.toUpperCase();
    if (w.length <= 3 &&
        w == w.toUpperCase() &&
        !RegExp(r'[0-9]').hasMatch(w)) {
      return w;
    }
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

/// Pantalla Pro Tool & Apple HIG para la gestión de Componentes Químicos (Ingredientes Activos).
///
/// Implementa una personalidad multi-dispositivo camaleónica:
/// - **Desktop (>= 1050px)**: Command Bar superior estilo Linear con atajos `Ctrl+K`, `Ctrl+N`,
///   Grid científico de 3 columnas de alta densidad y Slide-Over Drawer contextual.
/// - **Tablet (650px - 1049px)**: Eficiencia híbrida en Grid de 2 columnas y Slide-Over Drawer.
/// - **Móvil (< 650px)**: Experiencia táctil fluida Apple HIG con tarjetas redondeadas,
///   FAB expandible y Cupertino/Material BottomSheet.
class ActiveIngredientsScreen extends StatefulWidget {
  const ActiveIngredientsScreen({super.key});

  @override
  State<ActiveIngredientsScreen> createState() =>
      _ActiveIngredientsScreenState();
}

class _ActiveIngredientsScreenState extends State<ActiveIngredientsScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showIngredientForm([String? id, String? name]) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 650;

    if (isMobile) {
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
    } else {
      _SlideOverIngredientDrawer.show(
        context: context,
        ingredientId: id,
        ingredientName: name,
      );
    }
  }

  Future<void> _confirmDeleteIngredient(
    BuildContext context,
    IngredientsCubit cubit,
    ActiveIngredientEntity ingredient,
  ) async {
    final formattedName = _formatIngredientName(ingredient.name);
    final confirmed = await AdaptiveDestructiveDialog.show(
      context: context,
      title: 'Eliminar Componente Químico',
      itemName: formattedName,
      description:
          'Esta acción eliminará permanentemente "$formattedName" del catálogo de componentes químicos.\n\nNota de Seguridad: La acción será bloqueada automáticamente por el sistema si este componente está siendo utilizado en las formulaciones de uno o más productos para evitar registros huérfanos.',
      matchText: ingredient.name,
      confirmButtonText: 'Eliminar Componente',
      onConfirmAsync: () async {
        return await cubit.deleteIngredient(ingredient.id);
      },
    );

    if (confirmed == true && context.mounted) {
      AppSnackbar.show(
        context,
        message: 'Componente "$formattedName" eliminado exitosamente.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _showIngredientForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          _showIngredientForm();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
          if (_searchCtrl.text.isNotEmpty) {
            _searchCtrl.clear();
            context.read<IngredientsCubit>().clearSearch();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AdminLayout(
          title: 'Componentes Químicos',
          showBackButton: true,
          actions: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: () =>
                    context.read<IngredientsCubit>().loadIngredients(),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<IngredientsCubit>().loadIngredients(),
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
                onPressed: () => _showIngredientForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Nuevo Componente',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
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
          body: BlocConsumer<IngredientsCubit, IngredientsState>(
            listenWhen: (prev, curr) => curr.errorId != prev.errorId,
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
              final cubit = context.read<IngredientsCubit>();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isDesktop = width >= 1050;
                  final isTablet = width >= 650 && width < 1050;
                  final isMobile = width < 650;
                  final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Command Bar Superior Adaptativa
                      if (isMobile)
                        _buildMobileCommandBar(context, state, cubit)
                      else
                        _buildDesktopCommandBar(
                          context,
                          state,
                          cubit,
                          isDesktop,
                        ),

                      // Lienzo de Contenido (Skeleton / Grid / Empty)
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => cubit.loadIngredients(),
                          color: AppColors.teal,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _buildBodyContent(
                              state,
                              cubit,
                              crossAxisCount,
                              isMobile,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          floatingActionButton: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 650) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _showIngredientForm(),
                icon: const Icon(Icons.add_rounded),
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
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              )
                              : const SizedBox.shrink(),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCommandBar(
    BuildContext context,
    IngredientsState state,
    IngredientsCubit cubit,
    bool isDesktop,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.03),
      ),
      child: Row(
        children: [
          // Campo de búsqueda con badge Ctrl K
          Expanded(
            child: _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              hasQuery: state.searchQuery.isNotEmpty,
              onChanged: cubit.onSearchChanged,
              onClear: () {
                _searchCtrl.clear();
                cubit.clearSearch();
              },
              showShortcut: true,
            ),
          ),
          const SizedBox(width: 14),

          // Píldora de estado con contador
          _IngredientCounterBadge(count: state.ingredients.length),
        ],
      ),
    );
  }

  Widget _buildMobileCommandBar(
    BuildContext context,
    IngredientsState state,
    IngredientsCubit cubit,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchBar(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hasQuery: state.searchQuery.isNotEmpty,
            onChanged: cubit.onSearchChanged,
            onClear: () {
              _searchCtrl.clear();
              cubit.clearSearch();
            },
            showShortcut: false,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _IngredientCounterBadge(count: state.ingredients.length),
              if (state.searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    cubit.clearSearch();
                  },
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tealDark,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    IngredientsState state,
    IngredientsCubit cubit,
    int crossAxisCount,
    bool isMobile,
  ) {
    if (state.viewState == ViewState.loading ||
        state.viewState == ViewState.initial) {
      return ActiveIngredientsSkeleton(
        key: const ValueKey('skeleton'),
        itemCount: crossAxisCount > 1 ? crossAxisCount * 3 : 8,
        crossAxisCount: crossAxisCount,
      );
    }

    if (state.ingredients.isEmpty) {
      return _EmptyState(
        searchQuery: state.searchQuery,
        onCreate: () => _showIngredientForm(),
        onClearSearch: () {
          _searchCtrl.clear();
          cubit.clearSearch();
        },
      );
    }

    if (crossAxisCount > 1) {
      return GridView.builder(
        controller: _scrollController,
        key: const ValueKey('grid_view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: state.ingredients.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 12,
          mainAxisExtent: 86,
        ),
        itemBuilder: (context, index) {
          final item = state.ingredients[index];
          return _IngredientCard(
            key: ValueKey(item.id),
            ingredient: item,
            onEdit: () => _showIngredientForm(item.id, item.name),
            onDelete: () => _confirmDeleteIngredient(context, cubit, item),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      key: const ValueKey('list_view'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: state.ingredients.length,
      itemBuilder: (context, index) {
        final item = state.ingredients[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _IngredientCard(
            key: ValueKey(item.id),
            ingredient: item,
            onEdit: () => _showIngredientForm(item.id, item.name),
            onDelete: () => _confirmDeleteIngredient(context, cubit, item),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES DE INTERFAZ (COMMAND BAR, BADGES, INPUTS)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;
  final bool showShortcut;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
    required this.showShortcut,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 44,
      decoration: BoxDecoration(
        color: _isFocused ? AppColors.surface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? AppColors.teal : AppColors.border,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow:
            _isFocused
                ? [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar componente químico...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: _isFocused ? AppColors.tealDark : AppColors.textMuted,
          ),
          suffixIcon:
              widget.hasQuery
                  ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    splashRadius: 16,
                    onPressed: widget.onClear,
                  )
                  : (widget.showShortcut
                      ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Text(
                                'Ctrl K',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : null),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class _IngredientCounterBadge extends StatelessWidget {
  final int count;

  const _IngredientCounterBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'componente' : 'componentes'}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE COMPONENTE QUÍMICO (SCIENTIFIC PRO CARD)
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientCard extends StatefulWidget {
  final ActiveIngredientEntity ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IngredientCard({
    super.key,
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<_IngredientCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final formattedName = _formatIngredientName(widget.ingredient.name);
    final hasDesc =
        widget.ingredient.description != null &&
        widget.ingredient.description!.trim().isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onEdit,
          onHighlightChanged: (val) => setState(() => _isPressed = val),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedScale(
            scale: _isPressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _isHovered
                          ? AppColors.teal.withValues(alpha: 0.45)
                          : AppColors.border,
                  width: _isHovered ? 1.4 : 1.0,
                ),
                boxShadow:
                    _isHovered
                        ? [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : AppColors.cardShadow(opacity: 0.025),
              ),
              child: Row(
                children: [
                  // Monograma / Avatar Científico
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          _isHovered
                              ? AppColors.tealLight
                              : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _isHovered
                                ? AppColors.teal.withValues(alpha: 0.3)
                                : const Color(0xFFCCFBF1),
                      ),
                    ),
                    child: const Icon(
                      Icons.science_rounded,
                      color: AppColors.tealDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Información del Componente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                formattedName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Text(
                                'Activo',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasDesc
                              ? widget.ingredient.description!
                              : 'Principio activo registrado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                hasDesc
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Acciones Rápidas (Editar / Eliminar)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        color: AppColors.slate,
                        tooltip: 'Editar',
                        onTap: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        tooltip: 'Eliminar',
                        onTap: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHover = true),
        onExit: (_) => setState(() => _isHover = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  _isHover
                      ? widget.color.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 17, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE-OVER DRAWER LATERAL (LINEAR / STRIPE STYLE) PARA DESKTOP & TABLET
// ─────────────────────────────────────────────────────────────────────────────

class _SlideOverIngredientDrawer extends StatefulWidget {
  final String? ingredientId;
  final String? ingredientName;

  const _SlideOverIngredientDrawer({this.ingredientId, this.ingredientName});

  static Future<bool?> show({
    required BuildContext context,
    String? ingredientId,
    String? ingredientName,
  }) {
    final cubit = context.read<IngredientsCubit>();
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar panel',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return BlocProvider.value(
          value: cubit,
          child: Align(
            alignment: Alignment.centerRight,
            child: _SlideOverIngredientDrawer(
              ingredientId: ingredientId,
              ingredientName: ingredientName,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: child,
        );
      },
    );
  }

  @override
  State<_SlideOverIngredientDrawer> createState() =>
      _SlideOverIngredientDrawerState();
}

class _SlideOverIngredientDrawerState
    extends State<_SlideOverIngredientDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.ingredientName ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El nombre del componente es requerido.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<IngredientsCubit>();
    final success = await cubit.saveIngredient(name, id: widget.ingredientId);

    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message:
              widget.ingredientId == null
                  ? 'Componente "$name" creado correctamente.'
                  : 'Componente actualizado correctamente.',
          type: SnackbarType.success,
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop(false);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        _handleSave();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ingredientId != null;
    final isSaving = context.watch<IngredientsCubit>().state.isSaving;
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width < 500 ? width * 0.95 : 440.0;

    return Focus(
      onKeyEvent: _handleKey,
      child: Material(
        color: AppColors.surface,
        elevation: 16,
        child: Container(
          width: panelWidth,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera del Slide-Over
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.science_rounded,
                        color: AppColors.tealDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Editar Componente'
                                : 'Nuevo Componente Químico',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditing
                                ? 'Modifica los datos del principio activo.'
                                : 'Registra un nuevo principio activo para el catálogo.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Cerrar (Esc)',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),

              // Formulario interno
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _nameCtrl,
                          focusNode: _focusNode,
                          label: 'Nombre del Componente *',
                          icon: Icons.label_outlined,
                          hintText: 'Ej: Sulfato de Cobre, Paracetamol...',
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _descCtrl,
                          label: 'Descripción o Notas Técnicas (Opcional)',
                          icon: Icons.notes_rounded,
                          hintText:
                              'Ej: Fungicida cúprico preventivo de amplio espectro...',
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 24),

                        // Callout informativo de buenas prácticas
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCCFBF1)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 18,
                                color: AppColors.tealDark,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Los componentes químicos activos se asignan a las fichas técnicas de productos y permiten filtrados agronómicos o farmacológicos avanzados en el punto de venta.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.tealDark,
                                    height: 1.4,
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
              ),

              // Barra de botones inferior
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            isSaving
                                ? null
                                : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar (Esc)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isSaving
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  isEditing
                                      ? 'Guardar Cambios'
                                      : 'Crear Componente',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VACÍO (EMPTY STATE)
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onCreate;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.searchQuery,
    required this.onCreate,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: const Icon(
                Icons.science_outlined,
                size: 34,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? 'No se encontraron componentes'
                  : 'No hay componentes registrados',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                hasSearch
                    ? 'No existen componentes que coincidan con "$searchQuery". Prueba con otro término.'
                    : 'Registra los principios activos que forman parte de la formulación de tus productos.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (hasSearch)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Limpiar búsqueda'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Registrar Primer Componente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
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
    );
  }
}
