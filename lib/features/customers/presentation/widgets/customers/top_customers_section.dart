import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers_state.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class TopCustomersSection extends StatelessWidget {
  const TopCustomersSection({super.key});

  static const _medals = ['🥇', '🥈', '🥉', '4º', '5º'];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopCustomersCubit, TopCustomersState>(
      builder: (context, state) {
        if (state is TopCustomersLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TopCustomersLoaded) {
          final top = state.topCustomers;
          if (top.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Top compradores',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/admin/top-customers'),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: top.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final c = top[i];
                    return _TopCustomerCard(
                      customer: c,
                      medal: _medals[i],
                      onTap:
                          (c) => context.go(
                            '/admin/customer-detail/${c.id}',
                            extra: c,
                          ),
                    );
                  },
                ),
              ),
            ],
          );
        } else if (state is TopCustomersError) {
          return Center(child: Text('Error: ${state.message}'));
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _TopCustomerCard extends StatefulWidget {
  final CustomerEntity customer;
  final String medal;
  final void Function(CustomerEntity) onTap;

  const _TopCustomerCard({
    required this.customer,
    required this.medal,
    required this.onTap,
  });

  @override
  State<_TopCustomerCard> createState() => _TopCustomerCardState();
}

class _TopCustomerCardState extends State<_TopCustomerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isHovered ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTapDown: (_) => setState(() => _isHovered = true),
            onTapUp: (_) => setState(() => _isHovered = false),
            onTapCancel: () => setState(() => _isHovered = false),
            onTap: () => widget.onTap(widget.customer),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(widget.medal, style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      _MiniAvatar(
                        name: widget.customer.fullName,
                        avatarUrl: widget.customer.avatarUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.customer.fullName.split(' ').first,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'S/ ${widget.customer.totalRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _MiniAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
      );
    }

    return CircleAvatar(
      radius: 12,
      backgroundColor: Colors.primaries[name.length % Colors.primaries.length],
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
