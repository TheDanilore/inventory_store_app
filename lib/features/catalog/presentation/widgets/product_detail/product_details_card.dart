import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_card_header.dart';

class ProductDetailsCard extends StatelessWidget {
  final Map<String, dynamic> details;
  const ProductDetailsCard({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    final entries = details.entries.toList();
    return Container(
      decoration: AppColors.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: ProductCardHeader(
              icon: Icons.list_alt_rounded,
              iconColor: Color(0xFF8B5CF6),
              iconBg: Color(0xFFEDE9FE),
              title: 'Especificaciones',
            ),
          ),
          Container(height: 1, color: AppColors.divider),
          ...entries.asMap().entries.map((e) {
            final isEven = e.key % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              color: isEven ? AppColors.background : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      _humanizeKey(e.value.key.toString()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _humanizeValue(e.value.key.toString(), e.value.value),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _humanizeKey(String rawKey) {
    final clean = rawKey.replaceAll('_', ' ').toLowerCase().trim();
    switch (clean) {
      case 'active ingredient':
        return 'Ingrediente Activo';
      case 'tipo de producto':
      case 'product type':
        return 'Tipo de Producto';
      case 'formulation':
        return 'Formulación';
      case 'concentration':
        return 'Concentración';
      case 'action mode':
      case 'action mechanism':
        return 'Modo de Acción';
      case 'toxicological category':
        return 'Categoría Toxicológica';
      case 'country of origin':
        return 'País de Origen';
      case 'manufacturer':
        return 'Fabricante';
      case 'shelf life':
        return 'Vida Útil';
      case 'storage condition':
        return 'Almacenamiento';
      default:
        return rawKey
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (w) =>
                  w.isNotEmpty
                      ? '${w[0].toUpperCase()}${w.substring(1)}'
                      : '',
            )
            .join(' ');
    }
  }

  static String _humanizeValue(String rawKey, dynamic rawValue) {
    final val = rawValue?.toString() ?? '—';
    if (val.isEmpty || val == 'null') return '—';

    final cleanKey = rawKey.toLowerCase();
    if (cleanKey.contains('tipo') || cleanKey.contains('type')) {
      switch (val.toLowerCase().trim()) {
        case 'good':
          return 'Mercadería Física';
        case 'service':
          return 'Servicio';
        case 'raw_material':
          return 'Materia Prima';
        case 'finished_good':
          return 'Producto Terminado';
        case 'kit':
          return 'Kit / Combo';
        default:
          return val;
      }
    }

    if (cleanKey.contains('active_ingredient') ||
        cleanKey.contains('ingrediente')) {
      return val
          .split(',')
          .map((item) {
            final t = item.trim();
            if (t.isEmpty) return t;
            return t
                .split(' ')
                .map(
                  (w) =>
                      w.isNotEmpty
                          ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
                          : '',
                )
                .join(' ');
          })
          .join(', ');
    }

    return val;
  }
}
