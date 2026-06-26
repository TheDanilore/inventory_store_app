import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/admin/customer_detail_provider.dart'
    show UserAddress;
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'customer_section_card.dart';

class CustomerAddressesSection extends StatelessWidget {
  final List<UserAddress> addresses;
  const CustomerAddressesSection({super.key, required this.addresses});

  @override
  Widget build(BuildContext context) {
    return CustomerSectionCard(
      title: 'Direcciones',
      icon: Icons.location_on_rounded,
      child: Column(
        children: addresses.map((a) => _AddressRow(address: a)).toList(),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final UserAddress address;
  const _AddressRow({required this.address});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  address.isDefault
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              address.isDefault
                  ? Icons.home_rounded
                  : Icons.location_on_outlined,
              size: 14,
              color:
                  address.isDefault ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        address.addressLine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Principal',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${address.district}, ${address.province} - ${address.department}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (address.reference != null && address.reference!.isNotEmpty)
                  Text(
                    'Ref: ${address.reference}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
