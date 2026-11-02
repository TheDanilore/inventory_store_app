import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/attribute_search_dialog.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_card/variant_card_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_card/variant_card_identifiers.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_card/variant_card_pricing.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_card/variant_card_attributes.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_card/variant_card_media.dart';

typedef VariantDraftUpdateCallback =
    void Function(VariantDraftFormModel newDraft, {bool syncState});

class VariantDraftCard extends StatefulWidget {
  final int index;
  final VariantDraftFormModel draft;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onPickImage;
  final ValueChanged<bool> onActiveChanged;
  final VariantDraftUpdateCallback onUpdate;
  final bool? isExpanded;

  const VariantDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onDuplicate,
    required this.onPickImage,
    required this.onActiveChanged,
    required this.onUpdate,
    this.isExpanded,
  });

  @override
  State<VariantDraftCard> createState() => _VariantDraftCardState();
}

class _VariantDraftCardState extends State<VariantDraftCard> {
  final List<AttributeSelectionItem> _selectedAttributes = [];
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
    _isExpanded = widget.isExpanded ?? (widget.index == 0);
    _parseInitialAttributes();

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
    _syncAllToDraft(syncState: false);
  }

  void _syncAllToDraft({bool syncState = false}) {
    if (!mounted) return;
    final List<Map<String, dynamic>> finalAttributes = [];
    for (final row in _selectedAttributes) {
      if (row.attributeId != null && row.valueId != null) {
        finalAttributes.add(row.toMap());
      }
    }

    widget.onUpdate(
      widget.draft.copyWith(
        sku: skuCtrl.text.trim(),
        barcode: barcodeCtrl.text.trim(),
        price: priceCtrl.text.trim(),
        wholesalePrice: wholesalePriceCtrl.text.trim(),
        wholesaleMinQuantity: wholesaleMinQuantityCtrl.text.trim(),
        reorderPoint: reorderPointCtrl.text.trim(),
        unitCost: unitCostCtrl.text.trim(),
        selectedAttributes: finalAttributes,
      ),
      syncState: syncState,
    );
  }

  @override
  void didUpdateWidget(VariantDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != null &&
        widget.isExpanded != oldWidget.isExpanded) {
      _isExpanded = widget.isExpanded!;
    }
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

    final currentCompleted =
        _selectedAttributes
            .where((a) => a.attributeId != null && a.valueId != null)
            .map((a) => '${a.attributeId}:${a.valueId}')
            .toSet();
    final newCompleted =
        widget.draft.selectedAttributes
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
    skuCtrl.removeListener(_onFieldChanged);
    barcodeCtrl.removeListener(_onFieldChanged);
    priceCtrl.removeListener(_onFieldChanged);
    wholesalePriceCtrl.removeListener(_onFieldChanged);
    wholesaleMinQuantityCtrl.removeListener(_onFieldChanged);
    reorderPointCtrl.removeListener(_onFieldChanged);
    unitCostCtrl.removeListener(_onFieldChanged);

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
        AttributeSelectionItem(
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
        AttributeSelectionItem(attributeName: '', valueName: ''),
      );
    });
  }

  void _removeAttributeRow(int index) {
    setState(() {
      _selectedAttributes.removeAt(index);
    });
    _syncAllToDraft();
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
      _syncAllToDraft();
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
            // ── Cabecera Inteligente ─────────────────────────────────────────
            VariantCardHeader(
              index: widget.index,
              draft: widget.draft,
              isExpanded: _isExpanded,
              onToggleExpand: () => setState(() => _isExpanded = !_isExpanded),
              onDuplicate: widget.onDuplicate,
              onRemove: widget.onRemove,
              onActiveChanged: widget.onActiveChanged,
              skuCtrl: skuCtrl,
              barcodeCtrl: barcodeCtrl,
              priceCtrl: priceCtrl,
              unitCostCtrl: unitCostCtrl,
              attributes: widget.draft.selectedAttributes,
            ),

            // ── Cuerpo Expandible ───────────────────────────────────────────
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
                          VariantCardIdentifiers(
                            skuCtrl: skuCtrl,
                            barcodeCtrl: barcodeCtrl,
                            reorderPointCtrl: reorderPointCtrl,
                            onFieldChanged: _onFieldChanged,
                          ),
                          const SizedBox(height: 16),
                          VariantCardAttributes(
                            attributes: _selectedAttributes,
                            onAddRow: _addAttributeRow,
                            onRemoveRow: _removeAttributeRow,
                            onPickKey: _pickAttributeKey,
                            onPickValue: _pickAttributeValue,
                          ),
                          const SizedBox(height: 16),
                          VariantCardPricing(
                            unitCostCtrl: unitCostCtrl,
                            priceCtrl: priceCtrl,
                            wholesalePriceCtrl: wholesalePriceCtrl,
                            wholesaleMinQuantityCtrl: wholesaleMinQuantityCtrl,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          VariantCardMedia(
                            draft: widget.draft,
                            onPickImage: widget.onPickImage,
                            onSetExternalUrl: (url) {
                              widget.onUpdate(
                                widget.draft.copyWith(
                                  externalImageUrl: url,
                                  urlsExistentes: [],
                                  nuevasImagenes: [],
                                  clearExternalImageUrl: false,
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                            onClearImage: () {
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
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
