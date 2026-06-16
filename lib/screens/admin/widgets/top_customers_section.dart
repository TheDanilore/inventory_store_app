import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class TopCustomersSection extends StatelessWidget {
  final List<CustomerSummary> top;
  final void Function(CustomerSummary) onTap;

  const TopCustomersSection({super.key, required this.top, required this.onTap});

  static const _medals = ['🥇', '🥈', '🥉', '4°', '5°'];

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
        ),
        SizedBox(
          height: 125, // Incrementado de 110 a 125 para evitar el RenderFlex overflow
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final c = top[i];
              return GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _medals[i],
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          _MiniAvatar(name: c.fullName, avatarUrl: c.avatarUrl),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.fullName.split(' ').first,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'S/ ${c.totalSpent.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
