import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onUserUpdated;

  const UserDetailSheet({
    super.key,
    required this.userData,
    required this.onUserUpdated,
  });

  @override
  State<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<UserDetailSheet> {
  final _supabase = Supabase.instance.client;
  final _pointsCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjustPoints(int amount) async {
    if (amount == 0) return;
    setState(() => _isSaving = true);

    try {
      final String profileId = widget.userData['id'];
      final int currentBalance = widget.userData['wallet_balance'] ?? 0;

      // Calculamos el nuevo saldo (evitando saldos negativos si es resta)
      final int newBalance = (currentBalance + amount).clamp(0, 9999999);

      // 1. Actualizamos el saldo en el perfil del usuario
      await _supabase
          .from('profiles')
          .update({'wallet_balance': newBalance})
          .eq('id', profileId);

      // 2. Registramos el movimiento en el historial
      await _supabase.from('wallet_movements').insert({
        'profile_id': profileId,
        'points': amount,
        'movement_type': 'MANUAL_BONUS',
        'description':
            amount > 0
                ? 'Abono manual de administrador'
                : 'Descuento manual de administrador',
      });

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Saldo actualizado correctamente',
        type: SnackbarType.success,
      );

      widget.onUserUpdated();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Error al actualizar saldo: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'No disponible';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return 'Fecha inválida';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final user = widget.userData;

    final String fullName = user['full_name'] ?? 'Usuario';
    final String initial =
        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final String role = user['role'] ?? 'customer';
    final bool isActive = user['is_active'] ?? true;
    final int balance = user['wallet_balance'] ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Añadimos SingleChildScrollView para evitar el overflow
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── HANDLE ──────────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ─── CABECERA DEL PERFIL ───────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color:
                        role == 'admin'
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color:
                            role == 'admin'
                                ? Colors.indigo.shade700
                                : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  role == 'admin'
                                      ? Colors.indigo.shade50
                                      : AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    role == 'admin'
                                        ? Colors.indigo.shade200
                                        : AppColors.border,
                              ),
                            ),
                            child: Text(
                              role == 'admin' ? 'Administrador' : 'Cliente',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    role == 'admin'
                                        ? Colors.indigo.shade700
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    isActive
                                        ? Colors.green.shade200
                                        : Colors.red.shade200,
                              ),
                            ),
                            child: Text(
                              isActive ? 'ACTIVO' : 'INACTIVO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color:
                                    isActive
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── DATOS DE CONTACTO E IDENTIFICACIÓN ────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.email_outlined,
                    'Correo',
                    user['email'] ?? 'No registrado',
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.phone_outlined,
                    'Teléfono',
                    user['phone'] ?? 'No registrado',
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.badge_outlined,
                    'Documento',
                    '${user['document_type'] ?? 'DNI'}: ${user['document_number'] ?? 'No registrado'}',
                  ),
                  const Divider(height: 20),
                  _buildInfoRow(
                    Icons.calendar_today_rounded,
                    'Registrado',
                    _formatDate(user['created_at']),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── SECCIÓN DE MONEDAS / BILLETERA ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.amberLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.amberLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monedas de Fidelidad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amberDark,
                        ),
                      ),
                      Icon(Icons.stars_rounded, color: Colors.amber.shade500),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balance.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.amberDark,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'monedas actuales',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Formulario para sumar/restar
                  const Text(
                    'Ajustar saldo manualmente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: TextField(
                            controller: _pointsCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              hintText: 'Cantidad...',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isSaving
                                    ? null
                                    : () {
                                      final amount =
                                          int.tryParse(
                                            _pointsCtrl.text.trim(),
                                          ) ??
                                          0;
                                      _adjustPoints(-amount);
                                    },
                            child: const Icon(Icons.remove_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _isSaving
                                    ? null
                                    : () {
                                      final amount =
                                          int.tryParse(
                                            _pointsCtrl.text.trim(),
                                          ) ??
                                          0;
                                      _adjustPoints(amount);
                                    },
                            child: const Icon(Icons.add_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
