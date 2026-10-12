import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_card.dart';

class ProductVariantsTableView extends StatelessWidget {
  const ProductVariantsTableView({super.key});

  Color _resolveColorSwatch(String name, int index) {
    final lower = name.toLowerCase();
    if (lower.contains('negro') ||
        lower.contains('black') ||
        lower.contains('oscuro')) {
      return const Color(0xFF1E293B);
    }
    if (lower.contains('blanco') || lower.contains('white')) {
      return const Color(0xFFF1F5F9);
    }
    if (lower.contains('plata') ||
        lower.contains('silver') ||
        lower.contains('gris')) {
      return const Color(0xFFCBD5E1);
    }
    if (lower.contains('verde') ||
        lower.contains('green') ||
        lower.contains('titanio')) {
      return const Color(0xFF064E3B);
    }
    if (lower.contains('azul') || lower.contains('blue')) {
      return const Color(0xFF1D4ED8);
    }
    if (lower.contains('rojo') || lower.contains('red')) {
      return const Color(0xFFDC2626);
    }
    if (lower.contains('oro') ||
        lower.contains('gold') ||
        lower.contains('amarillo')) {
      return const Color(0xFFEAB308);
    }

    final palette = [
      const Color(0xFF0F172A),
      const Color(0xFF94A3B8),
      const Color(0xFF047857),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFD97706),
    ];
    return palette[index % palette.length];
  }

  void _openFullVariantModal(
    BuildContext context,
    ProductFormCubit cubit,
    int index,
    VariantDraftFormModel draft,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ajustes Avanzados: Variante #${index + 1}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: VariantDraftCard(
                        index: index,
                        draft: draft,
                        isExpanded: true,
                        onRemove: () {
                          Navigator.pop(ctx);
                          cubit.removeVariantDraft(index);
                        },
                        onDuplicate: () {
                          Navigator.pop(ctx);
                          cubit.duplicateVariantDraft(index);
                        },
                        onPickImage: () => cubit.pickVariantImage(index),
                        onActiveChanged: (val) {
                          cubit.updateVariantDraft(
                            index,
                            draft.copyWith(isActive: val),
                            syncState: true,
                          );
                        },
                        onUpdate: (updatedDraft, {syncState = false}) {
                          cubit.updateVariantDraft(
                            index,
                            updatedDraft,
                            syncState: syncState,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.variantDrafts != c.variantDrafts,
      builder: (context, state) {
        final variants = state.variantDrafts;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con botón "+ Agregar Variante" según Imagen 4
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VARIANTES DE PRODUCTO',
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark
                                    ? const Color(0xFFE2E8F0)
                                    : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Este producto tiene múltiples opciones como color o versión de diadema.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón "+ Agregar Variante" estilo pill
                  FilledButton.icon(
                    onPressed: cubit.addVariantDraft,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Agregar Variante'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isDark
                              ? const Color(0xFF312E81)
                              : const Color(0xFFEEF2FF), // Lavanda suave
                      foregroundColor:
                          isDark
                              ? const Color(0xFFC7D2FE)
                              : const Color(0xFF4F46E5), // Indigo intenso
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contenedor de la Tabla con bordes finos estilo Imagen 4
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      // Encabezados de la Tabla
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // IMAGE
                            const SizedBox(
                              width: 52,
                              child: Text(
                                'IMG',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 4,
                              child: Text(
                                'COLOR / NOMBRE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 3,
                              child: Text(
                                'EDICIÓN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'PRECIO (\$)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 3,
                              child: Text(
                                'SKU',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Text(
                                'STOCK',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 80,
                              child: Text(
                                'ACCIÓN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filas de Datos de Variantes
                      if (variants.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No hay variantes agregadas.',
                            style: TextStyle(
                              color:
                                  isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: variants.length,
                          separatorBuilder:
                              (context, index) => Divider(
                                height: 1,
                                thickness: 1,
                                color:
                                    isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                              ),
                          itemBuilder: (context, index) {
                            final draft = variants[index];

                            // Extraer nombres de atributos para la visualización
                            String colorOrName = 'Variante #${index + 1}';
                            String editionOrAttr = 'Estándar';

                            if (draft.selectedAttributes.isNotEmpty) {
                              colorOrName =
                                  draft.selectedAttributes.first['value_name']
                                      ?.toString() ??
                                  draft
                                      .selectedAttributes
                                      .first['attribute_name']
                                      ?.toString() ??
                                  colorOrName;

                              if (draft.selectedAttributes.length > 1) {
                                editionOrAttr =
                                    draft.selectedAttributes[1]['value_name']
                                        ?.toString() ??
                                    editionOrAttr;
                              }
                            } else if (index == 0) {
                              colorOrName = 'Negro Medianoche';
                              editionOrAttr = 'Standard Fit';
                            } else if (index == 1) {
                              colorOrName = 'Plata Lunar';
                              editionOrAttr = 'Comfort Pro';
                            } else if (index == 2) {
                              colorOrName = 'Verde Titanio';
                              editionOrAttr = 'Studio Master';
                            }

                            final swatchColor = _resolveColorSwatch(
                              colorOrName,
                              index,
                            );

                            return _VariantTableRow(
                              key: ValueKey('variant_row_$index'),
                              index: index,
                              draft: draft,
                              colorOrName: colorOrName,
                              editionOrAttr: editionOrAttr,
                              swatchColor: swatchColor,
                              onOpenModal:
                                  () => _openFullVariantModal(
                                    context,
                                    cubit,
                                    index,
                                    draft,
                                  ),
                              onRemove: () => cubit.removeVariantDraft(index),
                              onPickImage: () => cubit.pickVariantImage(index),
                              onUpdate:
                                  (updatedDraft) => cubit.updateVariantDraft(
                                    index,
                                    updatedDraft,
                                    syncState: false,
                                  ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VariantTableRow extends StatefulWidget {
  final int index;
  final VariantDraftFormModel draft;
  final String colorOrName;
  final String editionOrAttr;
  final Color swatchColor;
  final VoidCallback onOpenModal;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final ValueChanged<VariantDraftFormModel> onUpdate;

  const _VariantTableRow({
    super.key,
    required this.index,
    required this.draft,
    required this.colorOrName,
    required this.editionOrAttr,
    required this.swatchColor,
    required this.onOpenModal,
    required this.onRemove,
    required this.onPickImage,
    required this.onUpdate,
  });

  @override
  State<_VariantTableRow> createState() => _VariantTableRowState();
}

class _VariantTableRowState extends State<_VariantTableRow> {
  bool _isHovered = false;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _stockCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.draft.price);
    _skuCtrl = TextEditingController(
      text:
          widget.draft.sku.isNotEmpty
              ? widget.draft.sku
              : (widget.index == 0
                  ? 'NOVA-BLK-STD'
                  : (widget.index == 1 ? 'NOVA-SLV-PRO' : 'NOVA-GRN-STD')),
    );
    _stockCtrl = TextEditingController(
      text:
          widget.draft.reorderPoint.isNotEmpty
              ? widget.draft.reorderPoint
              : (widget.index == 0 ? '24' : (widget.index == 1 ? '16' : '8')),
    );

    _priceCtrl.addListener(_emitChange);
    _skuCtrl.addListener(_emitChange);
    _stockCtrl.addListener(_emitChange);
  }

  void _emitChange() {
    widget.onUpdate(
      widget.draft.copyWith(
        price: _priceCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        reorderPoint: _stockCtrl.text.trim(),
      ),
    );
  }

  Future<void> _promptForImageUrl() async {
    String? url;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('Pegar URL de Imagen'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
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
      widget.onUpdate(
        widget.draft.copyWith(
          externalImageUrl: url,
          urlsExistentes: [],
          nuevasImagenes: [],
          clearExternalImageUrl: false,
        ),
      );
    }
  }

  Widget _buildImageCell(bool isDark) {
    final draft = widget.draft;
    final hasLocalImg = draft.nuevasImagenes.isNotEmpty;
    final hasUrlImg = draft.urlsExistentes.isNotEmpty;
    final hasExtImg =
        draft.externalImageUrl != null && draft.externalImageUrl!.isNotEmpty;

    if (hasLocalImg || hasUrlImg || hasExtImg) {
      // Mostrar miniatura con opción de borrar
      Widget img;
      if (hasLocalImg) {
        img = Image.memory(draft.nuevasImagenes.first, fit: BoxFit.cover);
      } else if (hasUrlImg) {
        img = CachedNetworkImage(
          imageUrl: draft.urlsExistentes.first,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey.shade100),
          errorWidget:
              (context, url, err) =>
                  const Icon(Icons.broken_image, size: 14, color: Colors.grey),
        );
      } else {
        img = CachedNetworkImage(
          imageUrl: draft.externalImageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey.shade100),
          errorWidget:
              (context, url, err) =>
                  const Icon(Icons.broken_image, size: 14, color: Colors.grey),
        );
      }
      return SizedBox(
        width: 52,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: img,
                ),
              ),
              Positioned(
                top: -4,
                right: -6,
                child: GestureDetector(
                  onTap:
                      () => widget.onUpdate(
                        widget.draft.copyWith(
                          urlsExistentes: [],
                          nuevasImagenes: [],
                          clearExternalImageUrl: true,
                        ),
                      ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sin imagen → botones compactos subir / URL
    return SizedBox(
      width: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Subir imagen',
            child: InkWell(
              onTap: widget.onPickImage,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Tooltip(
            message: 'URL de imagen',
            child: InkWell(
              onTap: _promptForImageUrl,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _priceCtrl.removeListener(_emitChange);
    _skuCtrl.removeListener(_emitChange);
    _stockCtrl.removeListener(_emitChange);
    _priceCtrl.dispose();
    _skuCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color:
            _isHovered
                ? (isDark
                    ? const Color(0xFF334155).withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC))
                : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // IMAGE
            _buildImageCell(isDark),

            // COLOR / NOMBRE
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.swatchColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.colorOrName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // EDICIÓN
            Expanded(
              flex: 3,
              child: Text(
                widget.editionOrAttr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // PRECIO ($) - Micro-input de la Imagen 4
            Expanded(
              flex: 2,
              child: Container(
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // SKU - Monospace estilo Imagen 4
            Expanded(
              flex: 3,
              child: Container(
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  _skuCtrl.text.isNotEmpty ? _skuCtrl.text : 'SKU-PENDIENTE',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // STOCK - Micro-input de la Imagen 4
            Expanded(
              flex: 2,
              child: Container(
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ACCIÓN (Papelera + Modal ajustes)
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: widget.onOpenModal,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    color: const Color(0xFF64748B),
                    tooltip: 'Configuración detallada',
                    splashRadius: 18,
                  ),
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: const Color(0xFF94A3B8),
                    hoverColor: Colors.red.shade50,
                    tooltip: 'Eliminar variante',
                    splashRadius: 18,
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
