import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Shimmer
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: const AppShimmer(
              height: 220,
              width: double.infinity,
              borderRadius: 0,
            ),
          ),
          const SizedBox(height: 20),

          // Quick actions Shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppShimmer(width: 150, height: 20, borderRadius: 4),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.55,
                  ),
                  itemBuilder:
                      (context, index) => const AppShimmer(
                        height: double.infinity,
                        width: double.infinity,
                        borderRadius: 20,
                      ),
                ),
                const SizedBox(height: 24),

                // Info Cards Shimmer
                const AppShimmer(
                  height: 140,
                  width: double.infinity,
                  borderRadius: 20,
                ),
                const SizedBox(height: 16),
                const AppShimmer(
                  height: 210,
                  width: double.infinity,
                  borderRadius: 20,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
