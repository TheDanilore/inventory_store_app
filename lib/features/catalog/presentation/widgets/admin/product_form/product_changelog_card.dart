import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductChangelogCard extends StatelessWidget {
  const ProductChangelogCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.changelog != c.changelog,
      builder: (context, state) {
        final logs =
            state.changelog.isNotEmpty
                ? state.changelog
                : [
                  {
                    'action': 'Ficha creada e inventario registrado',
                    'time': 'Inicial',
                    'author': 'Admin',
                  },
                ];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HISTORIAL DE CAMBIOS',
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 18),

              // Línea de tiempo visual según la Imagen 3
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final action =
                      log['action']?.toString() ?? 'Cambio registrado';
                  final time = log['time']?.toString() ?? 'Reciente';
                  final author = log['author']?.toString() ?? 'Sistema';

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Línea vertical izquierda continua (estilo Imagen 3)
                        Container(
                          width: 2.5,
                          margin: const EdgeInsets.only(right: 14, top: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$time • Por $author',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
