import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Skeleton de carga 1:1 adaptado a los 3 breakpoints de ProfileScreen
/// (Móvil < 600px, Tablet 600–1023px, Desktop >= 1024px).
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1024;
        final isTablet = width >= 600 && width < 1024;

        if (isDesktop || isTablet) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24 : 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isDesktop ? 34 : 38,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppShimmer(height: 152, borderRadius: 24),
                          SizedBox(height: 14),
                          AppShimmer(height: 108, borderRadius: 20),
                          SizedBox(height: 14),
                          AppShimmer(height: 62, borderRadius: 16),
                          SizedBox(height: 14),
                          AppShimmer(height: 62, borderRadius: 16),
                        ],
                      ),
                    ),
                    SizedBox(width: isDesktop ? 24 : 20),
                    Expanded(
                      flex: isDesktop ? 66 : 62,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppShimmer(width: 190, height: 22, borderRadius: 6),
                          SizedBox(height: 12),
                          AppShimmer(height: 146, borderRadius: 20),
                          SizedBox(height: 16),
                          AppShimmer(height: 204, borderRadius: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppShimmer(height: 148, borderRadius: 24),
              SizedBox(height: 14),
              AppShimmer(height: 108, borderRadius: 20),
              SizedBox(height: 20),
              AppShimmer(width: 180, height: 20, borderRadius: 6),
              SizedBox(height: 12),
              AppShimmer(height: 132, borderRadius: 20),
              SizedBox(height: 12),
              AppShimmer(height: 190, borderRadius: 20),
              SizedBox(height: 20),
              AppShimmer(height: 62, borderRadius: 16),
              SizedBox(height: 14),
              AppShimmer(height: 62, borderRadius: 16),
            ],
          ),
        );
      },
    );
  }
}
