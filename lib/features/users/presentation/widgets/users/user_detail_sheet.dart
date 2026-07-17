import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_detail/user_detail_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_detail/user_detail_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:go_router/go_router.dart';

class UserDetailSheet extends StatelessWidget {
  final String userId;
  final VoidCallback onUserUpdated;

  const UserDetailSheet({
    super.key,
    required this.userId,
    required this.onUserUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserDetailCubit>()..fetchUser(userId),
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _openEditForm(BuildContext context, UserDetailLoaded state) async {
    final changed = await context.push<bool?>(
      '/admin/user-form',
      extra: {'existingUser': state.user},
    );
    if (changed == true) {
      widget.onUserUpdated();
      // ignore: use_build_context_synchronously
      context.read<UserDetailCubit>().fetchUser(state.user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoyaltyEnabled = context.watch<AppConfigCubit>().loyaltyGlobalEnabled;

    return BlocConsumer<UserDetailCubit, UserDetailState>(
      listener: (context, state) {
        if (state is UserDetailLoaded) {
          if (state.errorMessage != null) {
            AppSnackbar.show(
              context,
              message: state.errorMessage!,
              type: SnackbarType.error,
            );
            context.read<UserDetailCubit>().clearMessages();
          } else if (state.successMessage != null) {
            AppSnackbar.show(
              context,
              message: state.successMessage!,
              type: SnackbarType.success,
            );
            _pointsCtrl.clear();
            widget.onUserUpdated();
            context.read<UserDetailCubit>().clearMessages();
          }
        } else if (state is UserDetailError) {
           AppSnackbar.show(
              context,
              message: state.message,
              type: SnackbarType.error,
            );
        }
      },
      builder: (context, state) {
        if (state is UserDetailInitial || state is UserDetailLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is UserDetailError) {
          return Center(
            child: Text(
              'Error al cargar: ${state.message}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (state is! UserDetailLoaded) {
          return const SizedBox.shrink();
        }

        final role = state.user.role;
        final fullName = state.user.fullName;
        final email = state.user.email;
        final phone = state.user.phone;
        final documentType = state.user.documentType;
        final documentNumber = state.user.documentNumber;
        final isActive = state.user.isActive;
        final walletBalance = state.user.walletBalance;

        final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
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

                    // ─── CABECERA DEL PERFIL + BOTÓN EDITAR ──────────
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: role == 'admin'
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
                                color: role == 'admin'
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
                                      color: role == 'admin'
                                          ? Colors.indigo.shade50
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: role == 'admin'
                                            ? Colors.indigo.shade200
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      role == 'admin' ? 'Administrador' : 'Cliente',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: role == 'admin'
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
                                      color: isActive
                                          ? Colors.green.shade50
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isActive
                                            ? Colors.green.shade200
                                            : Colors.red.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      isActive ? 'ACTIVO' : 'INACTIVO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
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

                        // Botón Editar
                        IconButton(
                          onPressed: () => _openEditForm(context, state),
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

                    // ─── INFORMACIÓN DEL USUARIO ──────────
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
                              icon: Icons.email_outlined,
                              label: 'Correo Electrónico',
                              value: email,
                              onCopy: () {
                                Clipboard.setData(ClipboardData(text: email));
                                AppSnackbar.show(
                                  context,
                                  message: 'Correo copiado',
                                  type: SnackbarType.success,
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                          ],
                          if (phone != null && phone.isNotEmpty) ...[
                            _buildInfoRow(
                              context,
                              icon: Icons.phone_outlined,
                              label: 'Teléfono',
                              value: phone,
                              onCopy: () {
                                Clipboard.setData(ClipboardData(text: phone));
                                AppSnackbar.show(
                                  context,
                                  message: 'Teléfono copiado',
                                  type: SnackbarType.success,
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                          ],
                          if (documentNumber != null && documentNumber.isNotEmpty) ...[
                            _buildInfoRow(
                              context,
                              icon: Icons.badge_outlined,
                              label: 'Documento ($documentType)',
                              value: documentNumber,
                              onCopy: () {
                                Clipboard.setData(ClipboardData(text: documentNumber));
                                AppSnackbar.show(
                                  context,
                                  message: 'Documento copiado',
                                  type: SnackbarType.success,
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                          ],
                          _buildInfoRow(
                            context,
                            icon: Icons.calendar_today_outlined,
                            label: 'Fecha de registro',
                            value: _formatDate(state.user.createdAt?.toIso8601String()),
                          ),
                        ],
                      ),
                    ),

                    // ─── FIDELIDAD (Opcional) ──────────
                    if (isLoyaltyEnabled) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Programa de Fidelidad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.stars_rounded,
                                      color: Colors.amber.shade600,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Balance Actual',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$walletBalance pt.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            const Text(
                              'Ajustar puntos manualmente',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: TextField(
                                      controller: _pointsCtrl,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
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
                                      onPressed: state.isSaving
                                          ? null
                                          : () {
                                              if (_pointsCtrl.text.trim().isEmpty) {
                                                AppSnackbar.show(
                                                  context,
                                                  message: 'Ingresa un monto',
                                                  type: SnackbarType.warning,
                                                );
                                                return;
                                              }
                                              final amount = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
                                              context.read<UserDetailCubit>().adjustPoints(-amount);
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
                                      onPressed: state.isSaving
                                          ? null
                                          : () {
                                              if (_pointsCtrl.text.trim().isEmpty) {
                                                AppSnackbar.show(
                                                  context,
                                                  message: 'Ingresa un monto',
                                                  type: SnackbarType.warning,
                                                );
                                                return;
                                              }
                                              final amount = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
                                              context.read<UserDetailCubit>().adjustPoints(amount);
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
                      
                      const SizedBox(height: 24),
                      if (state.recentMovements.isNotEmpty) ...[
                        const Text(
                          'Últimos movimientos de fidelidad',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...state.recentMovements.map((mov) {
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
                                    color: isPositive
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
