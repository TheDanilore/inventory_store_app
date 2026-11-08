import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';

class RolePermissionTile extends StatelessWidget {
  final PermissionEntity permission;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const RolePermissionTile({
    super.key,
    required this.permission,
    required this.isSelected,
    required this.onChanged,
  });

  bool get _isGateway =>
      permission.code == AppPermissions.erpAccess ||
      permission.code == AppPermissions.posView;

  bool get _isErp => permission.code == AppPermissions.erpAccess;
  bool get _isPos => permission.code == AppPermissions.posView;

  @override
  Widget build(BuildContext context) {
    final gatewayBg =
        _isErp
            ? Colors.indigo.shade50
            : _isPos
            ? Colors.teal.shade50
            : null;

    final gatewayBorder =
        _isErp
            ? Colors.indigo.shade100
            : _isPos
            ? Colors.teal.shade100
            : null;

    final chipColor = _isErp ? Colors.indigo.shade700 : Colors.teal.shade700;
    final chipLabel = _isErp ? 'Acceso ERP' : 'Acceso POS';

    final tile = CheckboxListTile(
      value: isSelected,
      activeColor: _isErp ? Colors.indigo.shade600 : AppColors.primary,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      onChanged: onChanged,
      title: Row(
        children: [
          Flexible(
            child: Text(
              permission.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          if (_isGateway) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: chipColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                chipLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: chipColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        permission.code,
        style: TextStyle(
          fontSize: 10.5,
          fontFamily: 'monospace',
          color:
              _isGateway
                  ? chipColor.withValues(alpha: 0.7)
                  : Colors.grey.shade500,
        ),
      ),
    );

    if (!_isGateway) return tile;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: gatewayBg,
        border: Border(
          left: BorderSide(
            color: gatewayBorder ?? Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: tile,
    );
  }
}
