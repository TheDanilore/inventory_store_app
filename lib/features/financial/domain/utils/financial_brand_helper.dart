import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Define la marca o proveedor financiero reconocido en el sistema (Perú / Latam).
enum FinancialBrandType {
  yape,
  plin,
  tunki,
  agora,
  bcp,
  bbva,
  interbank,
  scotiabank,
  bancoNacion,
  banbif,
  pichincha,
  cajaArequipa,
  cajaHuancayo,
  cajaCusco,
  cajaPiura,
  cajaMunicipal,
  caja,
  posNiubiz,
  posIzipay,
  digitalGeneral,
  bancoGeneral,
  otro,
}

class FinancialBrandPreset {
  final String key;
  final String label;
  final String defaultName;
  final String type; // 'CAJA', 'BANCO', 'DIGITAL', 'OTRO'
  final FinancialBrandType brandType;
  final Color primaryColor;
  final IconData icon;

  const FinancialBrandPreset({
    required this.key,
    required this.label,
    required this.defaultName,
    required this.type,
    required this.brandType,
    required this.primaryColor,
    required this.icon,
  });
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

  /// Catálogo de presets preconfigurados con logos, nombres y tipos por defecto
  static const List<FinancialBrandPreset> presets = [
    // Billeteras
    FinancialBrandPreset(
      key: 'yape',
      label: 'Yape',
      defaultName: 'Yape',
      type: 'DIGITAL',
      brandType: FinancialBrandType.yape,
      primaryColor: Color(0xFF742284),
      icon: Icons.qr_code_2_rounded,
    ),
    FinancialBrandPreset(
      key: 'plin',
      label: 'Plin',
      defaultName: 'Plin',
      type: 'DIGITAL',
      brandType: FinancialBrandType.plin,
      primaryColor: Color(0xFF00B4D8),
      icon: Icons.send_to_mobile_rounded,
    ),
    FinancialBrandPreset(
      key: 'tunki',
      label: 'Tunki / Agora',
      defaultName: 'Tunki',
      type: 'DIGITAL',
      brandType: FinancialBrandType.tunki,
      primaryColor: Color(0xFFE91E63),
      icon: Icons.smartphone_rounded,
    ),

    // Bancos
    FinancialBrandPreset(
      key: 'bcp',
      label: 'BCP',
      defaultName: 'BCP Soles',
      type: 'BANCO',
      brandType: FinancialBrandType.bcp,
      primaryColor: Color(0xFF002A8F),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'bbva',
      label: 'BBVA',
      defaultName: 'BBVA Continental',
      type: 'BANCO',
      brandType: FinancialBrandType.bbva,
      primaryColor: Color(0xFF004481),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'interbank',
      label: 'Interbank',
      defaultName: 'Interbank',
      type: 'BANCO',
      brandType: FinancialBrandType.interbank,
      primaryColor: Color(0xFF009B3A),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'scotiabank',
      label: 'Scotiabank',
      defaultName: 'Scotiabank',
      type: 'BANCO',
      brandType: FinancialBrandType.scotiabank,
      primaryColor: Color(0xFFEC111A),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'banco_nacion',
      label: 'Banco Nación',
      defaultName: 'Banco de la Nación',
      type: 'BANCO',
      brandType: FinancialBrandType.bancoNacion,
      primaryColor: Color(0xFF8A1538),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'banbif',
      label: 'BanBif / Pichincha',
      defaultName: 'BanBif Soles',
      type: 'BANCO',
      brandType: FinancialBrandType.banbif,
      primaryColor: Color(0xFF0072BC),
      icon: Icons.account_balance_rounded,
    ),

    // Cajas Municipales
    FinancialBrandPreset(
      key: 'caja_arequipa',
      label: 'Caja Arequipa',
      defaultName: 'Caja Arequipa',
      type: 'BANCO',
      brandType: FinancialBrandType.cajaArequipa,
      primaryColor: Color(0xFFC41230),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'caja_huancayo',
      label: 'Caja Huancayo',
      defaultName: 'Caja Huancayo',
      type: 'BANCO',
      brandType: FinancialBrandType.cajaHuancayo,
      primaryColor: Color(0xFFD32F2F),
      icon: Icons.account_balance_rounded,
    ),
    FinancialBrandPreset(
      key: 'caja_cusco',
      label: 'Caja Cusco / Piura',
      defaultName: 'Caja Cusco',
      type: 'BANCO',
      brandType: FinancialBrandType.cajaCusco,
      primaryColor: Color(0xFF1976D2),
      icon: Icons.account_balance_rounded,
    ),

    // Efectivo / Caja
    FinancialBrandPreset(
      key: 'caja_principal',
      label: 'Caja Principal',
      defaultName: 'Caja Principal',
      type: 'CAJA',
      brandType: FinancialBrandType.caja,
      primaryColor: AppColors.teal,
      icon: Icons.point_of_sale_rounded,
    ),

    // POS / Pasarelas
    FinancialBrandPreset(
      key: 'pos_niubiz',
      label: 'Niubiz / Izipay',
      defaultName: 'POS Niubiz',
      type: 'DIGITAL',
      brandType: FinancialBrandType.posNiubiz,
      primaryColor: Color(0xFF475569),
      icon: Icons.credit_card_rounded,
    ),
  ];

  /// Identifica la marca financiera a partir del nombre, tipo o preset explícito.
  static FinancialBrandInfo getBrand({
    required String name,
    String? type,
    String? brandKey,
  }) {
    // Si hay una clave explícita
    if (brandKey != null && brandKey.isNotEmpty && brandKey != 'auto') {
      final found = presets.where((p) => p.key == brandKey).firstOrNull;
      if (found != null) {
        return _fromBrandType(found.brandType, found.label);
      }
    }

    final n = name.trim().toUpperCase();
    final t = (type ?? '').trim().toUpperCase();

    // 1. Yape
    if (n.contains('YAPE')) {
      return _fromBrandType(FinancialBrandType.yape, 'Yape');
    }

    // 2. Plin
    if (n.contains('PLIN')) {
      return _fromBrandType(FinancialBrandType.plin, 'Plin');
    }

    // 3. Tunki / Agora / Bim
    if (n.contains('TUNKI') || n.contains('AGORA') || n.contains('BIM')) {
      return _fromBrandType(FinancialBrandType.tunki, 'Tunki');
    }

    // 4. BCP
    if (n.contains('BCP') ||
        n.contains('CRÉDITO DEL PERÚ') ||
        n.contains('CREDITO DEL PERU')) {
      return _fromBrandType(FinancialBrandType.bcp, 'BCP');
    }

    // 5. BBVA
    if (n.contains('BBVA') || n.contains('CONTINENTAL')) {
      return _fromBrandType(FinancialBrandType.bbva, 'BBVA');
    }

    // 6. Interbank
    if (n.contains('INTERBANK') || n.contains('IBK')) {
      return _fromBrandType(FinancialBrandType.interbank, 'Interbank');
    }

    // 7. Scotiabank
    if (n.contains('SCOTIA') || n.contains('SCOTIABANK')) {
      return _fromBrandType(FinancialBrandType.scotiabank, 'Scotiabank');
    }

    // 8. Banco de la Nación
    if (n.contains('BANCO DE LA NACION') ||
        n.contains('BANCO DE LA NACIÓN') ||
        n.contains('BN') ||
        n.contains('NACION') ||
        n.contains('NACIÓN')) {
      return _fromBrandType(FinancialBrandType.bancoNacion, 'Banco Nación');
    }

    // 9. BanBif
    if (n.contains('BANBIF') || n.contains('BIF')) {
      return _fromBrandType(FinancialBrandType.banbif, 'BanBif');
    }

    // 10. Pichincha
    if (n.contains('PICHINCHA') || n.contains('FINANCIERO')) {
      return _fromBrandType(FinancialBrandType.pichincha, 'Pichincha');
    }

    // 11. Cajas Municipales
    if (n.contains('AREQUIPA')) {
      return _fromBrandType(FinancialBrandType.cajaArequipa, 'Caja Arequipa');
    }
    if (n.contains('HUANCAYO')) {
      return _fromBrandType(FinancialBrandType.cajaHuancayo, 'Caja Huancayo');
    }
    if (n.contains('CUSCO')) {
      return _fromBrandType(FinancialBrandType.cajaCusco, 'Caja Cusco');
    }
    if (n.contains('PIURA')) {
      return _fromBrandType(FinancialBrandType.cajaPiura, 'Caja Piura');
    }
    if (n.contains('TRUJILLO') || n.contains('SULLANA') || n.contains('ICA')) {
      return _fromBrandType(FinancialBrandType.cajaMunicipal, 'Caja Municipal');
    }

    // 12. POS / Pasarelas
    if (n.contains('NIUBIZ') ||
        n.contains('IZIPAY') ||
        n.contains('CULQI') ||
        n.contains('POS') ||
        n.contains('TARJETA') ||
        n.contains('STRIPE') ||
        n.contains('PAYPAL')) {
      return _fromBrandType(FinancialBrandType.posNiubiz, 'POS / Tarjeta');
    }

    // 14. Caja Física / Efectivo
    if (t == 'CAJA' || n.contains('CAJA') || n.contains('EFECTIVO')) {
      return _fromBrandType(FinancialBrandType.caja, 'Caja Física');
    }

    // 15. Digital General
    if (t == 'DIGITAL' || n.contains('BILLETERA')) {
      return _fromBrandType(
        FinancialBrandType.digitalGeneral,
        'Billetera Digital',
      );
    }

    // 16. Banco General
    if (t == 'BANCO' || n.contains('BANCO') || n.contains('CUENTA')) {
      return _fromBrandType(FinancialBrandType.bancoGeneral, 'Cuenta Bancaria');
    }

    return _fromBrandType(FinancialBrandType.otro, 'Otra Cuenta');
  }

  static FinancialBrandInfo _fromBrandType(
    FinancialBrandType type,
    String label,
  ) {
    switch (type) {
      case FinancialBrandType.yape:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.yape,
          label: 'Yape',
          primaryColor: Color(0xFF742284),
          bgColor: Color(0xFFF6E8FA),
          textColor: Color(0xFF742284),
          icon: Icons.qr_code_2_rounded,
          shortCode: 'YAPE',
        );

      case FinancialBrandType.plin:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.plin,
          label: 'Plin',
          primaryColor: Color(0xFF00B4D8),
          bgColor: Color(0xFFE0F7FA),
          textColor: Color(0xFF007791),
          icon: Icons.send_to_mobile_rounded,
          shortCode: 'PLIN',
        );

      case FinancialBrandType.tunki:
      case FinancialBrandType.agora:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.tunki,
          label: 'Tunki / Agora',
          primaryColor: Color(0xFFE91E63),
          bgColor: Color(0xFFFCE4EC),
          textColor: Color(0xFFC2185B),
          icon: Icons.smartphone_rounded,
          shortCode: 'TUNKI',
        );

      case FinancialBrandType.bcp:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.bcp,
          label: 'BCP',
          primaryColor: Color(0xFF002A8F),
          bgColor: Color(0xFFE8EEF9),
          textColor: Color(0xFF002A8F),
          icon: Icons.account_balance_rounded,
          shortCode: 'BCP',
        );

      case FinancialBrandType.bbva:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.bbva,
          label: 'BBVA',
          primaryColor: Color(0xFF004481),
          bgColor: Color(0xFFE6EEF5),
          textColor: Color(0xFF004481),
          icon: Icons.account_balance_rounded,
          shortCode: 'BBVA',
        );

      case FinancialBrandType.interbank:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.interbank,
          label: 'Interbank',
          primaryColor: Color(0xFF009B3A),
          bgColor: Color(0xFFE6F7ED),
          textColor: Color(0xFF007A2E),
          icon: Icons.account_balance_rounded,
          shortCode: 'IBK',
        );

      case FinancialBrandType.scotiabank:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.scotiabank,
          label: 'Scotiabank',
          primaryColor: Color(0xFFEC111A),
          bgColor: Color(0xFFFDE8E9),
          textColor: Color(0xFFC70D15),
          icon: Icons.account_balance_rounded,
          shortCode: 'SCOTIA',
        );

      case FinancialBrandType.bancoNacion:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.bancoNacion,
          label: 'Banco Nación',
          primaryColor: Color(0xFF8A1538),
          bgColor: Color(0xFFF7E6EB),
          textColor: Color(0xFF8A1538),
          icon: Icons.account_balance_rounded,
          shortCode: 'BN',
        );

      case FinancialBrandType.banbif:
      case FinancialBrandType.pichincha:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.banbif,
          label: 'BanBif / Pichincha',
          primaryColor: Color(0xFF0072BC),
          bgColor: Color(0xFFE1F5FE),
          textColor: Color(0xFF01579B),
          icon: Icons.account_balance_rounded,
          shortCode: 'BANBIF',
        );

      case FinancialBrandType.cajaArequipa:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.cajaArequipa,
          label: 'Caja Arequipa',
          primaryColor: Color(0xFFC41230),
          bgColor: Color(0xFFFCE8EB),
          textColor: Color(0xFFC41230),
          icon: Icons.account_balance_rounded,
          shortCode: 'CAQ',
        );

      case FinancialBrandType.cajaHuancayo:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.cajaHuancayo,
          label: 'Caja Huancayo',
          primaryColor: Color(0xFFD32F2F),
          bgColor: Color(0xFFFFEBEE),
          textColor: Color(0xFFC62828),
          icon: Icons.account_balance_rounded,
          shortCode: 'CMAC',
        );

      case FinancialBrandType.cajaCusco:
      case FinancialBrandType.cajaPiura:
      case FinancialBrandType.cajaMunicipal:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.cajaMunicipal,
          label: 'Caja Municipal',
          primaryColor: Color(0xFF1976D2),
          bgColor: Color(0xFFE3F2FD),
          textColor: Color(0xFF0D47A1),
          icon: Icons.account_balance_rounded,
          shortCode: 'CAJA',
        );

      case FinancialBrandType.caja:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.caja,
          label: 'Caja Física',
          primaryColor: AppColors.teal,
          bgColor: Color(0xFFE6FFFA),
          textColor: AppColors.tealDark,
          icon: Icons.point_of_sale_rounded,
          shortCode: 'CAJA',
        );

      case FinancialBrandType.posNiubiz:
      case FinancialBrandType.posIzipay:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.posNiubiz,
          label: 'POS / Tarjeta',
          primaryColor: Color(0xFF475569),
          bgColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF334155),
          icon: Icons.credit_card_rounded,
          shortCode: 'POS',
        );

      case FinancialBrandType.digitalGeneral:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.digitalGeneral,
          label: 'Billetera Digital',
          primaryColor: Color(0xFF8E24AA),
          bgColor: Color(0xFFF3E5F5),
          textColor: Color(0xFF6A1B9A),
          icon: Icons.smartphone_rounded,
          shortCode: 'DIGITAL',
        );

      case FinancialBrandType.bancoGeneral:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.bancoGeneral,
          label: 'Cuenta Bancaria',
          primaryColor: Color(0xFF0288D1),
          bgColor: Color(0xFFE1F5FE),
          textColor: Color(0xFF01579B),
          icon: Icons.account_balance_rounded,
          shortCode: 'BANCO',
        );

      case FinancialBrandType.otro:
        return const FinancialBrandInfo(
          brand: FinancialBrandType.otro,
          label: 'Otra Cuenta',
          primaryColor: AppColors.textSecondary,
          bgColor: Color(0xFFF1F5F9),
          textColor: AppColors.textPrimary,
          icon: Icons.account_balance_wallet_rounded,
          shortCode: 'OTRO',
        );
    }
  }

  /// Retorna el símbolo de moneda formateado a partir del código.
  static String formatCurrencySymbol(String? currencyCode) {
    final c = (currencyCode ?? 'PEN').trim().toUpperCase();
    if (c == 'USD' || c == 'DOL' || c == 'DOLARES' || c == 'DÓLARES') {
      return '\$';
    }
    return 'S/';
  }

  /// Renderiza un avatar / logo oficial o vectorial estilizado para la marca financiera.
  static Widget buildBrandBadge({
    required String name,
    String? type,
    String? brandKey,
    double size = 32,
    bool showBorder = true,
  }) {
    final info = getBrand(name: name, type: type, brandKey: brandKey);

    switch (info.brand) {
      case FinancialBrandType.yape:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/yape.png',
          size: size,
          fit: BoxFit.cover,
          showBorder: false,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
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
          ),
        );

      case FinancialBrandType.plin:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/plin.png',
          size: size,
          fit: BoxFit.cover,
          showBorder: false,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D2D3), Color(0xFF00A8E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * 0.28),
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
          ),
        );

      case FinancialBrandType.bcp:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/bcp.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.10,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Text(
              'BCP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.34,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );

      case FinancialBrandType.bbva:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/bbva.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.12,
          backgroundColor: Colors.white,
          fallback: Container(
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
                fontSize: size * 0.27,
                letterSpacing: -0.3,
              ),
            ),
          ),
        );

      case FinancialBrandType.interbank:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/interbank.png',
          size: size,
          fit: BoxFit.cover,
          backgroundColor: const Color(0xFF009B3A),
          showBorder: false,
          fallback: Container(
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
          ),
        );

      case FinancialBrandType.scotiabank:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/scotiabank.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.10,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.58,
                letterSpacing: -0.5,
              ),
            ),
          ),
        );

      case FinancialBrandType.bancoNacion:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/banco_nacion.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.08,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Text(
              'BN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.38,
                letterSpacing: -0.3,
              ),
            ),
          ),
        );

      case FinancialBrandType.banbif:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/banbif.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.10,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Text(
              'BanBif',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.26,
              ),
            ),
          ),
        );

      case FinancialBrandType.cajaHuancayo:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/caja_huancayo.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.08,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_rounded,
              size: size * 0.52,
              color: Colors.white,
            ),
          ),
        );

      case FinancialBrandType.cajaArequipa:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/caja_arequipa.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.08,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_rounded,
              size: size * 0.52,
              color: Colors.white,
            ),
          ),
        );

      case FinancialBrandType.cajaPiura:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/caja_piura.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.08,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_rounded,
              size: size * 0.52,
              color: Colors.white,
            ),
          ),
        );

      case FinancialBrandType.cajaCusco:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/caja_cusco.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.08,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.account_balance_rounded,
              size: size * 0.52,
              color: Colors.white,
            ),
          ),
        );

      case FinancialBrandType.tunki:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/tunki.png',
          size: size,
          fit: BoxFit.contain,
          padding: size * 0.08,
          backgroundColor: Colors.white,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.smartphone_rounded,
              size: size * 0.52,
              color: Colors.white,
            ),
          ),
        );

      case FinancialBrandType.caja:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/caja_principal.png',
          size: size,
          fit: BoxFit.cover,
          showBorder: false,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(info.icon, size: size * 0.52, color: Colors.white),
          ),
        );

      case FinancialBrandType.posNiubiz:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/pos_niubiz.png',
          size: size,
          fit: BoxFit.cover,
          showBorder: false,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.credit_card_rounded,
              size: size * 0.52,
              color: Colors.white,
            ),
          ),
        );

      case FinancialBrandType.posIzipay:
        return _buildImageBadge(
          assetPath: 'assets/icons/banks/pos_izipay.png',
          size: size,
          fit: BoxFit.cover,
          showBorder: false,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: info.primaryColor,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.credit_card_rounded,
              size: size * 0.52,
              color: Colors.white,
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

  static Widget _buildImageBadge({
    required String assetPath,
    required double size,
    required Widget fallback,
    Color? backgroundColor,
    double padding = 0,
    BoxFit fit = BoxFit.cover,
    bool showBorder = true,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        border:
            showBorder
                ? Border.all(color: const Color(0xFFE2E8F0), width: 0.8)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallback,
          ),
        ),
      ),
    );
  }
}
