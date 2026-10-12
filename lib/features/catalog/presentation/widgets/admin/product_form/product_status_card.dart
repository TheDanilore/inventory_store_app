import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductStatusCard extends StatelessWidget {
  const ProductStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.publicationStatus != c.publicationStatus,
      builder: (context, state) {
        final status = state.publicationStatus;

        String helperText;
        switch (status) {
          case 'draft':
            helperText =
                'Este producto está en modo borrador y no es visible para los clientes en la tienda.';
            break;
          case 'archived':
            helperText =
                'Este producto está archivado e inactivo. No está disponible para la compra.';
            break;
          case 'active':
          default:
            helperText =
                'Este producto está disponible para la compra en todos los canales de venta activos.';
            break;
        }

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
              Text(
                'Estado actual',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),

              // Dropdown estilizado consistente con los demás inputs
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                      size: 22,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'active',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(
                                  0xFF10B981,
                                ), // Verde esmeralda vivo
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x6610B981),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Activo (Visible en tienda)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'draft',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFF94A3B8), // Gris suave
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Borrador (No visible en tienda)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444), // Rojo
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Inactivo (Archivado)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        cubit.setPublicationStatus(val);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  helperText,
                  key: ValueKey(helperText),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
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
