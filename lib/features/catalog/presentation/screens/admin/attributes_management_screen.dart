import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_value_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attributes_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

// Intents para atajos de teclado Pro Tool (Linear / Stripe style)
class _NewAttributeIntent extends Intent {
  const _NewAttributeIntent();
}

class _SearchFocusIntent extends Intent {
  const _SearchFocusIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

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

  // Desktop Form State
  final _desktopNameCtrl = TextEditingController();
  final _desktopDescCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();

  // Search State
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';

  String? _editingAttributeId;

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
      context.read<AttributesCubit>().loadAttributes();
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    _desktopNameCtrl.dispose();
    _desktopDescCtrl.dispose();
    _nameFocusNode.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showAttributeForm([AttributeEntity? attribute, bool isDesktop = false]) {
    if (isDesktop) {
      setState(() {
        _editingAttributeId = attribute?.id;
        _desktopNameCtrl.text = attribute?.name ?? '';
        _desktopDescCtrl.text = attribute?.description ?? '';
      });
      _nameFocusNode.requestFocus();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttributeFormSheet(attribute: attribute),
    );
  }

  void _clearDesktopForm() {
    setState(() {
      _editingAttributeId = null;
      _desktopNameCtrl.clear();
      _desktopDescCtrl.clear();
    });
  }

  void _handleHeaderNewAttribute(bool isDesktop) {
    if (isDesktop) {
      _clearDesktopForm();
      _nameFocusNode.requestFocus();
    } else {
      _showAttributeForm();
    }
  }

  Future<void> _saveDesktopAttribute() async {
    final name = _desktopNameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El nombre de la propiedad es obligatorio.',
        type: SnackbarType.warning,
      );
      _nameFocusNode.requestFocus();
      return;
    }

    final cubit = context.read<AttributesCubit>();
    final success = await cubit.saveAttribute(
      name,
      id: _editingAttributeId,
      description: _desktopDescCtrl.text.trim(),
    );

    if (success && mounted) {
      AppSnackbar.show(
        context,
        message:
            _editingAttributeId == null
                ? 'Propiedad creada correctamente.'
                : 'Propiedad actualizada correctamente.',
        type: SnackbarType.success,
      );
      _clearDesktopForm();
    }
  }

  void _showAddValueForm(String attributeId, String attributeName) {
    showDialog(
      context: context,
      builder:
          (context) => AttributeValueDialog(
            attributeId: attributeId,
            attributeName: attributeName,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 720;
    final isEditing = _editingAttributeId != null;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const _NewAttributeIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN):
            const _NewAttributeIntent(),
        LogicalKeySet(LogicalKeyboardKey.slash): const _SearchFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewAttributeIntent: CallbackAction<_NewAttributeIntent>(
            onInvoke: (_) {
              _handleHeaderNewAttribute(!isMobile);
              return null;
            },
          ),
          _SearchFocusIntent: CallbackAction<_SearchFocusIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          _EscapeIntent: CallbackAction<_EscapeIntent>(
            onInvoke: (_) {
              if (_searchFocusNode.hasFocus) {
                _searchFocusNode.unfocus();
              } else if (_editingAttributeId != null) {
                _clearDesktopForm();
              }
              return null;
            },
          ),
        },
        child: AdminLayout(
          title: 'Atributos de Variantes',
          showBackButton: true,
          actions: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar',
                onPressed: () => context.read<AttributesCubit>().loadAttributes(),
              )
            else ...[
              OutlinedButton.icon(
                onPressed:
                    () => context.read<AttributesCubit>().loadAttributes(),
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
                onPressed: () => _handleHeaderNewAttribute(!isMobile),
                icon: Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(
                  isEditing ? 'Editando...' : 'Nueva Propiedad',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isEditing ? AppColors.info : AppColors.primary,
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
                    onPressed: () => _showAttributeForm(null, false),
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
                final isSaving = state.isSaving;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 960;

                    if (isDesktop) {
                      return _buildDesktopLayout(
                        context,
                        state,
                        cubit,
                        isSaving,
                        constraints,
                      );
                    }

                    return _buildMobileLayout(
                      context,
                      state,
                      cubit,
                      isSaving,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- LAYOUT DESKTOP (32% Formulario / 68% Lista y Comandos) ---
  Widget _buildDesktopLayout(
    BuildContext context,
    AttributesState state,
    AttributesCubit cubit,
    bool isSaving,
    BoxConstraints constraints,
  ) {
    final filteredAttributes = _getFilteredAttributes(state.attributes);
    final totalValues = state.attributes.fold<int>(
      0,
      (sum, a) => sum + a.values.length,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Formulario ERP Embebido (Ancho Fijo Óptimo 360px)
              SizedBox(
                width: 360,
                child: _buildDesktopFormCard(isSaving),
              ),
              const SizedBox(width: 24),
              // Columna Derecha: Barra de Comandos + Lista de Atributos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCommandBar(
                      totalAttributes: state.attributes.length,
                      totalValues: totalValues,
                      isMobile: false,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => cubit.loadAttributes(),
                        color: AppColors.primary,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildAttributeListContent(
                            state,
                            cubit,
                            filteredAttributes,
                            isDesktop: true,
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

  // --- LAYOUT MÓVIL Y TABLET COMPACTA ---
  Widget _buildMobileLayout(
    BuildContext context,
    AttributesState state,
    AttributesCubit cubit,
    bool isSaving,
  ) {
    final filteredAttributes = _getFilteredAttributes(state.attributes);
    final totalValues = state.attributes.fold<int>(
      0,
      (sum, a) => sum + a.values.length,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildCommandBar(
            totalAttributes: state.attributes.length,
            totalValues: totalValues,
            isMobile: true,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cubit.loadAttributes(),
              color: AppColors.primary,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildAttributeListContent(
                  state,
                  cubit,
                  filteredAttributes,
                  isDesktop: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BARRA DE COMANDO Y BÚSQUEDA ---
  Widget _buildCommandBar({
    required int totalAttributes,
    required int totalValues,
    required bool isMobile,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: isMobile
                    ? 'Buscar propiedad o valor...'
                    : 'Buscar propiedad o valor (Ej: Talla, Spiderman, Litro)...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : (!isMobile
                        ? Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  '/',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : null),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildStatBadge(
          label: '$totalAttributes ${totalAttributes == 1 ? 'propiedad' : 'propiedades'}',
          icon: Icons.category_outlined,
          color: AppColors.primary,
        ),
        if (!isMobile) ...[
          const SizedBox(width: 8),
          _buildStatBadge(
            label: '$totalValues valores',
            icon: Icons.label_outline_rounded,
            color: AppColors.info,
          ),
        ],
      ],
    );
  }

  Widget _buildStatBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTRADO DE ATRIBUTOS ---
  List<AttributeEntity> _getFilteredAttributes(
    List<AttributeEntity> attributes,
  ) {
    if (_searchQuery.isEmpty) return attributes;

    final q = _searchQuery.toLowerCase();
    return attributes.where((attr) {
      final matchName = attr.name.toLowerCase().contains(q);
      final matchDesc = attr.description?.toLowerCase().contains(q) ?? false;
      final matchValue = attr.values.any(
        (v) => v.value.toLowerCase().contains(q),
      );
      return matchName || matchDesc || matchValue;
    }).toList();
  }

  // --- TARJETA DE FORMULARIO DESKTOP ---
  Widget _buildDesktopFormCard(bool isSaving) {
    final isEditing = _editingAttributeId != null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
          width: isEditing ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(opacity: 0.04),
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
                  color: isEditing
                      ? AppColors.info.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEditing
                      ? Icons.edit_note_rounded
                      : Icons.add_circle_outline_rounded,
                  color: isEditing ? AppColors.info : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Editar Propiedad' : 'Nueva Propiedad',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Modifica el nombre o descripción.'
                          : 'Crea una propiedad para variantes.',
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
            focusNode: _nameFocusNode,
            label: 'Nombre de la Propiedad *',
            icon: Icons.label_outlined,
            hintText: 'Ej: Talla, Color, Presentación...',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _desktopDescCtrl,
            label: 'Descripción (Opcional)',
            icon: Icons.notes_rounded,
            hintText: 'Ej: Tamaño o formato del producto...',
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              if (isEditing) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : _clearDesktopForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: isEditing ? 1 : 2,
                child: AppPrimaryButton(
                  label: isEditing ? 'Guardar' : 'Crear Propiedad',
                  loading: isSaving,
                  onPressed: isSaving ? null : _saveDesktopAttribute,
                  backgroundColor:
                      isEditing ? AppColors.info : AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- CONTENIDO DE LA LISTA DE ATRIBUTOS ---
  Widget _buildAttributeListContent(
    AttributesState state,
    AttributesCubit cubit,
    List<AttributeEntity> filteredAttributes, {
    required bool isDesktop,
  }) {
    if (state.viewState == ViewState.loading ||
        state.viewState == ViewState.initial) {
      return const AttributesSkeleton(key: ValueKey('skeleton'), itemCount: 4);
    }

    if (state.errorMessage != null && state.attributes.isEmpty) {
      return Center(
        child: CatalogErrorState(
          message: state.errorMessage!,
          onRetry: () => cubit.loadAttributes(),
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
              ],
            ),
          ),
        ],
      );
    }

    if (filteredAttributes.isEmpty && _searchQuery.isNotEmpty) {
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
              'No se encontraron coincidencias para "$_searchQuery"',
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
                setState(() => _searchQuery = '');
              },
              child: const Text('Limpiar búsqueda'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: filteredAttributes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final attr = filteredAttributes[index];
        final isSelected = _editingAttributeId == attr.id;

        return _AttributeCard(
          attribute: attr,
          isSelected: isSelected,
          onEdit: () => _showAttributeForm(attr, isDesktop),
          onDelete: () => _handleDeleteAttribute(attr, cubit),
          onAddValue: () => _showAddValueForm(attr.id, attr.name),
        );
      },
    );
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
        if (_editingAttributeId == attr.id) {
          _clearDesktopForm();
        }
        AppSnackbar.show(
          context,
          message: 'Propiedad "${attr.name}" eliminada',
          type: SnackbarType.success,
        );
      }
    }
  }
}

// ==========================================
// WIDGETS PRIVADOS Y ATÓMICOS
// ==========================================

class _AttributeCard extends StatefulWidget {
  final AttributeEntity attribute;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddValue;

  const _AttributeCard({
    required this.attribute,
    required this.isSelected,
    required this.onEdit,
    required this.onDelete,
    required this.onAddValue,
  });

  @override
  State<_AttributeCard> createState() => _AttributeCardState();
}

class _AttributeCardState extends State<_AttributeCard> {
  bool _isHovered = false;

  IconData _getAttributeIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('talla') || lower.contains('tamaño') || lower.contains('size')) {
      return Icons.straighten_rounded;
    }
    if (lower.contains('color')) {
      return Icons.palette_outlined;
    }
    if (lower.contains('presentacion') ||
        lower.contains('presentación') ||
        lower.contains('unidad')) {
      return Icons.inventory_2_outlined;
    }
    if (lower.contains('modelo') || lower.contains('model')) {
      return Icons.layers_outlined;
    }
    if (lower.contains('material') || lower.contains('tela')) {
      return Icons.texture_rounded;
    }
    if (lower.contains('marca') || lower.contains('brand')) {
      return Icons.verified_outlined;
    }
    if (lower.contains('peso') ||
        lower.contains('capacidad') ||
        lower.contains('volumen')) {
      return Icons.scale_outlined;
    }
    return Icons.category_outlined;
  }

  Color _getAttributeColor(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('talla')) return const Color(0xFF10B981);
    if (lower.contains('color')) return const Color(0xFF8B5CF6);
    if (lower.contains('presentacion') || lower.contains('presentación')) {
      return const Color(0xFF0EA5E9);
    }
    if (lower.contains('modelo')) return const Color(0xFFF59E0B);
    if (lower.contains('material')) return const Color(0xFFEC4899);
    return AppColors.primary;
  }

  String _formatTitle(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.attribute.values;
    final themeColor = _getAttributeColor(widget.attribute.name);
    final themeIcon = _getAttributeIcon(widget.attribute.name);
    final formattedTitle = _formatTitle(widget.attribute.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? AppColors.primary
                : (_isHovered
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border),
            width: widget.isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (_isHovered || widget.isSelected)
              BoxShadow(
                color: themeColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          themeIcon,
                          color: themeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          formattedTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${values.length} ${values.length == 1 ? 'valor' : 'valores'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardActionIcon(
                      icon: Icons.edit_rounded,
                      tooltip: 'Editar Propiedad',
                      hoverColor: AppColors.primary,
                      onPressed: widget.onEdit,
                    ),
                    const SizedBox(width: 4),
                    _CardActionIcon(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Eliminar Propiedad',
                      hoverColor: AppColors.error,
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),

            if (widget.attribute.description != null &&
                widget.attribute.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text(
                  widget.attribute.description!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border, height: 1),
            ),

            // Grilla de Chips de Valores
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...values.map(
                    (v) => _ValueChip(
                      value: v,
                      attributeName: formattedTitle,
                    ),
                  ),
                  _AddValueChipButton(onTap: widget.onAddValue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color hoverColor;
  final VoidCallback onPressed;

  const _CardActionIcon({
    required this.icon,
    required this.tooltip,
    required this.hoverColor,
    required this.onPressed,
  });

  @override
  State<_CardActionIcon> createState() => _CardActionIconState();
}

class _CardActionIconState extends State<_CardActionIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.hoverColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: _isHovered ? widget.hoverColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueChip extends StatefulWidget {
  final AttributeValueEntity value;
  final String attributeName;

  const _ValueChip({
    required this.value,
    required this.attributeName,
  });

  @override
  State<_ValueChip> createState() => _ValueChipState();
}

class _ValueChipState extends State<_ValueChip> {
  bool _isDeleting = false;
  bool _isHovered = false;

  Future<void> _handleDelete() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar Valor',
      message:
          '¿Estás seguro de eliminar el valor "${widget.value.value}" de ${widget.attributeName}?',
      confirmText: 'Eliminar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final cubit = context.read<AttributesCubit>();
    final success = await cubit.deleteAttributeValue(widget.value.id);
    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message: 'Valor eliminado',
          type: SnackbarType.success,
        );
      }
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.value.value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _isDeleting ? null : _handleDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _isDeleting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddValueChipButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AddValueChipButton({required this.onTap});

  @override
  State<_AddValueChipButton> createState() => _AddValueChipButtonState();
}

class _AddValueChipButtonState extends State<_AddValueChipButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: _isHovered ? 0.4 : 0.2),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              SizedBox(width: 4),
              Text(
                'Añadir valor',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
