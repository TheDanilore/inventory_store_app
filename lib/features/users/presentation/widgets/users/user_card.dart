import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/presentation/bloc/users/users_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserCard extends StatefulWidget {
  final UserEntity user;
  final VoidCallback onTap;
  final String role;
  final VoidCallback? onDelete;

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
    required this.role,
    this.onDelete,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  bool _isToggling = false;

  Future<void> _handleToggle(bool currentStatus) async {
    if (_isToggling) return;

    setState(() => _isToggling = true);

    await context.read<UsersCubit>().toggleUserStatus(
      widget.user.id,
      currentStatus,
    );

    if (mounted) {
      setState(() => _isToggling = false);
      // We rely on the Bloc Listener in the parent screen to show snackbars if needed,
      // or we could show them here if we had a way to wait for the exact result,
      // but toggleUserStatus handles the error emitting.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoyaltyEnabled =
        context.watch<AppConfigCubit>().loyaltyGlobalEnabled;
    final String fullName = widget.user.fullName;
    final String? email = widget.user.email;
    final String? phone = widget.user.phone;
    final bool isActive = widget.user.isActive;
    final int walletBalance = widget.user.walletBalance;
    final String initial =
        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      widget.role == AppRoles.admin
                          ? Colors.indigo.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color:
                          widget.role == AppRoles.admin
                              ? Colors.indigo.shade700
                              : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Nombre + email/teléfono
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (email != null && email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (phone != null && phone.isNotEmpty)
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (widget.user.allRoles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children:
                            widget.user.allRoles
                                .where((r) => r.isNotEmpty)
                                .map(_buildRoleBadge)
                                .toList(),
                      ),
                    ],
                    if (isLoyaltyEnabled) ...[
                      const SizedBox(height: 6),
                      // Monedas
                      Row(
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            size: 13,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$walletBalance monedas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Estado + chevron + Toggle Switch
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
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
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color:
                                isActive
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quick Toggle
                      if (_isToggling)
                        const SizedBox(
                          width: 32,
                          height: 20,
                          child: Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 20,
                          child: Transform.scale(
                            scale: 0.6,
                            child: CupertinoSwitch(
                              value: isActive,
                              activeTrackColor: Colors.green,
                              onChanged: (val) => _handleToggle(isActive),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onDelete != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: widget.onDelete,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String r) {
    Color bg;
    Color fg;
    Color border;
    String label;

    switch (r.toLowerCase()) {
      case 'admin':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        border = Colors.indigo.shade200;
        label = 'Admin';
        break;
      case 'cashier':
      case 'cajero':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade700;
        border = Colors.teal.shade200;
        label = 'Cajero';
        break;
      case 'warehouse_keeper':
      case 'almacenero':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        border = Colors.purple.shade200;
        label = 'Almacén';
        break;
      case 'employee':
      case 'empleado':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        border = Colors.amber.shade200;
        label = 'Empleado';
        break;
      case 'customer':
      case 'cliente':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        border = Colors.blue.shade200;
        label = 'Cliente';
        break;
      default:
        bg = Colors.blueGrey.shade50;
        fg = Colors.blueGrey.shade800;
        border = Colors.blueGrey.shade200;
        label = r.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
