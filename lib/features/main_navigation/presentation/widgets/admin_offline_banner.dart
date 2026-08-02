import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/offline_games_suggestion.dart';

class AdminOfflineBanner extends StatelessWidget {
  const AdminOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkCubit, NetworkState>(
      builder: (context, state) {
        final isOnline = state is NetworkConnected;
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isOnline
              ? const SizedBox(width: double.infinity, height: 0)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Sin conexión a internet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const OfflineGamesSuggestion(),
                  ],
                ),
        );
      },
    );
  }
}
