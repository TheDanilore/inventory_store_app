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

  const UserCard({
    super.key,
    required this.user,
    required this.onTap,
    required this.role,
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
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
