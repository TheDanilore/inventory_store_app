import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/pending_orders_badge.dart';

/// Badge reactivo de pedidos pendientes para el Drawer (delegado a [PendingOrdersBadge]).
class DrawerBadgeWidget extends StatelessWidget {
  const DrawerBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) => const PendingOrdersBadge();
}
