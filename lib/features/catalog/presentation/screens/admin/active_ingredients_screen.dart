import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/dialogs/adaptive_destructive_dialog.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredient_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredient_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredients_command_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredients_empty_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/active_ingredients_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/active_ingredients/slide_over_ingredient_drawer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

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
      // Si el cubit ya tiene datos en caché, no produce shimmer (Zero-Shimmer)
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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 650;

    if (isMobile) {
      final cubit = context.read<IngredientsCubit>();
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
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
      SlideOverIngredientDrawer.show(
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
    final formattedName = formatIngredientName(ingredient.name);
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
    final cubit = context.read<IngredientsCubit>();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _showIngredientForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          _showIngredientForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
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
          actions: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: () => cubit.loadIngredients(forceRefresh: true),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: () => cubit.loadIngredients(forceRefresh: true),
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
          body: BlocListener<IngredientsCubit, IngredientsState>(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width >= 1050;
                final isTablet = width >= 650 && width < 1050;
                final isMobileLayout = width < 650;
                final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Command Bar Superior Aislada de Rebuilds
                    if (isMobileLayout)
                      _buildMobileCommandBar(context, cubit)
                    else
                      _buildDesktopCommandBar(context, cubit),

                    // Lienzo de Contenido (Skeleton / Grid / Empty)
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh:
                            () => cubit.loadIngredients(forceRefresh: true),
                        color: AppColors.teal,
                        child: BlocSelector<
                          IngredientsCubit,
                          IngredientsState,
                          ({
                            ViewState viewState,
                            List<ActiveIngredientEntity> items,
                            String query,
                          })
                        >(
                          selector:
                              (state) => (
                                viewState: state.viewState,
                                items: state.ingredients,
                                query: state.searchQuery,
                              ),
                          builder: (context, data) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _buildBodyContent(
                                data.viewState,
                                data.items,
                                data.query,
                                cubit,
                                crossAxisCount,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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

  Widget _buildDesktopCommandBar(BuildContext context, IngredientsCubit cubit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: isDark ? [] : AppColors.cardShadow(opacity: 0.03),
      ),
      child: Row(
        children: [
          Expanded(
            child: BlocSelector<IngredientsCubit, IngredientsState, bool>(
              selector: (s) => s.searchQuery.isNotEmpty,
              builder: (context, hasQuery) {
                return ActiveIngredientsSearchBar(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  hasQuery: hasQuery,
                  onChanged: cubit.onSearchChanged,
                  onClear: () {
                    _searchCtrl.clear();
                    cubit.clearSearch();
                  },
                  showShortcut: true,
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          BlocSelector<IngredientsCubit, IngredientsState, int>(
            selector: (s) => s.ingredients.length,
            builder: (context, count) {
              return ActiveIngredientsCounterBadge(count: count);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCommandBar(BuildContext context, IngredientsCubit cubit) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocSelector<IngredientsCubit, IngredientsState, bool>(
            selector: (s) => s.searchQuery.isNotEmpty,
            builder: (context, hasQuery) {
              return ActiveIngredientsSearchBar(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                hasQuery: hasQuery,
                onChanged: cubit.onSearchChanged,
                onClear: () {
                  _searchCtrl.clear();
                  cubit.clearSearch();
                },
                showShortcut: false,
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BlocSelector<IngredientsCubit, IngredientsState, int>(
                selector: (s) => s.ingredients.length,
                builder: (context, count) {
                  return ActiveIngredientsCounterBadge(count: count);
                },
              ),
              BlocSelector<IngredientsCubit, IngredientsState, bool>(
                selector: (s) => s.searchQuery.isNotEmpty,
                builder: (context, hasQuery) {
                  if (!hasQuery) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      cubit.clearSearch();
                    },
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text(
                      'Limpiar',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.tealDark,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    ViewState viewState,
    List<ActiveIngredientEntity> items,
    String searchQuery,
    IngredientsCubit cubit,
    int crossAxisCount,
  ) {
    // Zero-Shimmer: Solo mostrar Skeleton si realmente está cargando y NO hay elementos en caché.
    final showSkeleton =
        (viewState == ViewState.loading || viewState == ViewState.initial) &&
        items.isEmpty;

    if (showSkeleton) {
      return ActiveIngredientsSkeleton(
        key: const ValueKey('skeleton'),
        itemCount: crossAxisCount > 1 ? crossAxisCount * 3 : 8,
        crossAxisCount: crossAxisCount,
      );
    }

    if (items.isEmpty) {
      return ActiveIngredientsEmptyState(
        key: const ValueKey('empty_state'),
        searchQuery: searchQuery,
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
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 12,
          mainAxisExtent: 86,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return ActiveIngredientCard(
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
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ActiveIngredientCard(
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
