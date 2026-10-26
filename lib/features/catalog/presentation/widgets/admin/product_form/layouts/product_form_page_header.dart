import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

/// Header de página estilo ERP (Kusale) para la vista Desktop de producto.
/// Presenta título, subtítulo explicativo y las acciones gemelas superiores (Descartar, Vista Previa, Guardar).
class ProductFormPageHeader extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onExit;
  final VoidCallback onPreview;
  final VoidCallback onSave;

  const ProductFormPageHeader({
    super.key,
    required this.isEdit,
    required this.onExit,
    required this.onPreview,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Título Principal y Subtítulo Ejecutivo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? 'Editar Producto' : 'Nuevo Producto',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEdit
                    ? 'Actualiza los datos técnicos, inventario, precios y variantes'
                    : 'Registra un nuevo producto, configura precios, lotes y galería multimedia',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Acciones Gemelas de Cabecera
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Descartar cambios y salir (Esc)',
              waitDuration: const Duration(milliseconds: 300),
              child: OutlinedButton(
                onPressed: onExit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                ),
                child: const Text(
                  'Descartar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Vista previa de la ficha en tienda (Ctrl + P / ⌘ + P)',
              child: OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Vista Previa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            BlocSelector<ProductFormCubit, ProductFormState, bool>(
              selector: (s) => s.isSaving,
              builder: (context, isSaving) {
                return Tooltip(
                  message:
                      isEdit
                          ? 'Guardar cambios (Alt + G / Ctrl + S)'
                          : 'Publicar producto en catálogo (Alt + G / Ctrl + S)',
                  waitDuration: const Duration(milliseconds: 300),
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : onSave,
                    icon:
                        isSaving
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.check_rounded, size: 17),
                    label: Text(
                      isEdit ? 'Actualizar Producto' : 'Guardar Producto',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radius),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
