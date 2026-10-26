import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/product_input_field.dart';

/// Diálogo con ciclo de vida seguro para registrar opiniones de clientes.
/// Los controladores TextEditingController se desechan de forma canónica en dispose().
class ProductAddReviewDialog extends StatefulWidget {
  final ProductDetailCubit cubit;

  const ProductAddReviewDialog({super.key, required this.cubit});

  static Future<void> show(BuildContext context, ProductDetailCubit cubit) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductAddReviewDialog(cubit: cubit),
    );
  }

  @override
  State<ProductAddReviewDialog> createState() => _ProductAddReviewDialogState();
}

class _ProductAddReviewDialogState extends State<ProductAddReviewDialog> {
  int _selectedRating = 5;
  late final TextEditingController _commentCtrl;
  late final TextEditingController _nameCtrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Ingresa el nombre del cliente.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await widget.cubit.addReview(
      userName: name,
      rating: _selectedRating,
      comment: _commentCtrl.text.trim(),
      isAdminSubmission: true,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.amber.withValues(alpha: 0.15)
                        : AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: AppColors.amber,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Registrar Opinión de Cliente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _selectedRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppColors.amber,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ProductInputField(
              controller: _nameCtrl,
              hint: 'Nombre del cliente',
              label: 'Nombre',
            ),
            const SizedBox(height: 12),
            ProductInputField(
              controller: _commentCtrl,
              hint: 'Comentario u opinión...',
              label: 'Comentario',
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radius),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radius),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Publicar',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
