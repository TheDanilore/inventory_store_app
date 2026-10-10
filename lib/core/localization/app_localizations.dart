import 'package:flutter/material.dart';

/// Clase central de traducciones e internacionalización (i18n) para el ERP.
/// Soporta Español (es), English (en), Português (pt) y Quechua / Runasimi (qu).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('es'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('es'),
    Locale('en'),
    Locale('pt'),
    Locale('qu'),
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    // 🇪🇸 ESPAÑOL
    'es': {
      // General & Navegación
      'app_title': 'Danilore One',
      'dashboard': 'Dashboard',
      'catalog': 'Catálogo',
      'inventory': 'Inventario',
      'pos': 'Punto de Venta (POS)',
      'customers': 'Clientes',
      'finance': 'Finanzas',
      'profile': 'Mi Perfil',
      'settings': 'Configuración',
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'edit': 'Editar',
      'delete': 'Eliminar',
      'export': 'Exportar',
      'add': 'Añadir',
      'close': 'Cerrar',
      'loading': 'Cargando...',
      'error': 'Error inesperado',
      'success': 'Operación exitosa',
      'search': 'Buscar...',

      // Saludos Agronómicos
      'greeting_morning': 'Buenos días',
      'greeting_afternoon': 'Buenas tardes',
      'greeting_evening': 'Buenas noches',
      'greeting_sub_morning': 'Jornada Matutina · Riego & Despacho',
      'greeting_sub_afternoon': 'Jornada Vespertina · Control & Ventas',
      'greeting_sub_evening': 'Cierre de Almacén · Inventario Seguro',
      'greeting_agro_desc': 'Monitoreo fitosanitario activo · Control de inventarios y rotación FEFO.',

      // KPIs y Métricas
      'total_sales': 'Ventas Totales',
      'average_ticket': 'Ticket Promedio',
      'total_stock': 'Stock Total',
      'gross_profit': 'Ganancia Bruta',
      'orders_in_period': 'órdenes en período',
      'optimal_stock': 'Óptimo',
      'stock_alerts': 'alertas',
      'top_rotation_products': 'Productos con Mayor Rotación',
      'top_rotation_desc': 'Artículos más despachados y rendimiento financiero',
      'top_customers': 'Clientes que más compran',
      'weekly_activity': 'Actividad Semanal',
      'financial_goal': 'Meta Financiera de Ahorro',

      // Lotes Críticos FEFO
      'fefo_title': 'Lotes Críticos por Vencer (FEFO)',
      'fefo_desc': 'Control preventivo de caducidad en almacén',
      'fefo_healthy_title': 'Salud Fitosanitaria Óptima',
      'fefo_healthy_desc': 'No hay lotes que expiren en los próximos 30 días. Tu stock de semillas, fertilizantes y agroquímicos está vigente.',
      'fefo_badge_valid': '✓ 100% Vigente',
      'manage_batches': 'Gestionar lotes y almacenes',

      // Perfil & Idioma
      'personal_info': 'Información Personal',
      'system_language': 'Idioma del Sistema',
      'system_language_desc': 'Selecciona el idioma para toda la plataforma ERP',
      'change_avatar': 'Cambiar Avatar',
      'avatar_agronomic_title': 'Avatares Agrícolas Predeterminados',
      'avatar_custom_title': 'Foto Personalizada',
      'upload_photo': 'Subir Foto',
      'take_photo': 'Tomar Foto',
      'choose_gallery': 'Seleccionar de Galería',
      'remove_photo': 'Restablecer Iniciales',
      'role_agronomo': 'Ingeniero Agrónomo',
      'role_almacen': 'Operador de Almacén',
      'role_campo': 'Técnico de Campo',
      'role_productora': 'Productora Agrícola',
      'role_calidad': 'Supervisora de Calidad',
      'role_ventas': 'Asesor Comercial',
    },

    // 🇺🇸 ENGLISH
    'en': {
      'app_title': 'Danilore One',
      'dashboard': 'Dashboard',
      'catalog': 'Catalog',
      'inventory': 'Inventory',
      'pos': 'Point of Sale (POS)',
      'customers': 'Customers',
      'finance': 'Finance',
      'profile': 'My Profile',
      'settings': 'Settings',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',
      'delete': 'Delete',
      'export': 'Export',
      'add': 'Add',
      'close': 'Close',
      'loading': 'Loading...',
      'error': 'Unexpected error',
      'success': 'Successful operation',
      'search': 'Search...',

      'greeting_morning': 'Good morning',
      'greeting_afternoon': 'Good afternoon',
      'greeting_evening': 'Good evening',
      'greeting_sub_morning': 'Morning Shift · Irrigation & Dispatch',
      'greeting_sub_afternoon': 'Afternoon Shift · Monitoring & Sales',
      'greeting_sub_evening': 'Warehouse Close · Secured Inventory',
      'greeting_agro_desc': 'Active phytosanitary monitoring · Inventory control and FEFO rotation.',

      'total_sales': 'Total Sales',
      'average_ticket': 'Average Ticket',
      'total_stock': 'Total Stock',
      'gross_profit': 'Gross Profit',
      'orders_in_period': 'orders in period',
      'optimal_stock': 'Optimal',
      'stock_alerts': 'alerts',
      'top_rotation_products': 'High Turnover Products',
      'top_rotation_desc': 'Most dispatched items and financial performance',
      'top_customers': 'Top Buying Customers',
      'weekly_activity': 'Weekly Activity',
      'financial_goal': 'Financial Savings Goal',

      'fefo_title': 'Expiring Critical Batches (FEFO)',
      'fefo_desc': 'Preventive expiration monitoring in warehouse',
      'fefo_healthy_title': 'Optimal Phytosanitary Health',
      'fefo_healthy_desc': 'No batches expiring in the next 30 days. All seeds, fertilizers and agrochemicals are up to date.',
      'fefo_badge_valid': '✓ 100% Up to Date',
      'manage_batches': 'Manage batches & warehouses',

      'personal_info': 'Personal Information',
      'system_language': 'System Language',
      'system_language_desc': 'Choose the display language for the whole ERP',
      'change_avatar': 'Change Avatar',
      'avatar_agronomic_title': 'Agricultural Preset Avatars',
      'avatar_custom_title': 'Custom Photo',
      'upload_photo': 'Upload Photo',
      'take_photo': 'Take Photo',
      'choose_gallery': 'Choose from Gallery',
      'remove_photo': 'Reset to Initials',
      'role_agronomo': 'Agronomist Engineer',
      'role_almacen': 'Warehouse Operator',
      'role_campo': 'Field Technician',
      'role_productora': 'Agricultural Producer',
      'role_calidad': 'Quality Supervisor',
      'role_ventas': 'Sales Consultant',
    },

    // 🇧🇷 PORTUGUÊS
    'pt': {
      'app_title': 'Danilore One',
      'dashboard': 'Painel',
      'catalog': 'Catálogo',
      'inventory': 'Estoque',
      'pos': 'Ponto de Venda (PDV)',
      'customers': 'Clientes',
      'finance': 'Finanças',
      'profile': 'Meu Perfil',
      'settings': 'Configurações',
      'save': 'Salvar',
      'cancel': 'Cancelar',
      'edit': 'Editar',
      'delete': 'Excluir',
      'export': 'Exportar',
      'add': 'Adicionar',
      'close': 'Fechar',
      'loading': 'Carregando...',
      'error': 'Erro inesperado',
      'success': 'Operação concluída',
      'search': 'Buscar...',

      'greeting_morning': 'Bom dia',
      'greeting_afternoon': 'Boa tarde',
      'greeting_evening': 'Boa noite',
      'greeting_sub_morning': 'Turno Matutino · Irrigação & Expedição',
      'greeting_sub_afternoon': 'Turno Vespertino · Controle & Vendas',
      'greeting_sub_evening': 'Fechamento de Armazém · Estoque Seguro',
      'greeting_agro_desc': 'Monitoramento fitossanitário ativo · Controle de estoque e rotação FEFO.',

      'total_sales': 'Vendas Totais',
      'average_ticket': 'Ticket Médio',
      'total_stock': 'Estoque Total',
      'gross_profit': 'Lucro Bruto',
      'orders_in_period': 'pedidos no período',
      'optimal_stock': 'Ótimo',
      'stock_alerts': 'alertas',
      'top_rotation_products': 'Produtos de Alta Rotatividade',
      'top_rotation_desc': 'Itens mais expedidos e desempenho financeiro',
      'top_customers': 'Clientes Principais',
      'weekly_activity': 'Atividade Semanal',
      'financial_goal': 'Meta Financeira de Poupança',

      'fefo_title': 'Lotes Críticos a Vencer (FEFO)',
      'fefo_desc': 'Controle preventivo de validade em armazém',
      'fefo_healthy_title': 'Saúde Fitossanitária Ótima',
      'fefo_healthy_desc': 'Nenhum lote com validade nos próximos 30 dias. Sementes e fertilizantes em dia.',
      'fefo_badge_valid': '✓ 100% Válido',
      'manage_batches': 'Gerenciar lotes e armazéns',

      'personal_info': 'Informações Pessoais',
      'system_language': 'Idioma do Sistema',
      'system_language_desc': 'Selecione o idioma para todo o sistema ERP',
      'change_avatar': 'Alterar Avatar',
      'avatar_agronomic_title': 'Avatares Agrícolas Predefinidos',
      'avatar_custom_title': 'Foto Personalizada',
      'upload_photo': 'Enviar Foto',
      'take_photo': 'Tirar Foto',
      'choose_gallery': 'Selecionar da Galeria',
      'remove_photo': 'Restaurar Iniciais',
      'role_agronomo': 'Engenheiro Agrônomo',
      'role_almacen': 'Operador de Armazém',
      'role_campo': 'Técnico de Campo',
      'role_productora': 'Produtora Agrícola',
      'role_calidad': 'Supervisora de Qualidade',
      'role_ventas': 'Consultor Comercial',
    },

    // 🇵🇪 RUNASIMI / QUECHUA (Qusqu-Qullaw)
    'qu': {
      'app_title': 'Danilore One',
      'dashboard': 'Qhawana Pampa',
      'catalog': 'Kaqkuna Qillqa',
      'inventory': 'Taqisqa Kaqkuna',
      'pos': 'Rantinakuy (POS)',
      'customers': 'Rantiqkuna',
      'finance': 'Qullqi Kamachiy',
      'profile': 'Ñuqaq Kawsayniy',
      'settings': 'Allichaykuna',
      'save': 'Waqaychay',
      'cancel': 'Tatichiy',
      'edit': 'Allinchay',
      'delete': 'Pichay',
      'export': 'Lluqsichiy',
      'add': 'Yapapay',
      'close': 'Wisq\'ay',
      'loading': 'Suyay...',
      'error': 'Pantasqa kachkan',
      'success': 'Allin ruwasqa',
      'search': 'Maskhay...',

      'greeting_morning': 'Allin p\'unchay',
      'greeting_afternoon': 'Allin sukha',
      'greeting_evening': 'Allin tuta',
      'greeting_sub_morning': 'Paqarin Llamk\'ay · Qarpay & Qhatuy',
      'greeting_sub_afternoon': 'Sukha Llamk\'ay · Qillqay & Rantiy',
      'greeting_sub_evening': 'Taqi Wisq\'ay · Allin Waqaychasqa',
      'greeting_agro_desc': 'Chakra qhaway purichkan · Taqisqa kaqkuna FEFOwan kuyuchisqa.',

      'total_sales': 'Tukuy Rantikusqa',
      'average_ticket': 'Chawpi Rantiy',
      'total_stock': 'Tukuy Taqisqa',
      'gross_profit': 'Llapan Chaskisqa',
      'orders_in_period': 'rantiykuna kay killapi',
      'optimal_stock': 'Allinlla',
      'stock_alerts': 'willaykuna',
      'top_rotation_products': 'Aswan Kuyusqa Kaqkuna',
      'top_rotation_desc': 'Aswan mañamusqa wanukuna chaymanta qullqi kallpa',
      'top_customers': 'Aswan Rantiq Masikuna',
      'weekly_activity': 'Qanchischaw Llamk\'ay',
      'financial_goal': 'Qullqi Taqiy Yuyaykuy',

      'fefo_title': 'Tukuypaq Q\'upachakuq Lote (FEFO)',
      'fefo_desc': 'Taqipi ama q\'upanapaq ñawpaq qhaway',
      'fefo_healthy_title': 'Tukuy Chakra Allinlla Kachkan',
      'fefo_healthy_desc': 'Manan kanchu kinsa chunka p\'unchawpi tukuq mujukuna wanukunapas. Tukuy kawsaykuna allinlla kachkan.',
      'fefo_badge_valid': '✓ 100% Allinlla',
      'manage_batches': 'Lotekunata taqikunatapas qhaway',

      'personal_info': 'Kikinmanta Willay',
      'system_language': 'Llika Simi',
      'system_language_desc': 'Llapan ERP llikaqta siminta akllay',
      'change_avatar': 'Rikch\'ay Tukuy',
      'avatar_agronomic_title': 'Chakra Llamk\'aq Rikch\'aykuna',
      'avatar_custom_title': 'Kikin Fotoyki',
      'upload_photo': 'Fotota churay',
      'take_photo': 'Fotota hap\'iy',
      'choose_gallery': 'Waqaychasqamanta akllay',
      'remove_photo': 'Qallariy qillqaman kutiy',
      'role_agronomo': 'Chakra Kamachiq Ingeniero',
      'role_almacen': 'Taqi Kamachiq',
      'role_campo': 'Chakra Qhawaq Técnico',
      'role_productora': 'Chakra Mama Productora',
      'role_calidad': 'Allin Kaq Qhawaq',
      'role_ventas': 'Qhatuq Yachachiq',
    },
  };

  String translate(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['es']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['es', 'en', 'pt', 'qu'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).translate(key);
}
