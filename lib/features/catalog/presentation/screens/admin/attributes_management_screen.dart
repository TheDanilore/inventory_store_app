import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes_state.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_value_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attributes_skeleton.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';

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
    super.dispose();
  }

  void _showAttributeForm([Map<String, dynamic>? attribute]) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (isDesktop) {
      setState(() {
        _editingAttributeId = attribute?['id'];
        _desktopNameCtrl.text = attribute?['name'] ?? '';
        _desktopDescCtrl.text = attribute?['description'] ?? '';
      });
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

  Future<void> _saveDesktopAttribute() async {
    final name = _desktopNameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'El nombre de la propiedad es obligatorio.',
        type: SnackbarType.warning,
      );
      return;
    }

    final cubit = context.read<AttributesCubit>();
    final success = await cubit.saveAttribute(
      name,
      id: _editingAttributeId,
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
    return AdminLayout(
      title: 'Atributos de Variantes',
      showBackButton: true,
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
                final isDesktop = constraints.maxWidth >= 900;

                if (isDesktop) {
                  return _buildDesktopLayout(context, state, cubit, isSaving);
                }

                return RefreshIndicator(
                  onRefresh: () => cubit.loadAttributes(),
                  color: AppColors.primary,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildContent(state, cubit),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            onPressed: () => _showAttributeForm(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: ValueListenableBuilder<bool>(
              valueListenable: _isFabExtended,
              builder: (context, isExtended, _) {
                return AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child:
                      isExtended
                          ? const Text(
                            'Nueva Propiedad',
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
    AttributesState state,
    AttributesCubit cubit,
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
              // Columna Derecha: Lista de Atributos (60%)
              Expanded(
                flex: 60,
                child: RefreshIndicator(
                  onRefresh: () => cubit.loadAttributes(),
                  color: AppColors.primary,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildContent(state, cubit),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFormCard(bool isSaving) {
    final isEditing = _editingAttributeId != null;

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
                  Icons.category_outlined,
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
                      isEditing ? 'Editar Propiedad' : 'Nueva Propiedad',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Modifica el nombre y descripción del atributo.'
                          : 'Crea una propiedad para variantes (Talla, Color, etc.).',
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
            label: 'Nombre de la Propiedad',
            icon: Icons.label_outlined,
            hintText: 'Ej: Talla, Color, Sabor, Marca...',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _desktopDescCtrl,
            label: 'Descripción (Opcional)',
            icon: Icons.notes_rounded,
            hintText: 'Ej: Tamaño o presentación del producto...',
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
                  label: isEditing ? 'Guardar Cambios' : 'Crear Propiedad',
                  loading: isSaving,
                  onPressed: isSaving ? null : _saveDesktopAttribute,
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AttributesState state, AttributesCubit cubit) {
    if (state.viewState == ViewState.loading ||
        state.viewState == ViewState.initial) {
      return const AttributesSkeleton(key: ValueKey('skeleton'), itemCount: 4);
    }
    if (state.attributes.isEmpty) {
      return ListView(
        controller: _scrollController,
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.category_outlined,
                  size: 60,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 16),
                Text(
                  'No hay propiedades registradas',
                  style: TextStyle(
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

    return ListView.separated(
      controller: _scrollController,
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.attributes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final attr = state.attributes[index];
        return _AttributeCard(
          attribute: attr,
          onEdit: () => _showAttributeForm(attr),
          onDelete: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                ),
                title: const Text(
                  'Eliminar Propiedad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                content: Text(
                  '¿Estás seguro de eliminar la propiedad "${attr['name']}"? Se eliminarán también todos sus valores.',
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
              ),
            );

            if (confirmed == true && context.mounted) {
              final success = await cubit.deleteAttribute(attr['id']);
              if (success && context.mounted) {
                AppSnackbar.show(
                  context,
                  message: 'Propiedad "${attr['name']}" eliminada',
                  type: SnackbarType.success,
                );
              }
            }
          },
          onAddValue: () => _showAddValueForm(attr['id'], attr['name']),
        );
      },
    );
  }
}

// WIDGETS PRIVADOS

class _AttributeCard extends StatefulWidget {
  final Map<String, dynamic> attribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddValue;

  const _AttributeCard({
    required this.attribute,
    required this.onEdit,
    required this.onDelete,
    required this.onAddValue,
  });

  @override
  State<_AttributeCard> createState() => _AttributeCardState();
}

class _AttributeCardState extends State<_AttributeCard> {
  bool _isCardPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final values = (widget.attribute['attribute_values'] as List?) ?? [];
    final isSaving = context.watch<AttributesCubit>().state.isSaving;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onHighlightChanged: (val) => setState(() => _isCardPressed = val),
        onHover: (hover) => setState(() => _isHovered = hover),
        onTap: widget.onEdit,
        child: AnimatedScale(
          scale: _isCardPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.category_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.attribute['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: AppColors.info,
                          ),
                          onPressed: widget.onEdit,
                          tooltip: 'Editar Propiedad',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          onPressed: widget.onDelete,
                          tooltip: 'Eliminar Propiedad',
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.attribute['description'] != null &&
                    widget.attribute['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                      top: 4,
                      left: 52,
                    ),
                    child: Text(
                      widget.attribute['description'],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...values.map((v) => _ValueChip(value: v)),
                      AnimatedScale(
                        scale: isSaving ? 0.95 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: ActionChip(
                          label: const Text('Añadir valor'),
                          avatar: const Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onPressed: widget.onAddValue,
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
    );
  }
}

class _ValueChip extends StatefulWidget {
  final Map<String, dynamic> value;

  const _ValueChip({required this.value});

  @override
  State<_ValueChip> createState() => _ValueChipState();
}

class _ValueChipState extends State<_ValueChip> {
  bool _isDeleting = false;

  void _handleDelete() async {
    setState(() => _isDeleting = true);
    final success = await context.read<AttributesCubit>().deleteAttributeValue(
      widget.value['id'],
    );
    if (success && mounted) {
      AppSnackbar.show(
        context,
        message: 'Valor eliminado',
        type: SnackbarType.success,
      );
    }
    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(
        widget.value['value'],
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      deleteIcon:
          _isDeleting
              ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              )
              : const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
      onDeleted: _isDeleting ? null : _handleDelete,
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
