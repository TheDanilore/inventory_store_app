import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credits_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class CreditAccountModal extends StatefulWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity? accountToEdit;
  final String customerId;

  const CreditAccountModal({
    super.key,
    required this.onSaved,
    required this.customerId,
    this.accountToEdit,
  });

  @override
  State<CreditAccountModal> createState() => _CreditAccountModalState();
}

class _CreditAccountModalState extends State<CreditAccountModal> {
  final _limitCtrl = TextEditingController();
  bool _isSaving = false;
  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _limitCtrl.text = widget.accountToEdit!.creditLimit.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final limit = double.tryParse(_limitCtrl.text);
    if (limit == null || limit <= 0) {
      AppSnackbar.showMessenger(ScaffoldMessenger.of(context), message: 'Ingrese un límite válido.', type: SnackbarType.error);
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      if (_isEditing) {
        // En una futura iteración se agregará updateCreditAccount
      } else {
        await context.read<CustomerCreditsCubit>().createCreditAccount(widget.customerId, limit);
      }
      
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context, true);
        AppSnackbar.showMessenger(ScaffoldMessenger.of(context), message: 'Cuenta de crédito .', type: SnackbarType.success);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showMessenger(ScaffoldMessenger.of(context), message: e.toString(), type: SnackbarType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Editar Límite de Crédito' : 'Aperturar Crédito',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            const Text('Límite de crédito (S/)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
