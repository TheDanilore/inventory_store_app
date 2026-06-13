import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/variant_draft.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class VariantDraftCard extends StatefulWidget {
  final int index;
  final VariantDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final ValueChanged<bool> onActiveChanged;

  const VariantDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onPickImage,
    required this.onActiveChanged,
  });

  @override
  State<VariantDraftCard> createState() => _VariantDraftCardState();
}

class _VariantDraftCardState extends State<VariantDraftCard> {
  final List<_AttributeControllers> _attributeRows = [];

  @override
  void initState() {
    super.initState();
    _parseInitialAttributes();
  }

  void _parseInitialAttributes() {
    final rawJson = widget.draft.attributesCtrl.text.trim();
    if (rawJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(rawJson);
        decoded.forEach((key, value) {
          // Llenamos la lista directamente sin usar setState
          // ya que estamos dentro de la fase de initState.
          final keyCtrl = TextEditingController(text: key);
          final valueCtrl = TextEditingController(text: value.toString());
          keyCtrl.addListener(_synchronizeToJson);
          valueCtrl.addListener(_synchronizeToJson);

          _attributeRows.add(
            _AttributeControllers(keyCtrl: keyCtrl, valueCtrl: valueCtrl),
          );
        });
      } catch (e) {
        debugPrint('Error al parsear atributos iniciales: $e');
      }
    }
  }

  void _addAttributeRow({
    String key = '',
    String value = '',
    bool sync = true,
  }) {
    final keyCtrl = TextEditingController(text: key);
    final valueCtrl = TextEditingController(text: value);
    keyCtrl.addListener(_synchronizeToJson);
    valueCtrl.addListener(_synchronizeToJson);

    // Este setState SÍ es necesario porque este método se llama
    // cuando el usuario presiona el botón "Añadir propiedad"
    setState(() {
      _attributeRows.add(
        _AttributeControllers(keyCtrl: keyCtrl, valueCtrl: valueCtrl),
      );
    });
    if (sync) _synchronizeToJson();
  }

  void _removeAttributeRow(int index) {
    setState(() {
      _attributeRows[index].dispose();
      _attributeRows.removeAt(index);
    });
    _synchronizeToJson();
  }

  void _synchronizeToJson() {
    final Map<String, String> finalMap = {};
    for (final row in _attributeRows) {
      final key = row.keyCtrl.text.trim();
      final value = row.valueCtrl.text.trim();
      if (key.isNotEmpty) {
        finalMap[key] = value;
      }
    }
    widget.draft.attributesCtrl.text =
        finalMap.isEmpty ? '' : jsonEncode(finalMap);
  }

  @override
  void dispose() {
    for (final row in _attributeRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ─── INPUT HELPER ─────────────────────────────────────────────────────────
  Widget _field({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            prefixText: prefixText,
            prefixIcon:
                icon != null
                    ? Icon(icon, size: 16, color: Colors.grey.shade500)
                    : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
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
            Row(
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
                const Spacer(),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: isActive,
                    onChanged: widget.onActiveChanged,
                    activeColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Eliminar variante',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── FILA 1: SKU + Punto de Reorden ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    label: 'SKU',
                    controller: widget.draft.skuCtrl,
                    icon: Icons.qr_code_2_rounded,
                    hintText: 'Ej: PROD-001',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    label: 'Punto de Reorden',
                    controller: widget.draft.reorderPointCtrl,
                    icon: Icons.warning_amber_rounded,
                    keyboardType: TextInputType.number,
                    hintText: 'Ej: 5',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      Icon(
                        Icons.attach_money_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Precios de la variante',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(vacío = usa precio del producto)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fila 1: Costo unitario + Precio de venta
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          label: 'Costo unitario',
                          controller: widget.draft.unitCostCtrl,
                          icon: Icons.price_change_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hintText: '0.00',
                          prefixText: 'S/ ',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          label: 'Precio venta',
                          controller: widget.draft.priceCtrl,
                          icon: Icons.sell_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hintText: '0.00',
                          prefixText: 'S/ ',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fila 2: Precio mayorista + Cantidad mínima mayoreo
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          label: 'P. mayorista',
                          controller: widget.draft.wholesalePriceCtrl,
                          icon: Icons.local_offer_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hintText: '0.00',
                          prefixText: 'S/ ',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          label: 'Mín. para mayoreo',
                          controller: widget.draft.wholesaleMinQuantityCtrl,
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                          hintText: 'Ej: 10',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: Row(
                children: [
                  if (widget.draft.urlsExistentes.isEmpty &&
                      widget.draft.nuevasImagenes.isEmpty)
                    _buildAddButton(),
                  if (widget.draft.urlsExistentes.isNotEmpty)
                    _buildThumbnail(
                      Image.network(
                        widget.draft.urlsExistentes.first,
                        fit: BoxFit.cover,
                      ),
                      onDelete: () {
                        setState(() {
                          widget.draft.urlsExistentes.clear();
                        });
                      },
                    ),
                  if (widget.draft.nuevasImagenes.isNotEmpty)
                    _buildThumbnail(
                      Image.memory(
                        widget.draft.nuevasImagenes.first,
                        fit: BoxFit.cover,
                      ),
                      onDelete: () {
                        setState(() {
                          widget.draft.nuevasImagenes.clear();
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
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
              icon: Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
              label: Text(
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
        if (_attributeRows.isEmpty)
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
                color: Colors.grey.shade400,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attributeRows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final row = _attributeRows[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: row.keyCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Propiedad',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: Colors.grey.shade200),
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
                    child: TextField(
                      controller: row.valueCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Valor',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _removeAttributeRow(idx),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.remove_rounded,
                        color: Colors.red.shade400,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              'Añadir',
              style: TextStyle(fontSize: 10, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
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

class _AttributeControllers {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  _AttributeControllers({required this.keyCtrl, required this.valueCtrl});

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}
