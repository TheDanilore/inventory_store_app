import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_card.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_command_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_value_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attributes_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla principal de Gestión y Configuración de Atributos de Variantes.
/// Arquitectura de alto rendimiento: SWR, Zero-Shimmer en Frame 0 y aislamiento con RepaintBoundary.
class AttributesManagementScreen extends StatefulWidget {
  const AttributesManagementScreen({super.key});

  @override
  State<AttributesManagementScreen> createState() =>
      _AttributesManagementScreenState();
}

class _AttributesManagementScreenState
    extends State<AttributesManagementScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  // Search & Filter State
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  AttributeFilter _activeFilter = AttributeFilter.all;

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
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openForm([AttributeEntity? attribute]) {
    AttributeFormSheet.showAdaptive(context, attribute: attribute);
  }

  void _showAddValueDialog(String attributeId, String attributeName) {
    showDialog(
      context: context,
      builder:
          (context) => AttributeValueDialog(
            attributeId: attributeId,
            attributeName: attributeName,
          ),
    );
  }

  // --- FILTRADO DE ATRIBUTOS ---
  List<AttributeEntity> _getFilteredAttributes(
    List<AttributeEntity> attributes,
  ) {
    var list = attributes;

    if (_activeFilter == AttributeFilter.withValues) {
      list = list.where((a) => a.values.isNotEmpty).toList();
    } else if (_activeFilter == AttributeFilter.withoutValues) {
      list = list.where((a) => a.values.isEmpty).toList();
    }

    if (_searchQuery.isEmpty) return list;

    final q = _searchQuery.toLowerCase();
    return list.where((attr) {
      final matchName = attr.name.toLowerCase().contains(q);
      final matchDesc = attr.description?.toLowerCase().contains(q) ?? false;
      final matchValue = attr.values.any(
        (v) => v.value.toLowerCase().contains(q),
      );
      return matchName || matchDesc || matchValue;
    }).toList();
  }

  Future<void> _handleDeleteAttribute(
    AttributeEntity attr,
    AttributesCubit cubit,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar Propiedad',
      message:
          '¿Estás seguro de eliminar la propiedad "${attr.name}"? Se eliminarán también todos sus valores asociados.',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );

    if (confirmed == true && mounted) {
      final success = await cubit.deleteAttribute(attr.id);
      if (mounted && success) {
        AppSnackbar.show(
          context,
          message: 'Propiedad "${attr.name}" eliminada',
          type: SnackbarType.success,
        );
      }
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
        const SingleActivator(LogicalKeyboardKey.keyK, alt: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _openForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          _openForm();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true): () {
          _openForm();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          } else if (_searchQuery.isNotEmpty) {
            _searchCtrl.clear();
            setState(() => _searchQuery = '');
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AdminLayout(
          title: 'Atributos de Variantes',
          actions: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed:
                    () => context.read<AttributesCubit>().loadAttributes(
                      forceRefresh: true,
                    ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed:
                    () => context.read<AttributesCubit>().loadAttributes(
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
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Nueva Propiedad',
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
                    onPressed: () => _openForm(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    tooltip: 'Nueva Propiedad',
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
          body: BlocListener<AttributesCubit, AttributesState>(
            listenWhen:
                (previous, current) =>
                    current.errorMessage != null &&
                    current.errorMessage != previous.errorMessage,
            listener: (context, state) {
              if (state.errorMessage != null) {
                AppSnackbar.show(
                  context,
                  message: state.errorMessage!,
                  type: SnackbarType.error,
                );
              }
            },
            child: BlocBuilder<AttributesCubit, AttributesState>(
              builder: (context, state) {
                final cubit = context.read<AttributesCubit>();
                final filteredAttributes = _getFilteredAttributes(
                  state.attributes,
                );
                final totalValues = state.attributes.fold<int>(
                  0,
                  (sum, a) => sum + a.values.length,
                );

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: isMobile ? 14 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Command Bar (Search + Filter Chips + Counters)
                          RepaintBoundary(
                            child: AttributeCommandBar(
                              searchController: _searchCtrl,
                              searchFocusNode: _searchFocusNode,
                              searchQuery: _searchQuery,
                              activeFilter: _activeFilter,
                              onSearchChanged:
                                  (val) => setState(
                                    () => _searchQuery = val.trim(),
                                  ),
                              onClearSearch: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                              onFilterChanged:
                                  (filter) =>
                                      setState(() => _activeFilter = filter),
                              totalAttributes: state.attributes.length,
                              totalValues: totalValues,
                              isMobile: isMobile,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Attributes List
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh:
                                  () => cubit.loadAttributes(
                                    forceRefresh: true,
                                  ),
                              color: AppColors.primary,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _buildAttributeListContent(
                                  state,
                                  cubit,
                                  filteredAttributes,
                                  isMobile: isMobile,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- CONTENIDO DE LA LISTA DE ATRIBUTOS ---
  Widget _buildAttributeListContent(
    AttributesState state,
    AttributesCubit cubit,
    List<AttributeEntity> filteredAttributes, {
    required bool isMobile,
  }) {
    // ZERO-SHIMMER: Solo mostramos esqueleto si no hay atributos en memoria
    if (state.attributes.isEmpty &&
        (state.viewState == ViewState.loading ||
            state.viewState == ViewState.initial)) {
      return const AttributesSkeleton(key: ValueKey('skeleton'), itemCount: 4);
    }

    if (state.errorMessage != null && state.attributes.isEmpty) {
      return Center(
        child: CatalogErrorState(
          message: state.errorMessage!,
          onRetry: () => cubit.loadAttributes(forceRefresh: true),
        ),
      );
    }

    if (state.attributes.isEmpty) {
      return ListView(
        controller: _scrollController,
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.category_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay propiedades registradas',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Comienza creando tu primera propiedad (Talla, Color, etc.)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Crear Primera Propiedad'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (filteredAttributes.isEmpty &&
        (_searchQuery.isNotEmpty || _activeFilter != AttributeFilter.all)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron coincidencias para "$_searchQuery"'
                  : 'No hay propiedades con el filtro seleccionado',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery = '';
                  _activeFilter = AttributeFilter.all;
                });
              },
              child: const Text('Restablecer filtros'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: filteredAttributes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final attr = filteredAttributes[index];

        return RepaintBoundary(
          child: AttributeCard(
            attribute: attr,
            searchQuery: _searchQuery,
            onEdit: () => _openForm(attr),
            onDelete: () => _handleDeleteAttribute(attr, cubit),
            onOpenAddDialog: () => _showAddValueDialog(attr.id, attr.name),
          ),
        );
      },
    );
  }
}
