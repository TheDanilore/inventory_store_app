import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class AdminGoalDialog extends StatefulWidget {
  final double currentAmount;
  final double targetAmount;

  const AdminGoalDialog({
    super.key,
    required this.currentAmount,
    required this.targetAmount,
  });

  @override
  State<AdminGoalDialog> createState() => _AdminGoalDialogState();
}

class _AdminGoalDialogState extends State<AdminGoalDialog> {
  late TextEditingController _addCtrl;
  late TextEditingController _currentCtrl;
  late TextEditingController _targetCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addCtrl = TextEditingController();
    _currentCtrl = TextEditingController(
      text: widget.currentAmount.toStringAsFixed(2),
    );
    _targetCtrl = TextEditingController(
      text:
          widget.targetAmount > 0 ? widget.targetAmount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _currentCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGoal() async {
    final added = double.tryParse(_addCtrl.text.trim()) ?? 0.0;
    if (added < 0) {
      AppSnackbar.show(
        context,
        message: 'No puedes sumar un monto negativo.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final baseCurrent = double.tryParse(_currentCtrl.text.trim());
    if (baseCurrent == null || baseCurrent < 0) {
      AppSnackbar.show(
        context,
        message: 'El saldo actual debe ser un número válido positivo.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    final newTarget = double.tryParse(_targetCtrl.text.trim());
    if (newTarget == null || newTarget <= 0) {
      AppSnackbar.show(
        context,
        message: 'La meta total debe ser mayor a 0.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    final newCurrent = baseCurrent + added;

    setState(() {
      _isLoading = true;
    });

    final configProvider = context.read<AppConfigProvider>();

    try {
      await configProvider.saveValue(
        'admin_goal_current',
        newCurrent,
        description: 'Progreso actual del ahorro',
      );
      await configProvider.saveValue(
        'admin_goal_target',
        newTarget,
        description: 'Meta de ahorro del administrador',
      );

      if (mounted) {
        Navigator.pop(context, true);
        AppSnackbar.show(
          context,
          message: '¡Meta actualizada con éxito!',
          backgroundColor: AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar meta: \$e',
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Meta de Ahorro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Abonar a la meta (Suma)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto a sumar (S/.)',
                hintText: 'Ej. 100',
                prefixIcon: Icon(Icons.add_circle_outline, color: Colors.green),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Saldo Actual Exacto',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Corregir saldo (S/.)',
                prefixIcon: Icon(Icons.edit_note, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Modificar meta total',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Nueva Meta Total (S/.)',
                prefixIcon: Icon(Icons.flag_outlined, color: Colors.amber),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
          ),
          onPressed: _isLoading ? null : _saveGoal,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text(
                    'Guardar',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      ],
    );
  }
}
