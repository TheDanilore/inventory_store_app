import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/screens/admin/user_form_screen.dart';
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

  // Copia local para reflejar cambios tras edición sin cerrar el sheet
  late Map<String, dynamic> _user;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.userData);
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjustPoints(int amount) async {
    if (amount == 0) return;
    setState(() => _isSaving = true);

    try {
      final String profileId = _user['id'];
      final int currentBalance = _user['wallet_balance'] ?? 0;
      final int newBalance = (currentBalance + amount).clamp(0, 9999999);

      await _supabase
          .from('profiles')
          .update({'wallet_balance': newBalance})
          .eq('id', profileId);

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

      setState(() {
        _user['wallet_balance'] = newBalance;
        _pointsCtrl.clear();
      });

      AppSnackbar.show(
        context,
        message: 'Saldo actualizado correctamente',
        type: SnackbarType.success,
      );

      widget.onUserUpdated();
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

  Future<void> _openEditForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserFormScreen(existingUser: _user)),
    );

    if (result == true && mounted) {
      // Recargamos datos frescos de la vista
      try {
        final updated =
            await Supabase.instance.client
                .from('profiles_with_email')
                .select()
                .eq('id', _user['id'])
                .single();
        setState(() => _user = Map<String, dynamic>.from(updated));
      } catch (_) {}
      widget.onUserUpdated();
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

    final String fullName = _user['full_name'] ?? 'Usuario';
    final String initial =
        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final String role = _user['role'] ?? 'customer';
    final bool isActive = _user['is_active'] ?? true;
    final int balance = _user['wallet_balance'] ?? 0;
    final String? email = _user['email'];
    final String? phone = _user['phone'];
    final String? docType = _user['document_type'];
    final String? docNumber = _user['document_number'];
    final String? createdAt = _user['created_at'];

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── HANDLE ──────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ─── CABECERA DEL PERFIL + BOTÓN EDITAR ──────────────────────────
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
                                fontWeight: FontWeight.w700,
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

                // ✅ Botón Editar
                IconButton(
                  onPressed: _openEditForm,
                  tooltip: 'Editar usuario',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── INFORMACIÓN DEL USUARIO ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (email != null && email.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.email_rounded,
                      'Correo electrónico',
                      email,
                    ),
                    const Divider(height: 24),
                  ],
                  if (phone != null && phone.isNotEmpty) ...[
                    _buildInfoRow(Icons.phone_rounded, 'Teléfono', phone),
                    const Divider(height: 24),
                  ],
                  if (docNumber != null && docNumber.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.badge_rounded,
                      'Documento',
                      '${docType ?? 'DNI'}: $docNumber',
                    ),
                    const Divider(height: 24),
                  ],
                  _buildInfoRow(
                    Icons.calendar_today_rounded,
                    'Fecha de registro',
                    _formatDate(createdAt),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── SECCIÓN DE MONEDAS / BILLETERA ─────────────────────────────
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
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
