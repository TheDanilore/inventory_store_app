import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/mockups/dashboard_widget_mockups.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/models/dashboard_widget_item.dart';

/// Catálogo centralizado y memoizado de todos los widgets disponibles en el Dashboard.
/// Evita la re-instanciación de objetos de previsualización en cada frame de renderizado.
class DashboardWidgetsCatalog {
  static const List<String> categories = [
    'Todos',
    '#Rendimiento',
    '#Finanzas',
    '#Operaciones',
    '#Estrategia',
    '#InteligenciaArtificial',
    '#Inventario',
  ];

  static const List<DashboardWidgetItem> items = [
    DashboardWidgetItem(
      id: 'kpi_strip',
      title: 'Métricas Principales (KPIs)',
      description:
          'Métricas globales de ventas, ticket medio, inventario y utilidad bruta.',
      categoryTag: '#Rendimiento',
      previewMockup: DashboardKpiMockup(),
    ),
    DashboardWidgetItem(
      id: 'profit_spline',
      title: 'Curva de Utilidad y Ventas',
      description:
          'Gráfico de curva continua (Spline) con trayectoria de ganancias netas.',
      categoryTag: '#Finanzas',
      previewMockup: DashboardSplineMockup(),
    ),
    DashboardWidgetItem(
      id: 'best_sellers',
      title: 'Productos de Mayor Rotación',
      description:
          'Artículos con más unidades despachadas y rendimiento financiero por SKU.',
      categoryTag: '#Operaciones',
      previewMockup: DashboardBestSellersMockup(),
    ),
    DashboardWidgetItem(
      id: 'customer_segments',
      title: 'Segmentación de Clientes',
      description:
          'Canales de compradores principales (Minoristas, Distribuidores y Mayoristas).',
      categoryTag: '#Estrategia',
      previewMockup: DashboardCustomersMockup(),
    ),
    DashboardWidgetItem(
      id: 'weekly_activity',
      title: 'Días de Mayor Actividad',
      description:
          'Histograma semanal con picos de mayor demanda y frecuencia comercial.',
      categoryTag: '#Operaciones',
      previewMockup: DashboardWeeklyActivityMockup(),
    ),
    DashboardWidgetItem(
      id: 'radial_goal',
      title: 'Meta Financiera de Ahorro',
      description:
          'Indicador radial porcentual con progreso hacia la meta mensual de la tienda.',
      categoryTag: '#Finanzas',
      previewMockup: DashboardRadialGoalMockup(),
    ),
    DashboardWidgetItem(
      id: 'ai_assistant',
      title: 'Asistente IA Predictivo',
      description:
          'Predicciones automáticas, alertas de quiebre de stock y consultas inteligentes.',
      categoryTag: '#InteligenciaArtificial',
      previewMockup: DashboardAiAssistantMockup(),
      isDefaultVisible: false,
      isComingSoon: true,
    ),
    DashboardWidgetItem(
      id: 'expiring_batches',
      title: 'Lotes Críticos por Vencer',
      description:
          'Control preventivo de mercancía perecible en fecha de riesgo FEFO.',
      categoryTag: '#Inventario',
      previewMockup: DashboardExpiringBatchesMockup(),
    ),
  ];
}
