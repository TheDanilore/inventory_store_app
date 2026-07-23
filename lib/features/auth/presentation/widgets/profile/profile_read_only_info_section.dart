import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProfileReadOnlyInfoSection extends StatelessWidget {
  final String email;
  final String userRole;
  final String fullName;
  final String phone;
  final String docType;
  final String docNum;

  const ProfileReadOnlyInfoSection({
    super.key,
    required this.email,
    required this.userRole,
    required this.fullName,
    required this.phone,
    required this.docType,
    required this.docNum,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          children: [
            _InfoTile(
              icon: Icons.email_outlined,
              label: 'Correo electrónico',
              value: email,
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              label: 'Rol del sistema',
              value: userRole,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          children: [
            _InfoTile(
              icon: Icons.person_outline_rounded,
              label: 'Nombre completo',
              value: fullName.isEmpty ? 'No registrado' : fullName,
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: phone.isEmpty ? 'No registrado' : phone,
            ),
            _InfoTile(
              icon: Icons.badge_outlined,
              label: 'Documento ($docType)',
              value: docNum.isEmpty ? 'No registrado' : docNum,
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.textSecondary),
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
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: AppColors.border,
          ),
      ],
    );
  }
}
