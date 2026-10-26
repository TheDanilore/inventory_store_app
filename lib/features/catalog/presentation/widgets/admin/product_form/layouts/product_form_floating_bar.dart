import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

/// Barra flotante glassmorphism con acciones de guardado y feedback de cambios.
class ProductFormFloatingBar extends StatelessWidget {
  final bool isDesktop;
  final bool isEdit;
  final TextEditingController nombreCtrl;
  final VoidCallback onExit;
  final VoidCallback onPreview;
  final VoidCallback onSave;

  const ProductFormFloatingBar({
    super.key,
    required this.isDesktop,
    required this.isEdit,
    required this.nombreCtrl,
    required this.onExit,
    required this.onPreview,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopBar(context);
    }
    return _buildMobileBar(context);
  }

  Widget _buildDesktopBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 20,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Micro-estado reactivo vía BlocSelector
                      BlocSelector<ProductFormCubit, ProductFormState, bool>(
                        selector: (s) => s.isDirty,
                        builder: (context, isDirty) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDirty
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    isDirty
                                        ? Colors.orange.shade200
                                        : Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color:
                                        isDirty
                                            ? Colors.orange.shade600
                                            : Colors.green.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  isDirty
                                      ? 'Cambios sin guardar'
                                      : 'Cambios al día',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDirty
                                            ? Colors.orange.shade800
                                            : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: nombreCtrl,
                          builder: (context, _) {
                            final name = nombreCtrl.text.trim();
                            return Text(
                              name.isNotEmpty
                                  ? name
                                  : (isEdit
                                      ? 'Editar Producto'
                                      : 'Nuevo Producto'),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Tooltip(
                        message: 'Descartar cambios y salir (Esc)',
                        waitDuration: const Duration(milliseconds: 300),
                        child: OutlinedButton(
                          onPressed: onExit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Descartar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      BlocSelector<ProductFormCubit, ProductFormState, bool>(
                        selector: (s) => s.isSaving,
                        builder: (context, isSaving) {
                          return Tooltip(
                            message:
                                isEdit
                                    ? 'Guardar cambios del producto (Alt + G / Ctrl + S)'
                                    : 'Publicar nuevo producto en catálogo (Alt + G / Ctrl + S)',
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
                                      : const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                      ),
                              label: Text(
                                isEdit
                                    ? 'Actualizar Producto'
                                    : 'Guardar Producto',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBar(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    BlocSelector<ProductFormCubit, ProductFormState, bool>(
                      selector: (s) => s.isDirty,
                      builder: (context, isDirty) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDirty
                                    ? Colors.orange.shade50
                                    : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isDirty
                                      ? Colors.orange.shade200
                                      : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color:
                                      isDirty
                                          ? Colors.orange.shade600
                                          : Colors.green.shade600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isDirty ? 'Sin guardar' : 'Al día',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDirty
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'Vista previa (Ctrl + P)',
                      child: IconButton(
                        onPressed: onPreview,
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Descartar cambios y salir (Esc)',
                      child: OutlinedButton(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radius,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Salir',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BlocSelector<ProductFormCubit, ProductFormState, bool>(
                      selector: (s) => s.isSaving,
                      builder: (context, isSaving) {
                        return FilledButton.icon(
                          onPressed: isSaving ? null : onSave,
                          icon:
                              isSaving
                                  ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.check_rounded, size: 15),
                          label: Text(
                            isEdit ? 'Actualizar' : 'Guardar',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
