import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'bulk_import_components.dart';

class BulkImportColumnsGuide extends StatelessWidget {
  final bool compact;
  const BulkImportColumnsGuide({super.key, required this.compact});

  static const _cols = <(String, bool, String)>[
    (
      'nombre',
      true,
      'Nombre del producto. Varias filas con el mismo nombre + marca = un producto con varias variantes.',
    ),
    (
      'precio_compra',
      true,
      'Costo de compra por unidad. También acepta "costo".',
    ),
    ('precio_venta', true, 'Precio de venta al público.'),
    ('marca', false, 'Marca o laboratorio. Si no existe, se crea.'),
    ('categoria', false, 'Categoría. Si no existe, se crea.'),
    (
      'variante',
      false,
      'Ej. "400mg", "Talla M". Se guarda como atributo "Variante". Vacío = variante única.',
    ),
    (
      'sku',
      false,
      'Código único. Si falta, se identifica por nombre + marca + variante.',
    ),
    ('precio_mayor', false, 'Precio por mayor.'),
    (
      'cantidad_mayor',
      false,
      'Cantidad mínima para aplicar el precio por mayor.',
    ),
    ('stock', false, 'Cantidad entera. Vacío = 0 (solo catálogo).'),
    (
      'usa_lotes',
      false,
      '"si" o "no". Si hay lote o vencimiento se asume "si".',
    ),
    (
      'lote',
      false,
      'Obligatorio si el producto usa lotes y hay stock. Una fila por lote.',
    ),
    (
      'vencimiento',
      false,
      'AAAA-MM-DD o DD/MM/AAAA. Obligatorio con lotes y stock.',
    ),
    (
      'componentes',
      false,
      'Principios activos de todo el producto. Varios: sepáralos con ;',
    ),
    ('descripcion', false, 'Descripción del producto.'),
    ('imagen_url', false, 'URL de la imagen.'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = bulkImportPrimary(context);
    return Container(
      decoration: AppColors.cardAdaptive(context),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.view_column_outlined, size: 18, color: primary),
          ),
          title: const Text(
            'Columnas del archivo',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
          ),
          subtitle: Text(
            'Una fila = una variante (y un lote, si aplica)',
            style: TextStyle(fontSize: 12.5, color: bulkImportMuted(context)),
          ),
          children: [
            _section(context, 'Obligatorias', true),
            const SizedBox(height: 12),
            _section(context, 'Opcionales', false),
            const SizedBox(height: 12),
            const BulkImportInfoBox(
              icon: Icons.info_outline,
              color: AppColors.info,
              text:
                  'Si el producto ya existe, su categoría, componentes y descripción no se modifican; solo se agregan variantes, lotes y stock.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, bool required) {
    final items = _cols.where((c) => c.$2 == required).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: required ? AppColors.error : bulkImportMuted(context),
          ),
        ),
        const SizedBox(height: 6),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child:
                compact
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _name(context, c.$1),
                        const SizedBox(height: 4),
                        Text(
                          c.$3,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: bulkImportMuted(context),
                          ),
                        ),
                      ],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 160, child: _name(context, c.$1)),
                        Expanded(
                          child: Text(
                            c.$3,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: bulkImportMuted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
      ],
    );
  }

  Widget _name(BuildContext context, String n) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bulkImportSoft(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        n,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
