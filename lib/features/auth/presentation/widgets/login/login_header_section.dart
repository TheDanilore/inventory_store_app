import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LoginHeaderSection extends StatelessWidget {
  final bool isLoginMode;

  const LoginHeaderSection({super.key, required this.isLoginMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            height: 110,
            constraints: const BoxConstraints(maxWidth: 180),
            child: Image.asset(
              'assets/logo_full.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isLoginMode ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.6,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isLoginMode
                ? 'Todo tu negocio en un solo lugar.'
                : 'Completa tus datos para empezar',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
