import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class UsersSkeleton extends StatelessWidget {
  const UsersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar circular
                const AppShimmer(width: 48, height: 48, isCircular: true),
                const SizedBox(width: 14),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmer(width: 150, height: 16, borderRadius: 8),
                      SizedBox(height: 8),
                      AppShimmer(width: 100, height: 12, borderRadius: 6),
                      SizedBox(height: 8),
                      AppShimmer(width: 80, height: 12, borderRadius: 6),
                    ],
                  ),
                ),

                // Badge de estado y Chevron
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    AppShimmer(width: 50, height: 18, borderRadius: 6),
                    SizedBox(height: 12),
                    AppShimmer(width: 20, height: 20, borderRadius: 10),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
