import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Define la marca o proveedor financiero reconocido en el sistema (Perú / Latam).
enum FinancialBrandType {
  yape,
  plin,
  bcp,
  bbva,
  interbank,
  scotiabank,
  bancoNacion,
  caja,
  digitalGeneral,
  bancoGeneral,
  otro,
}

class FinancialBrandInfo {
  final FinancialBrandType brand;
  final String label;
  final Color primaryColor;
  final Color bgColor;
  final Color textColor;
  final IconData icon;
  final String shortCode;

  const FinancialBrandInfo({
    required this.brand,
    required this.label,
    required this.primaryColor,
    required this.bgColor,
    required this.textColor,
    required this.icon,
    required this.shortCode,
  });
}

class FinancialBrandHelper {
  FinancialBrandHelper._();

  /// Identifica la marca financiera a partir del nombre y tipo de cuenta.
  static FinancialBrandInfo getBrand({required String name, String? type}) {
    final n = name.trim().toUpperCase();
    final t = (type ?? '').trim().toUpperCase();

    // 1. Yape
    if (n.contains('YAPE')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.yape,
        label: 'Yape',
        primaryColor: Color(0xFF742284),
        bgColor: Color(0xFFF6E8FA),
        textColor: Color(0xFF742284),
        icon: Icons.qr_code_2_rounded,
        shortCode: 'YAPE',
      );
    }

    // 2. Plin
    if (n.contains('PLIN')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.plin,
        label: 'Plin',
        primaryColor: Color(0xFF00B4D8),
        bgColor: Color(0xFFE0F7FA),
        textColor: Color(0xFF007791),
        icon: Icons.send_to_mobile_rounded,
        shortCode: 'PLIN',
      );
    }

    // 3. BCP
    if (n.contains('BCP') ||
        n.contains('CRÉDITO DEL PERÚ') ||
        n.contains('CREDITO DEL PERU')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.bcp,
        label: 'BCP',
        primaryColor: Color(0xFF002A8F),
        bgColor: Color(0xFFE8EEF9),
        textColor: Color(0xFF002A8F),
        icon: Icons.account_balance_rounded,
        shortCode: 'BCP',
      );
    }

    // 4. BBVA
    if (n.contains('BBVA') || n.contains('CONTINENTAL')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.bbva,
        label: 'BBVA',
        primaryColor: Color(0xFF004481),
        bgColor: Color(0xFFE6EEF5),
        textColor: Color(0xFF004481),
        icon: Icons.account_balance_rounded,
        shortCode: 'BBVA',
      );
    }

    // 5. Interbank
    if (n.contains('INTERBANK') || n.contains('IBK')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.interbank,
        label: 'Interbank',
        primaryColor: Color(0xFF009B3A),
        bgColor: Color(0xFFE6F7ED),
        textColor: Color(0xFF007A2E),
        icon: Icons.account_balance_rounded,
        shortCode: 'IBK',
      );
    }

    // 6. Scotiabank
    if (n.contains('SCOTIA') || n.contains('SCOTIABANK')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.scotiabank,
        label: 'Scotiabank',
        primaryColor: Color(0xFFEC111A),
        bgColor: Color(0xFFFDE8E9),
        textColor: Color(0xFFC70D15),
        icon: Icons.account_balance_rounded,
        shortCode: 'SCOTIA',
      );
    }

    // 7. Banco de la Nación
    if (n.contains('BANCO DE LA NACION') ||
        n.contains('BANCO DE LA NACIÓN') ||
        n.contains('BN')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.bancoNacion,
        label: 'Banco Nación',
        primaryColor: Color(0xFF8A1538),
        bgColor: Color(0xFFF7E6EB),
        textColor: Color(0xFF8A1538),
        icon: Icons.account_balance_rounded,
        shortCode: 'BN',
      );
    }

    // 8. Caja Física / Efectivo
    if (t == 'CAJA' || n.contains('CAJA') || n.contains('EFECTIVO')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.caja,
        label: 'Caja Física',
        primaryColor: AppColors.teal,
        bgColor: Color(0xFFE6FFFA),
        textColor: AppColors.tealDark,
        icon: Icons.point_of_sale_rounded,
        shortCode: 'CAJA',
      );
    }

    // 9. Digital General
    if (t == 'DIGITAL' || n.contains('BILLETERA')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.digitalGeneral,
        label: 'Billetera Digital',
        primaryColor: Color(0xFF8E24AA),
        bgColor: Color(0xFFF3E5F5),
        textColor: Color(0xFF6A1B9A),
        icon: Icons.smartphone_rounded,
        shortCode: 'DIGITAL',
      );
    }

    // 10. Banco General
    if (t == 'BANCO' || n.contains('BANCO') || n.contains('CUENTA')) {
      return const FinancialBrandInfo(
        brand: FinancialBrandType.bancoGeneral,
        label: 'Cuenta Bancaria',
        primaryColor: Color(0xFF0288D1),
        bgColor: Color(0xFFE1F5FE),
        textColor: Color(0xFF01579B),
        icon: Icons.account_balance_rounded,
        shortCode: 'BANCO',
      );
    }

    return const FinancialBrandInfo(
      brand: FinancialBrandType.otro,
      label: 'Otra Cuenta',
      primaryColor: AppColors.textSecondary,
      bgColor: Color(0xFFF1F5F9),
      textColor: AppColors.textPrimary,
      icon: Icons.wallet_rounded,
      shortCode: 'OTRO',
    );
  }

  /// Retorna el símbolo de moneda formateado a partir del código.
  static String formatCurrencySymbol(String? currencyCode) {
    final c = (currencyCode ?? 'PEN').trim().toUpperCase();
    if (c == 'USD' || c == 'DOL' || c == 'DOLARES' || c == 'DÓLARES') {
      return '\$';
    }
    return 'S/';
  }

  /// Renderiza un avatar / logo vectorial estilizado para la marca financiera.
  static Widget buildBrandBadge({
    required String name,
    String? type,
    double size = 32,
    bool showBorder = true,
  }) {
    final info = getBrand(name: name, type: type);

    switch (info.brand) {
      case FinancialBrandType.yape:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: info.primaryColor,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: info.primaryColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Y',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.58,
              letterSpacing: -0.5,
            ),
          ),
        );

      case FinancialBrandType.plin:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D2D3), Color(0xFF00A8E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D2D3).withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'P',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.58,
              letterSpacing: -0.5,
            ),
          ),
        );

      case FinancialBrandType.bcp:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: info.primaryColor,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: info.primaryColor.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'BCP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.34,
                  letterSpacing: -0.2,
                ),
              ),
              Positioned(
                top: size * 0.18,
                right: size * 0.15,
                child: Container(
                  width: size * 0.16,
                  height: size * 0.16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFD6200), // naranja característico BCP
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );

      case FinancialBrandType.bbva:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: info.primaryColor,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'BBVA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.28,
              letterSpacing: -0.3,
            ),
          ),
        );

      case FinancialBrandType.interbank:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: info.primaryColor,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'IBK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.32,
              letterSpacing: -0.3,
            ),
          ),
        );

      default:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: info.bgColor,
            borderRadius: BorderRadius.circular(size * 0.28),
            border:
                showBorder
                    ? Border.all(
                      color: info.primaryColor.withValues(alpha: 0.25),
                    )
                    : null,
          ),
          alignment: Alignment.center,
          child: Icon(info.icon, size: size * 0.52, color: info.primaryColor),
        );
    }
  }
}
