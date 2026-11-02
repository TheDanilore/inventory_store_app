import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Item de lista atómico y reutilizable para representar un cliente en el buscador (Desktop & Mobile).
class PosClientListTile extends StatelessWidget {
  final Map<String, dynamic> client;
  final bool isSelected;
  final bool isLoyaltyEnabled;
  final VoidCallback onTap;

  const PosClientListTile({
    super.key,
    required this.client,
    required this.isSelected,
    required this.isLoyaltyEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = client['full_name'] as String? ?? 'Cliente';
    final doc = client['document_number'] as String?;
    final phone = client['phone'] as String?;
    final wallet = (client['wallet_balance'] as num?)?.toInt() ?? 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.teal
                        : AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 16,
                color: isSelected ? Colors.white : AppColors.teal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    [
                      if (doc != null && doc.isNotEmpty) 'Doc: $doc',
                      if (phone != null && phone.isNotEmpty) 'Tel: $phone',
                      if (isLoyaltyEnabled && wallet > 0) '$wallet pts',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.teal,
              ),
          ],
        ),
      ),
    );
  }
}
