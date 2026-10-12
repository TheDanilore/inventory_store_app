import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductSalesChannelsCard extends StatelessWidget {
  const ProductSalesChannelsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.salesChannels != c.salesChannels,
      builder: (context, state) {
        final channels = state.salesChannels;
        final totalChannels = 4;
        final activeCount = channels.values.where((v) => v).length;

        final channelList = [
          {
            'key': 'web',
            'title': 'Tienda Web Online',
            'badge': 'Publicado',
          },
          {
            'key': 'pos',
            'title': 'Terminal Punto de Venta (POS)',
            'badge': 'Publicado',
          },
          {
            'key': 'mercadolibre',
            'title': 'MercadoLibre / Amazon Sync',
            'badge': 'Sincronizado',
          },
          {
            'key': 'social',
            'title': 'Instagram & Facebook Shop',
            'badge': 'Publicado',
          },
        ];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              // Header con título y contador según la Imagen 2
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CANALES DE VENTA',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '$activeCount de $totalChannels activos',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5), // Azul violeta vibrante
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de canales con checkboxes nativos y badges
              ...channelList.map((ch) {
                final key = ch['key']!;
                final isChecked = channels[key] ?? false;
                final title = ch['title']!;
                final badge = ch['badge']!;

                return InkWell(
                  onTap: () => cubit.toggleSalesChannel(key),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                    child: Row(
                      children: [
                        // Checkbox moderno estilizado según Imagen 2
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isChecked
                                ? const Color(0xFF0066FF) // Azul brillante de la imagen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isChecked
                                  ? const Color(0xFF0066FF)
                                  : const Color(0xFFCBD5E1),
                              width: 1.8,
                            ),
                          ),
                          child: isChecked
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isChecked
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        Text(
                          isChecked ? badge : 'Inactivo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isChecked
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
