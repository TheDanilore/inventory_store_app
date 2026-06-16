import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/providers/admin/user_detail_provider.dart';
import 'package:inventory_store_app/screens/admin/user_form_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';

class UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onUserUpdated;

  const UserDetailSheet({
    super.key,
    required this.userData,
    required this.onUserUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserDetailProvider(initialUser: userData),
      child: _UserDetailContent(onUserUpdated: onUserUpdated),
    );
  }
}

class _UserDetailContent extends StatefulWidget {
  final VoidCallback onUserUpdated;

  const _UserDetailContent({required this.onUserUpdated});

  @override
  State<_UserDetailContent> createState() => _UserDetailContentState();
}

class _UserDetailContentState extends State<_UserDetailContent> {
  final _pointsCtrl = TextEditingController();

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  void _handleProviderMessages(
    BuildContext context,
    UserDetailProvider provider,
  ) {
    if (provider.errorMessage != null) {
      AppSnackbar.show(
        context,
        message: provider.errorMessage!,
        type: SnackbarType.error,
      );
      provider.clearMessages();
    } else if (provider.successMessage != null) {
      AppSnackbar.show(
        context,
        message: provider.successMessage!,
        type: SnackbarType.success,
      );
      provider.clearMessages();
      widget.onUserUpdated();
    }
  }

  Future<void> _openEditForm(
    BuildContext context,
    UserDetailProvider provider,
  ) async {
    if (provider.user == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(existingUser: provider.user!),
      ),
    );

    if (result == true && mounted) {
      await provider.reloadUser();
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

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Consumer<UserDetailProvider>(
      builder: (context, provider, child) {
        // Ejecutar mensajes después del frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleProviderMessages(context, provider);
        });

        final user = provider.user;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final String fullName = user['full_name'] ?? 'Usuario';
        final String initial =
            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
        final String role = user['role'] ?? 'customer';
        final bool isActive = user['is_active'] ?? true;
        final int balance = user['wallet_balance'] ?? 0;
        final String? email = user['email'];
        final String? phone = user['phone'];
        final String? docType = user['document_type'];
        final String? docNumber = user['document_number'];
        final String? createdAt = user['created_at'];

        return Stack(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
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
                                      role == 'admin'
                                          ? 'Administrador'
                                          : 'Cliente',
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
                          onPressed: () => _openEditForm(context, provider),
                          tooltip: 'Editar usuario',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.08,
                            ),
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
                              context,
                              icon: Icons.email_rounded,
                              label: 'Correo electrónico',
                              value: email,
                              onCopy:
                                  () => _copyToClipboard(
                                    context,
                                    email,
                                    'Correo',
                                  ),
                            ),
                            const Divider(height: 24),
                          ],
                          if (phone != null && phone.isNotEmpty) ...[
                            _buildInfoRow(
                              context,
                              icon: Icons.phone_rounded,
                              label: 'Teléfono',
                              value: phone,
                              onCopy:
                                  () => _copyToClipboard(
                                    context,
                                    phone,
                                    'Teléfono',
                                  ),
                            ),
                            const Divider(height: 24),
                          ],
                          if (docNumber != null && docNumber.isNotEmpty) ...[
                            _buildInfoRow(
                              context,
                              icon: Icons.badge_rounded,
                              label: 'Documento',
                              value: '${docType ?? 'DNI'}: $docNumber',
                              onCopy:
                                  () => _copyToClipboard(
                                    context,
                                    docNumber,
                                    'Documento',
                                  ),
                            ),
                            const Divider(height: 24),
                          ],
                          _buildInfoRow(
                            context,
                            icon: Icons.calendar_today_rounded,
                            label: 'Fecha de registro',
                            value: _formatDate(createdAt),
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
                              Icon(
                                Icons.stars_rounded,
                                color: Colors.amber.shade500,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (provider.isSaving)
                                const AppShimmer(
                                  width: 80,
                                  height: 32,
                                  borderRadius: 4,
                                )
                              else
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
                                    border: Border.all(
                                      color: Colors.amber.shade200,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _pointsCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                        provider.isSaving
                                            ? null
                                            : () {
                                              if (_pointsCtrl.text
                                                  .trim()
                                                  .isEmpty) {
                                                AppSnackbar.show(
                                                  context,
                                                  message: 'Ingresa un monto',
                                                  type: SnackbarType.warning,
                                                );
                                                return;
                                              }
                                              final amount =
                                                  int.tryParse(
                                                    _pointsCtrl.text.trim(),
                                                  ) ??
                                                  0;
                                              provider.adjustPoints(-amount);
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
                                        provider.isSaving
                                            ? null
                                            : () {
                                              if (_pointsCtrl.text
                                                  .trim()
                                                  .isEmpty) {
                                                AppSnackbar.show(
                                                  context,
                                                  message: 'Ingresa un monto',
                                                  type: SnackbarType.warning,
                                                );
                                                return;
                                              }
                                              final amount =
                                                  int.tryParse(
                                                    _pointsCtrl.text.trim(),
                                                  ) ??
                                                  0;
                                              provider.adjustPoints(amount);
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

                    // ─── HISTORIAL RECIENTE (Extra Proposal) ─────────────────────────────
                    if (provider.isLoading) ...[
                      const SizedBox(height: 24),
                      const AppShimmer(width: 200, height: 16, borderRadius: 4),
                      const SizedBox(height: 12),
                      const AppShimmer(
                        width: double.infinity,
                        height: 60,
                        borderRadius: 12,
                      ),
                      const SizedBox(height: 8),
                      const AppShimmer(
                        width: double.infinity,
                        height: 60,
                        borderRadius: 12,
                      ),
                    ] else if (provider.recentMovements.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Últimos movimientos de fidelidad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...provider.recentMovements.map((mov) {
                        final isPositive = (mov['points'] ?? 0) >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPositive
                                    ? Icons.add_circle_outline_rounded
                                    : Icons.remove_circle_outline_rounded,
                                color: isPositive ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mov['description'] ?? 'Movimiento',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(mov['created_at']),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isPositive ? '+' : ''}${mov['points']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isPositive
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
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
        if (onCopy != null)
          IconButton(
            icon: Icon(
              Icons.copy_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
            onPressed: onCopy,
            tooltip: 'Copiar',
            splashRadius: 20,
          ),
      ],
    );
  }
}
