import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/usecases/delete_user_usecase.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_detail/user_detail_cubit.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/user_detail/user_detail_state.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/users/user_delete_flow.dart';

/// Ficha de usuario. Se abre con [UserDetailSheet.show], que delega en
/// [AdaptiveDetailSheet] (slide-over en desktop/tablet, bottom sheet en móvil).
class UserDetailSheet extends StatelessWidget {
  final String userId;
  final VoidCallback onUserUpdated;
  final Future<void> Function(UserEntity user)? onToggleStatus;

  const UserDetailSheet({
    super.key,
    required this.userId,
    required this.onUserUpdated,
    this.onToggleStatus,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required VoidCallback onUserUpdated,
    Future<void> Function(UserEntity user)? onToggleStatus,
  }) {
    return AdaptiveDetailSheet.show<void>(
      context,
      barrierLabel: 'Cerrar ficha del usuario',
      builder:
          (_) => UserDetailSheet(
            userId: userId,
            onUserUpdated: onUserUpdated,
            onToggleStatus: onToggleStatus,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<UserDetailCubit>()..fetchUser(userId),
      child: _UserDetailContent(
        onUserUpdated: onUserUpdated,
        onToggleStatus: onToggleStatus,
      ),
    );
  }
}

class _UserDetailContent extends StatefulWidget {
  final VoidCallback onUserUpdated;
  final Future<void> Function(UserEntity user)? onToggleStatus;

  const _UserDetailContent({required this.onUserUpdated, this.onToggleStatus});

  @override
  State<_UserDetailContent> createState() => _UserDetailContentState();
}

class _UserDetailContentState extends State<_UserDetailContent> {
  static const _title = 'Ficha del Usuario';
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
      return DateFormat('dd/MM/yyyy HH:mm', 'es').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _openEditForm(BuildContext context, UserEntity user) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(
      '/users/form',
      extra: {'existingUser': user, 'initialRole': user.role},
    );
  }

  Future<void> _confirmDeleteUser(BuildContext context, UserEntity user) async {
    final deleted = await runDeleteUserFlow(
      context,
      user: user,
      onDeactivate:
          widget.onToggleStatus == null
              ? null
              : () async {
                await widget.onToggleStatus!(user);
                widget.onUserUpdated();
              },
      onDelete: () async {
        final res = await sl<DeleteUserUseCase>()(user.id);
        return res.fold((failure) {
          AppSnackbar.show(
            context,
            message: 'Error al eliminar: ${failure.message}',
            type: SnackbarType.error,
          );
          return false;
        }, (_) => true);
      },
    );

    if (deleted && context.mounted) {
      Navigator.of(context).pop();
      widget.onUserUpdated();
      AppSnackbar.show(
        context,
        message: 'Usuario "${user.fullName}" eliminado correctamente',
        type: SnackbarType.success,
      );
    }
  }

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    AppSnackbar.show(
      context,
      message: '$label copiado',
      type: SnackbarType.success,
    );
  }

  void _adjustPoints(
    BuildContext context,
    UserDetailLoaded state, {
    required bool add,
  }) {
    void warn(String msg) =>
        AppSnackbar.show(context, message: msg, type: SnackbarType.warning);

    final input = _pointsCtrl.text.trim();
    if (input.isEmpty) return warn('Ingresa un monto válido');

    final amount = int.tryParse(input) ?? 0;
    if (add) {
      if (amount <= 0) return warn('El monto a sumar debe ser mayor a 0');
      if (amount > 100000) {
        return warn(
          'Por seguridad, el límite por ajuste manual es de 100,000 pt.',
        );
      }
      context.read<UserDetailCubit>().adjustPoints(amount);
    } else {
      if (amount <= 0) return warn('El monto a descontar debe ser mayor a 0');
      if (amount > state.user.walletBalance) {
        return warn(
          'No puedes restar más de los puntos actuales (${state.user.walletBalance} pt.)',
        );
      }
      context.read<UserDetailCubit>().adjustPoints(-amount);
    }
  }

  /// Marco con spinner / error: mantiene cabecera y botón de cerrar visibles.
  Widget _stateFrame(Widget child) {
    return DetailSheetFrame(
      title: _title,
      fillMobileHeight: true,
      bodyPadding: const EdgeInsets.all(24),
      body: SizedBox(height: 260, child: Center(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoyaltyEnabled =
        context.watch<AppConfigCubit>().loyaltyGlobalEnabled;

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
          return _stateFrame(const CircularProgressIndicator());
        }

        if (state is UserDetailError) {
          return _stateFrame(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Error al cargar: ${state.message}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (state is! UserDetailLoaded) {
          return const SizedBox.shrink();
        }

        final user = state.user;
        final roles = user.allRoles.where((r) => r.isNotEmpty).toList();
        final isAdmin =
            roles.contains(AppRoles.admin) || user.role == AppRoles.admin;
        final isEmployee =
            roles.contains(AppRoles.employee) || user.role == AppRoles.employee;
        final avatarBg =
            isAdmin
                ? Colors.indigo.withValues(alpha: 0.12)
                : isEmployee
                ? Colors.orange.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.1);
        final avatarFg =
            isAdmin
                ? Colors.indigo.shade700
                : isEmployee
                ? Colors.orange.shade700
                : AppColors.primary;
        final initial =
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?';

        return DetailSheetFrame(
          title: user.fullName.isNotEmpty ? user.fullName : _title,
          fillMobileHeight: true,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: avatarFg,
                ),
              ),
            ),
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final r in roles) _roleBadge(r),
              _statusBadge(user.isActive),
            ],
          ),
          bodyPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContactCard(context, user),
              if (isLoyaltyEnabled) ...[
                const SizedBox(height: 14),
                _buildLoyaltyCard(context, state),
                if (state.recentMovements.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildMovementsCard(state),
                ],
              ],
              const SizedBox(height: 14),
              _buildDangerZone(context, user),
            ],
          ),
          footer: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openEditForm(context, user),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'Editar usuario',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (widget.onToggleStatus != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onToggleStatus!(user);
                      widget.onUserUpdated();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: Icon(
                      user.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      user.isActive ? 'Desactivar' : 'Reactivar',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Secciones ──────────────────────────────────────────────────────────

  Widget _buildContactCard(BuildContext context, UserEntity user) {
    final email = user.email;
    final phone = user.phone;
    final doc = user.documentNumber;

    final rows = <Widget>[
      if (email != null && email.isNotEmpty)
        _buildInfoRow(
          icon: Icons.email_outlined,
          label: 'Correo Electrónico',
          value: email,
          onCopy: () => _copy(context, email, 'Correo'),
        ),
      if (phone != null && phone.isNotEmpty)
        _buildInfoRow(
          icon: Icons.phone_outlined,
          label: 'Teléfono',
          value: phone,
          onCopy: () => _copy(context, phone, 'Teléfono'),
        ),
      if (doc != null && doc.isNotEmpty)
        _buildInfoRow(
          icon: Icons.badge_outlined,
          label: 'Documento (${user.documentType})',
          value: doc,
          onCopy: () => _copy(context, doc, 'Documento'),
        ),
      _buildInfoRow(
        icon: Icons.calendar_today_outlined,
        label: 'Fecha de registro',
        value: _formatDate(user.createdAt?.toIso8601String()),
      ),
    ];

    return DetailSectionCard(
      title: 'Información de contacto',
      icon: Icons.contact_page_outlined,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildLoyaltyCard(BuildContext context, UserDetailLoaded state) {
    return DetailSectionCard(
      title: 'Programa de Fidelidad',
      icon: Icons.stars_rounded,
      backgroundColor: Colors.amber.shade50,
      borderColor: Colors.amber.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balance Actual',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${state.user.walletBalance} pt.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            'Ajustar puntos manualmente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Cantidad...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _pointsButton(
                color: AppColors.danger,
                icon: Icons.remove_rounded,
                onPressed:
                    state.isSaving
                        ? null
                        : () => _adjustPoints(context, state, add: false),
              ),
              const SizedBox(width: 8),
              _pointsButton(
                color: AppColors.success,
                icon: Icons.add_rounded,
                onPressed:
                    state.isSaving
                        ? null
                        : () => _adjustPoints(context, state, add: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pointsButton({
    required Color color,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildMovementsCard(UserDetailLoaded state) {
    return DetailSectionCard(
      title: 'Últimos movimientos de fidelidad',
      icon: Icons.history_rounded,
      child: Column(
        children: [
          for (final mov in state.recentMovements)
            Builder(
              builder: (_) {
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
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context, UserEntity user) {
    return DetailSectionCard(
      backgroundColor: const Color(0xFFFFF1F2),
      borderColor: const Color(0xFFFECDD3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Color(0xFFE11D48),
              ),
              SizedBox(width: 8),
              Text(
                'Zona de Peligro',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFBE123C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'La eliminación de este usuario es definitiva e irreversible. Se revocarán todas sus sesiones, credenciales y asignaciones comerciales.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: Color(0xFFFDA4AF)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text(
                'Eliminar Usuario Definitivamente',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: () => _confirmDeleteUser(context, user),
            ),
          ),
        ],
      ),
    );
  }

  // ── Piezas pequeñas ────────────────────────────────────────────────────

  Widget _statusBadge(bool isActive) {
    final base = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: base.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: base.shade200),
      ),
      child: Text(
        isActive ? 'ACTIVO' : 'INACTIVO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: base.shade700,
        ),
      ),
    );
  }

  Widget _roleBadge(String r) {
    MaterialColor c;
    String label;
    switch (r.toLowerCase()) {
      case 'admin':
        c = Colors.indigo;
        label = 'Admin';
        break;
      case 'cashier':
      case 'cajero':
        c = Colors.teal;
        label = 'Cajero';
        break;
      case 'warehouse_keeper':
      case 'almacenero':
        c = Colors.purple;
        label = 'Almacén';
        break;
      case 'employee':
      case 'empleado':
        c = Colors.amber;
        label = 'Empleado';
        break;
      case 'customer':
      case 'cliente':
        c = Colors.blue;
        label = 'Cliente';
        break;
      default:
        c = Colors.blueGrey;
        label = r.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.shade200, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c == Colors.amber ? c.shade800 : c.shade700,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
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
