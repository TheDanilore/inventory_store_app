import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/attribute_search_dialog.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';

class VariantDraftCard extends StatefulWidget {
  final int index;
  final VariantDraftFormModel draft;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onPickImage;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<VariantDraftFormModel> onUpdate;

  const VariantDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onDuplicate,
    required this.onPickImage,
    required this.onActiveChanged,
    required this.onUpdate,
  });

  @override
  State<VariantDraftCard> createState() => _VariantDraftCardState();
}

class _VariantDraftCardState extends State<VariantDraftCard> {
  final List<_AttributeSelection> _selectedAttributes = [];
  bool _isExpanded = false;

  late final TextEditingController skuCtrl;
  late final TextEditingController barcodeCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController wholesalePriceCtrl;
  late final TextEditingController wholesaleMinQuantityCtrl;
  late final TextEditingController reorderPointCtrl;
  late final TextEditingController unitCostCtrl;

  @override
  void initState() {
    super.initState();
    _parseInitialAttributes();
    // Inicializar controladores locales a partir del modelo mutable
    skuCtrl = TextEditingController(text: widget.draft.sku);
    barcodeCtrl = TextEditingController(text: widget.draft.barcode);
    priceCtrl = TextEditingController(text: widget.draft.price);
    wholesalePriceCtrl = TextEditingController(
      text: widget.draft.wholesalePrice,
    );
    wholesaleMinQuantityCtrl = TextEditingController(
      text: widget.draft.wholesaleMinQuantity,
    );
    reorderPointCtrl = TextEditingController(text: widget.draft.reorderPoint);
    unitCostCtrl = TextEditingController(text: widget.draft.unitCost);

    skuCtrl.addListener(_onFieldChanged);
    barcodeCtrl.addListener(_onFieldChanged);
    priceCtrl.addListener(_onFieldChanged);
    wholesalePriceCtrl.addListener(_onFieldChanged);
    wholesaleMinQuantityCtrl.addListener(_onFieldChanged);
    reorderPointCtrl.addListener(_onFieldChanged);
    unitCostCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    _syncAllToDraft();
    if (mounted) setState(() {});
  }

  void _syncAllToDraft() {
    if (!mounted) return;
    final List<Map<String, dynamic>> finalAttributes = [];
    for (final row in _selectedAttributes) {
      if (row.attributeId != null && row.valueId != null) {
        finalAttributes.add({
          'attribute_id': row.attributeId,
          'attribute_name': row.attributeName,
          'value_id': row.valueId,
          'value_name': row.valueName,
        });
      }
    }

    widget.onUpdate(
      widget.draft.copyWith(
        sku: skuCtrl.text,
        barcode: barcodeCtrl.text,
        price: priceCtrl.text,
        wholesalePrice: wholesalePriceCtrl.text,
        wholesaleMinQuantity: wholesaleMinQuantityCtrl.text,
        reorderPoint: reorderPointCtrl.text,
        unitCost: unitCostCtrl.text,
        selectedAttributes: finalAttributes,
      ),
    );
  }

  @override
  void didUpdateWidget(VariantDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.sku != oldWidget.draft.sku &&
        widget.draft.sku != skuCtrl.text) {
      skuCtrl.text = widget.draft.sku;
    }
    if (widget.draft.barcode != oldWidget.draft.barcode &&
        widget.draft.barcode != barcodeCtrl.text) {
      barcodeCtrl.text = widget.draft.barcode;
    }
    if (widget.draft.price != oldWidget.draft.price &&
        widget.draft.price != priceCtrl.text) {
      priceCtrl.text = widget.draft.price;
    }
    if (widget.draft.wholesalePrice != oldWidget.draft.wholesalePrice &&
        widget.draft.wholesalePrice != wholesalePriceCtrl.text) {
      wholesalePriceCtrl.text = widget.draft.wholesalePrice;
    }
    if (widget.draft.wholesaleMinQuantity !=
            oldWidget.draft.wholesaleMinQuantity &&
        widget.draft.wholesaleMinQuantity != wholesaleMinQuantityCtrl.text) {
      wholesaleMinQuantityCtrl.text = widget.draft.wholesaleMinQuantity;
    }
    if (widget.draft.reorderPoint != oldWidget.draft.reorderPoint &&
        widget.draft.reorderPoint != reorderPointCtrl.text) {
      reorderPointCtrl.text = widget.draft.reorderPoint;
    }
    if (widget.draft.unitCost != oldWidget.draft.unitCost &&
        widget.draft.unitCost != unitCostCtrl.text) {
      unitCostCtrl.text = widget.draft.unitCost;
    }
    final currentCompleted = _selectedAttributes
        .where((a) => a.attributeId != null && a.valueId != null)
        .map((a) => '${a.attributeId}:${a.valueId}')
        .toSet();
    final newCompleted = widget.draft.selectedAttributes
        .where((a) => a['attribute_id'] != null && a['value_id'] != null)
        .map((a) => '${a['attribute_id']}:${a['value_id']}')
        .toSet();
    if (!setEquals(currentCompleted, newCompleted)) {
      _selectedAttributes.clear();
      _parseInitialAttributes();
    }
  }

  @override
  void dispose() {
    skuCtrl.dispose();
    barcodeCtrl.dispose();
    priceCtrl.dispose();
    wholesalePriceCtrl.dispose();
    wholesaleMinQuantityCtrl.dispose();
    reorderPointCtrl.dispose();
    unitCostCtrl.dispose();
    super.dispose();
  }

  void _parseInitialAttributes() {
    for (final attr in widget.draft.selectedAttributes) {
      _selectedAttributes.add(
        _AttributeSelection(
          attributeId: attr['attribute_id'],
          attributeName: attr['attribute_name'] ?? '',
          valueId: attr['value_id'],
          valueName: attr['value_name'] ?? '',
        ),
      );
    }
  }

  void _addAttributeRow() {
    setState(() {
      _selectedAttributes.add(
        _AttributeSelection(attributeName: '', valueName: ''),
      );
    });
  }

  void _synchronizeToDraft() {
    _syncAllToDraft();
  }

  void _removeAttributeRow(int index) {
    setState(() {
      _selectedAttributes.removeAt(index);
    });
    _synchronizeToDraft();
  }

  Future<void> _pickAttributeKey(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) =>
              const AttributeSearchDialog(mode: AttributeSearchMode.attribute),
    );

    if (result != null) {
      final selectedId = result['id'];

      // Validar que el atributo no se haya seleccionado ya en otra fila
      final isAlreadyUsed = _selectedAttributes.asMap().entries.any(
        (entry) => entry.key != index && entry.value.attributeId == selectedId,
      );

      if (isAlreadyUsed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta propiedad ya fue agregada a la variante.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _selectedAttributes[index].attributeId = result['id'];
        _selectedAttributes[index].attributeName = result['name'];
        _selectedAttributes[index].valueId = null;
        _selectedAttributes[index].valueName = '';
      });
    }
  }

  Future<void> _pickAttributeValue(int index) async {
    final attributeId = _selectedAttributes[index].attributeId;
    final attributeName = _selectedAttributes[index].attributeName;

    if (attributeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona una Propiedad.')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => AttributeSearchDialog(
            mode: AttributeSearchMode.value,
            parentAttributeId: attributeId,
            parentAttributeName: attributeName,
          ),
    );

    if (result != null) {
      setState(() {
        _selectedAttributes[index].valueId = result['id'];
        _selectedAttributes[index].valueName = result['value'];
      });
      _synchronizeToDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.draft.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isActive
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CABECERA ────────────────────────────────────────────────────
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Variante #${widget.index + 1}${isActive ? '' : ' (Inactiva)'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color:
                            isActive ? AppColors.primary : Colors.grey.shade500,
                      ),
                    ),
                  ),
                  if (!_isExpanded && priceCtrl.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      'S/ ${priceCtrl.text}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: isActive,
                      onChanged: widget.onActiveChanged,
                      activeThumbColor: AppColors.success,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey,
                    ),
                    onSelected: (value) {
                      if (value == 'duplicate') widget.onDuplicate();
                      if (value == 'delete') widget.onRemove();
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8),
                                Text('Duplicar'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child:
                  _isExpanded
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // ── FILA 1: SKU + Punto de Reorden ─────────────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'SKU',
                                  controller: skuCtrl,
                                  icon: Icons.qr_code_2_rounded,
                                  hintText: 'Ej: PROD-001',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  label: 'Punto de Reorden',
                                  controller: reorderPointCtrl,
                                  icon: Icons.warning_amber_rounded,
                                  keyboardType: TextInputType.number,
                                  hintText: 'Ej: 5',
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── SECCIÓN ATRIBUTOS ───────────────────────────────────────────
                          _buildDynamicAttributesSection(),
                          const SizedBox(height: 16),

                          // ── SECCIÓN PRECIOS ─────────────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_money_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Precios de la variante',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    _buildMarginBadge(),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        label: 'Costo unitario',
                                        controller: unitCostCtrl,
                                        icon: Icons.price_change_outlined,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        hintText: '0.00',
                                        prefixText: 'S/ ',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppTextField(
                                        label: 'Precio venta',
                                        controller: priceCtrl,
                                        icon: Icons.sell_outlined,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        hintText: '0.00',
                                        prefixText: 'S/ ',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        label: 'P. mayorista',
                                        controller: wholesalePriceCtrl,
                                        icon: Icons.local_offer_outlined,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        hintText: '0.00',
                                        prefixText: 'S/ ',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d+\.?\d{0,2}'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppTextField(
                                        label: 'Mín. para mayoreo',
                                        controller: wholesaleMinQuantityCtrl,
                                        icon: Icons.numbers_rounded,
                                        keyboardType: TextInputType.number,
                                        hintText: 'Ej: 10',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),

                          // ── IMAGEN DE VARIANTE ──────────────────────────────────────────
                          Row(
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Imagen de la variante',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(Máximo 1)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 90,
                            child: Row(
                              children: [
                                if (widget.draft.urlsExistentes.isEmpty &&
                                    widget.draft.nuevasImagenes.isEmpty &&
                                    widget.draft.externalImageUrl == null)
                                  _buildAddButtons(),
                                if (widget.draft.urlsExistentes.isNotEmpty)
                                  _buildThumbnail(
                                    CachedNetworkImage(
                                      imageUrl:
                                          widget.draft.urlsExistentes.first,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget:
                                          (context, url, error) =>
                                              const Icon(Icons.error),
                                    ),
                                    onDelete: () {
                                      widget.onUpdate(
                                        widget.draft.copyWith(
                                          urlsExistentes: [],
                                          nuevasImagenes: [],
                                          clearExternalImageUrl: true,
                                        ),
                                      );
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                if (widget.draft.externalImageUrl != null)
                                  _buildThumbnail(
                                    CachedNetworkImage(
                                      imageUrl: widget.draft.externalImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.broken_image, color: Colors.red),
                                    ),
                                    onDelete: () {
                                      widget.onUpdate(
                                        widget.draft.copyWith(
                                          urlsExistentes: [],
                                          nuevasImagenes: [],
                                          clearExternalImageUrl: true,
                                        ),
                                      );
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                if (widget.draft.nuevasImagenes.isNotEmpty)
                                  _buildThumbnail(
                                    Image.memory(
                                      widget.draft.nuevasImagenes.first,
                                      fit: BoxFit.cover,
                                    ),
                                    onDelete: () {
                                      widget.onUpdate(
                                        widget.draft.copyWith(
                                          urlsExistentes: [],
                                          nuevasImagenes: [],
                                          clearExternalImageUrl: true,
                                        ),
                                      );
                                      if (mounted) setState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarginBadge() {
    final cost = double.tryParse(unitCostCtrl.text);
    final price = double.tryParse(priceCtrl.text);
    if (cost == null || price == null || price <= 0) {
      return const SizedBox.shrink();
    }

    final marginPercent = ((price - cost) / price) * 100;
    final isPositive = marginPercent > 0;
    final isHealthy = marginPercent >= 25;

    final color = isHealthy
        ? AppColors.success
        : isPositive
            ? Colors.orange.shade700
            : AppColors.error;

    final bgColor = isHealthy
        ? AppColors.success.withValues(alpha: 0.1)
        : isPositive
            ? Colors.orange.shade50
            : AppColors.error.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHealthy
                ? Icons.trending_up_rounded
                : isPositive
                    ? Icons.remove_rounded
                    : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            'Margen: ${marginPercent >= 0 ? '+' : ''}${marginPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicAttributesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Especificaciones / Atributos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addAttributeRow(),
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Añadir propiedad',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_selectedAttributes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Sin especificaciones (Ej: Color, Talla, Material...)',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedAttributes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final row = _selectedAttributes[idx];
              final hasKey = row.attributeName.isNotEmpty;
              final hasValue = row.valueName.isNotEmpty;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: Material(
                      color: hasKey ? Colors.white : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _pickAttributeKey(idx),
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: AppColors.primary.withValues(alpha: 0.04),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  hasKey
                                      ? AppColors.primary.withValues(alpha: 0.45)
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hasKey ? row.attributeName : 'Propiedad...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        hasKey
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                    fontWeight:
                                        hasKey
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                                color: hasKey ? AppColors.primary : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Material(
                      color: hasValue ? Colors.white : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _pickAttributeValue(idx),
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: AppColors.primary.withValues(alpha: 0.04),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  hasValue
                                      ? AppColors.primary.withValues(alpha: 0.45)
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hasValue ? row.valueName : 'Valor...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        hasValue
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                    fontWeight:
                                        hasValue
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                                color: hasValue ? AppColors.primary : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _removeAttributeRow(idx),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400,
                      size: 19,
                    ),
                    tooltip: 'Eliminar propiedad',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 16,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildAddButtons() {
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onPickImage,
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 4),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                SizedBox(height: 4),
                Text(
                  'Subir',
                  style: TextStyle(fontSize: 10, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: _promptForImageUrl,
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 4),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.blueGrey.withValues(alpha: 0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.link_rounded,
                  color: Colors.blueGrey,
                  size: 22,
                ),
                SizedBox(height: 4),
                Text(
                  'URL',
                  style: TextStyle(fontSize: 10, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _promptForImageUrl() async {
    String? url;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Pegar URL de Imagen'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                url = ctrl.text.trim();
                Navigator.pop(ctx);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
    if (url != null && url!.isNotEmpty) {
      widget.onUpdate(widget.draft.copyWith(
        externalImageUrl: url,
        urlsExistentes: [], // Limpiar otras
        nuevasImagenes: [],
        clearExternalImageUrl: false,
      ));
      if (mounted) setState(() {});
    }
  }

  Widget _buildThumbnail(Widget image, {required VoidCallback onDelete}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 6),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: image,
          ),
        ),
        Positioned(
          top: 0,
          right: 2,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttributeSelection {
  String? attributeId;
  String attributeName;
  String? valueId;
  String valueName;

  _AttributeSelection({
    this.attributeId,
    required this.attributeName,
    this.valueId,
    required this.valueName,
  });
}
