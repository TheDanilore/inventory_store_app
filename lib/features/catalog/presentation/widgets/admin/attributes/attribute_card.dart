import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/attributes/attribute_value_chip.dart';

/// Tarjeta interactiva de Propiedad con Smart Tag Cloud, creador de valores inline
/// y botones de acción rápida.
class AttributeCard extends StatefulWidget {
  final AttributeEntity attribute;
  final String searchQuery;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenAddDialog;

  const AttributeCard({
    super.key,
    required this.attribute,
    required this.searchQuery,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenAddDialog,
  });

  @override
  State<AttributeCard> createState() => _AttributeCardState();
}

class _AttributeCardState extends State<AttributeCard> {
  bool _isHovered = false;
  bool _isExpanded = false;

  // Inline value creator state
  bool _isAddingInline = false;
  bool _isSubmittingInline = false;
  final TextEditingController _inlineCtrl = TextEditingController();
  final FocusNode _inlineFocusNode = FocusNode();

  @override
  void dispose() {
    _inlineCtrl.dispose();
    _inlineFocusNode.dispose();
    super.dispose();
  }

  IconData _getAttributeIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('talla') ||
        lower.contains('tamaño') ||
        lower.contains('size')) {
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

  Future<void> _submitInlineValue() async {
    final text = _inlineCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmittingInline = true);
    final cubit = context.read<AttributesCubit>();
    final success = await cubit.saveAttributeValue(widget.attribute.id, text);

    if (mounted) {
      setState(() {
        _isSubmittingInline = false;
        if (success) {
          _inlineCtrl.clear();
          // Mantiene el foco para que el usuario pueda escribir múltiples valores rápidamente
          _inlineFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.attribute.values;
    final themeColor = _getAttributeColor(widget.attribute.name);
    final themeIcon = _getAttributeIcon(widget.attribute.name);
    final formattedTitle = _formatTitle(widget.attribute.name);

    // Sistema Smart Tag Cloud: colapso inteligente si hay más de 8 valores
    final hasManyValues = values.length > 8;
    final visibleValues =
        (hasManyValues && !_isExpanded) ? values.take(8).toList() : values;

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
            color:
                _isHovered
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: themeColor.withValues(alpha: 0.08),
                blurRadius: 16,
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
                        child: Icon(themeIcon, color: themeColor, size: 20),
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

            // Grilla de Chips de Valores con Inline Creator & Smart Tag Expansion
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...visibleValues.map((v) {
                    final isMatch =
                        widget.searchQuery.isNotEmpty &&
                        v.value.toLowerCase().contains(
                          widget.searchQuery.toLowerCase(),
                        );
                    return AttributeValueChip(
                      value: v,
                      attributeName: formattedTitle,
                      isSearchMatch: isMatch,
                    );
                  }),

                  // Botón para expandir/colapsar si tiene muchos valores
                  if (hasManyValues)
                    InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded
                                  ? 'Ver menos'
                                  : '+${values.length - 8} más',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Creador Inline de Valor (Pro Tool: rápido sin modales)
                  if (_isAddingInline)
                    Container(
                      height: 32,
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 90,
                              maxWidth: 160,
                            ),
                            child: TextField(
                              controller: _inlineCtrl,
                              focusNode: _inlineFocusNode,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Nuevo valor...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (_) => _submitInlineValue(),
                            ),
                          ),
                          if (_isSubmittingInline)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          else ...[
                            InkWell(
                              onTap: _submitInlineValue,
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isAddingInline = false;
                                  _inlineCtrl.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    AddValueChipButton(
                      onTap: () {
                        setState(() {
                          _isAddingInline = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _inlineFocusNode.requestFocus();
                        });
                      },
                      onLongPress: widget.onOpenAddDialog,
                    ),
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
              color:
                  _isHovered
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
