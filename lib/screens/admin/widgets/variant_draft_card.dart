import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/variant_draft.dart';
import 'package:inventory_store_app/shared/widgets/app_text_field.dart';
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
  // Lista local para gestionar los controladores de cada par Clave-Valor
  final List<_AttributeControllers> _attributeRows = [];

  @override
  void initState() {
    super.initState();
    _parseInitialAttributes();
  }

  // Lee el JSON actual del draft y genera las filas de campos de texto correspondientes
  void _parseInitialAttributes() {
    final rawJson = widget.draft.attributesCtrl.text.trim();
    if (rawJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(rawJson);
        decoded.forEach((key, value) {
          _addAttributeRow(key: key, value: value.toString(), sync: false);
        });
      } catch (e) {
        debugPrint('Error al parsear atributos iniciales: $e');
      }
    }
  }

  // Añade una nueva fila de Clave-Valor a la interfaz
  void _addAttributeRow({
    String key = '',
    String value = '',
    bool sync = true,
  }) {
    final keyCtrl = TextEditingController(text: key);
    final valueCtrl = TextEditingController(text: value);

    // Escuchar cambios en los nuevos campos para actualizar el JSON en tiempo real
    keyCtrl.addListener(_synchronizeToJson);
    valueCtrl.addListener(_synchronizeToJson);

    setState(() {
      _attributeRows.add(
        _AttributeControllers(keyCtrl: keyCtrl, valueCtrl: valueCtrl),
      );
    });

    if (sync) _synchronizeToJson();
  }

  // Elimina una fila de atributos
  void _removeAttributeRow(int index) {
    setState(() {
      _attributeRows[index].dispose();
      _attributeRows.removeAt(index);
    });
    _synchronizeToJson();
  }

  // Convierte las filas actuales de vuelta a un String JSON y lo asigna al controlador del Draft
  void _synchronizeToJson() {
    final Map<String, String> finalMap = {};
    for (final row in _attributeRows) {
      final key = row.keyCtrl.text.trim();
      final value = row.valueCtrl.text.trim();
      if (key.isNotEmpty) {
        finalMap[key] = value;
      }
    }

    // Actualizamos el controlador original que "product_form_screen" leerá al guardar
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABECERA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        widget.draft.isActive
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Variante #${widget.index + 1} ${widget.draft.isActive ? '' : '(Inactiva)'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          widget.draft.isActive
                              ? AppColors.primary
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Switch(
                      value: widget.draft.isActive,
                      onChanged: widget.onActiveChanged,
                      activeColor: AppColors.success,
                    ),
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Eliminar variante',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FILA 1: SKU y Punto de Reorden
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: widget.draft.skuCtrl,
                    label: 'SKU',
                    icon: Icons.qr_code,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: widget.draft.reorderPointCtrl,
                    label: 'Punto Reorden',
                    icon: Icons.warning_amber,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECCIÓN DINÁMICA DE ATRIBUTOS (Chips / Clave-Valor)
            _buildDynamicAttributesSection(),
            const SizedBox(height: 20),

            // FILA 2: Precios de la variante
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: widget.draft.priceCtrl,
                    label: 'P. Especial',
                    icon: Icons.sell_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    controller: widget.draft.wholesalePriceCtrl,
                    label: 'P. x Mayor',
                    icon: Icons.local_offer_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    controller: widget.draft.wholesaleMinQuantityCtrl,
                    label: 'Mín. Mayor',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // SECCIÓN GALERÍA (Restringida a 1 imagen)
            const Text(
              'Imagen de la variante (Máximo 1)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90, // Un poco más alto para que quepa el botón X
              child: Row(
                children: [
                  // Mostrar botón añadir solo si no hay imágenes
                  if (widget.draft.urlsExistentes.isEmpty &&
                      widget.draft.nuevasImagenes.isEmpty)
                    _buildAddButton(),

                  // Mostrar la imagen existente en base de datos
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

                  // Mostrar la nueva imagen seleccionada de galería
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

  // Genera el diseño visual dinámico para añadir Atributos (Ej: Color: Rojo)
  Widget _buildDynamicAttributesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Especificaciones / Atributos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addAttributeRow(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Añadir propiedad',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_attributeRows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Sin especificaciones (Ej: Color, Talla, Material...)',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
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
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: row.keyCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Propiedad (ej: Color)',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      ':',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: row.valueCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Valor (ej: Azul)',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeAttributeRow(idx),
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
        margin: const EdgeInsets.only(right: 8, top: 8),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
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
          margin: const EdgeInsets.only(right: 8, top: 8),
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
        // Botón rojo con X para eliminar la imagen
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Clase helper interna para agrupar los controladores de texto por fila
class _AttributeControllers {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  _AttributeControllers({required this.keyCtrl, required this.valueCtrl});

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}
