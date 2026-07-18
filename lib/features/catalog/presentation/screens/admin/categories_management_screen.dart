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
    super.dispose();
  }

  void _showCategoryForm([CategoryEntity? category]) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    if (isTablet) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder:
            (context) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 480,
                child: CategoryFormSheet(category: category),
              ),
            ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => CategoryFormSheet(category: category),
      );
    }
  }

  Future<void> _handleToggleStatus(
    CategoryEntity cat,
    bool val,
    CategoriesCubit cubit,
  ) async {
    if (!val) {
      // Si se va a desactivar, pedir confirmación
      final confirm = await AppConfirmDialog.show(
        context,
        title: 'Desactivar Categoría',
        message:
            '¿Estás seguro de desactivar la categoría "${cat.name}"? Los productos asociados podrían dejar de ser visibles para los clientes.',
        confirmText: 'Desactivar',
        confirmColor: Colors.orange.shade700,
      );
      if (confirm != true) return;
    }
    if (!mounted) return;
    cubit.toggleStatus(cat, val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(),
        backgroundColor: AppColors.primary,
        tooltip: 'Crear nueva categoria',
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
      ),
      body: BlocBuilder<CategoriesCubit, CategoriesState>(
        builder: (context, state) {
          final cubit = context.read<CategoriesCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BUSCADOR
              Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  label: 'Buscador de categorías',
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: cubit.onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar categoría por nombre...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                      ),
                      suffixIcon:
                          cubit.state.searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  cubit.clearSearch();
                                },
                              )
                              : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Text(
                  'Total: ${cubit.state.categories.length} categorías',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // LISTA DE CATEGORIAS
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
        },
      ),
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
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cubit.state.searchQuery.isNotEmpty
                    ? 'Intenta con otro término de búsqueda'
                    : 'Organiza tus productos creando la primera categoría.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        80,
      ), // Padding inferior para el FAB
      itemCount: cubit.state.categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 88, // Altura fija
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
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cat.description?.isNotEmpty == true
                                    ? cat.description!
                                    : 'Sin descripción',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
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
                      // Boton Editar explicito
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        tooltip: 'Editar categoría',
                        onPressed: () => _showCategoryForm(cat),
                      ),

                      // Switch de Estado independiente
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
