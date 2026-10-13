import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/usecases/get_user_relations_usecase.dart';

enum _DeleteChoice { delete, deactivate, cancel }

/// Devuelve true si el usuario fue eliminado.
Future<bool> runDeleteUserFlow(
  BuildContext context, {
  required UserEntity user,
  required Future<bool> Function() onDelete,
  Future<void> Function()? onDeactivate,
}) async {
  // 1. Consultar relaciones con indicador de carga
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final res = await sl<GetUserRelationsUseCase>()(user.id);
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (!context.mounted) return false;

  final relations = res.fold<Map<String, int>?>((_) => null, (r) => r);
  if (relations == null) {
    AppSnackbar.show(
      context,
      message: 'No se pudo verificar las relaciones del usuario',
      type: SnackbarType.error,
    );
    return false;
  }

  // 2. Mostrar confirmación según haya o no relaciones
  final blocking = relations['blocking_total'] ?? 0;
  final choice = await showDialog<_DeleteChoice>(
    context: context,
    builder: (_) => _DeleteUserDialog(
      user: user,
      relations: relations,
      hasBlocking: blocking > 0,
      canDeactivate: onDeactivate != null && user.isActive,
    ),
  );

  if (choice == _DeleteChoice.deactivate) {
    await onDeactivate?.call();
    return false;
  }
  if (choice != _DeleteChoice.delete) return false;

  return onDelete();
}

class _DeleteUserDialog extends StatelessWidget {
  final UserEntity user;
  final Map<String, int> relations;
  final bool hasBlocking;
  final bool canDeactivate;

  const _DeleteUserDialog({
    required this.user,
    required this.relations,
    required this.hasBlocking,
    required this.canDeactivate,
  });

  static const _labels = <String, String>{
    'orders': 'Pedidos / compras como cliente',
    'sales_created': 'Ventas registradas como operador',
    'cash_shifts': 'Turnos de caja (apertura/cierre)',
    'account_movements': 'Movimientos en cuentas financieras',
    'credit_accounts': 'Línea de crédito comercial',
  };

  @override
  Widget build(BuildContext context) {
    final items = _labels.entries
        .where((e) => (relations[e.key] ?? 0) > 0)
        .toList();
    final color = hasBlocking ? Colors.orange.shade800 : Colors.green.shade700;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        hasBlocking ? 'No se puede eliminar' : 'Eliminar usuario',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${user.fullName}" (${user.email ?? user.phone ?? 'sin contacto'})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: hasBlocking
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Este usuario tiene registros asociados:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final e in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '•  ${_labels[e.key]}: ${relations[e.key]}',
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Eliminarlo rompería el historial contable. '
                          'Se recomienda desactivar la cuenta.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este usuario no tiene relaciones '
                            '(pedidos, pagos, turnos ni créditos).',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (!hasBlocking) ...[
              const SizedBox(height: 12),
              Text(
                'Se eliminará permanentemente su cuenta y credenciales'
                '${(relations['wallet_points'] ?? 0) > 0 ? ', junto con ${relations['wallet_points']} puntos acumulados' : ''}'
                '. Esta acción no se puede deshacer.',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _DeleteChoice.cancel),
          child: const Text('Cancelar'),
        ),
        if (hasBlocking && canDeactivate)
          FilledButton(
            onPressed: () => Navigator.pop(context, _DeleteChoice.deactivate),
            child: const Text('Desactivar cuenta'),
          ),
        if (!hasBlocking)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, _DeleteChoice.delete),
            child: const Text('Eliminar usuario'),
          ),
      ],
    );
  }
}