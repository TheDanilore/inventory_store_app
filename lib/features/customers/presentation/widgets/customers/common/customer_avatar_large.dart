import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Avatar circular estilizado para el cliente con imagen remota en caché o iniciales
class CustomerAvatarLarge extends StatelessWidget {
  final CustomerEntity customer;
  final double radius;

  const CustomerAvatarLarge({
    super.key,
    required this.customer,
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    if (customer.avatarUrl != null && customer.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.background,
        backgroundImage: CachedNetworkImageProvider(customer.avatarUrl!),
      );
    }

    final color =
        Colors.primaries[customer.fullName.length % Colors.primaries.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        customer.fullName.isNotEmpty ? customer.fullName[0].toUpperCase() : '?',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.77,
        ),
      ),
    );
  }
}
