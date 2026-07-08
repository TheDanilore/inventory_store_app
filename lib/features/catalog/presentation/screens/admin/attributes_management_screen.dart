import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes_state.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/widgets/attributes/attribute_form_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/widgets/attributes/attribute_value_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/widgets/attributes/attributes_skeleton.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_layout.dart';

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
    // Load attributes on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttributesCubit>().loadAttributes();
    });
  }

  void _showAttributeForm([Map<String, dynamic>? attribute]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AttributeFormSheet(attribute: attribute),
    );
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
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Atributos de Variantes',
      showBackButton: true,
      body: BlocBuilder<AttributesCubit, AttributesState>(
        builder: (context, state) {
          final cubit = context.read<AttributesCubit>();
          return RefreshIndicator(
            onRefresh: () => cubit.loadAttributes(),
            color: AppColors.primary,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildContent(state, cubit),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAttributeForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: ValueListenableBuilder<bool>(
          valueListenable: _isFabExtended,
          builder: (context, isExtended, _) {
            return AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isExtended
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
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No hay propiedades registradas',
                  style: TextStyle(
                    color: Colors.grey.shade500,
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
          onDelete: () => cubit.deleteAttribute(attr['id']),
          onAddValue: () => _showAddValueForm(attr['id'], attr['name']),
        );
      },
    );
  }
}

// ─── WIDGETS PRIVADOS ─────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final values = (widget.attribute['attribute_values'] as List?) ?? [];
    // Read isSaving from cubit state for the chip animation
    final isSaving = context.watch<AttributesCubit>().state.isSaving;

    return AnimatedScale(
      scale: _isCardPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onHighlightChanged: (val) => setState(() => _isCardPressed = val),
          onTap: widget.onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.category_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.attribute['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Colors.blue,
                          ),
                          onPressed: widget.onEdit,
                          tooltip: 'Editar Propiedad',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
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
                    padding: const EdgeInsets.only(bottom: 12, top: 4, left: 52),
                    child: Text(
                      widget.attribute['description'],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const Divider(),
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
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
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
    await context
        .read<AttributesCubit>()
        .deleteAttributeValue(widget.value['id']);
    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(widget.value['value'], style: const TextStyle(fontSize: 13)),
      deleteIcon:
          _isDeleting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.close, size: 14),
      onDeleted: _isDeleting ? null : _handleDelete,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
