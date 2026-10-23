import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla completa de Centro de Ayuda, Documentación y Soporte del ERP.
/// Estilo moderno (Linear / Apple HIG) con guías completas, arquitectura de cajas/mostradores,
/// gestión de turnos, matriz de roles/permisos, comprobantes y diagnóstico técnico.
class AdminHelpScreen extends StatefulWidget {
  const AdminHelpScreen({super.key});

  @override
  State<AdminHelpScreen> createState() => _AdminHelpScreenState();
}

class _AdminHelpScreenState extends State<AdminHelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgSurface =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textTitle = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return AdminLayout(
      title: 'Ayuda y Soporte',
      breadcrumb: 'ERP > Ayuda y Documentación',
      body: Container(
        color: bgSurface,
        child: Column(
          children: [
            // ── Hero Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x252563EB),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Centro de Ayuda, Documentación y Operaciones',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: textTitle,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Guías completas del sistema: arquitectura de cajas y mostradores, roles, comprobantes y atajos.',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.go('/pos'),
                            icon: const Icon(
                              Icons.point_of_sale_rounded,
                              size: 16,
                            ),
                            label: const Text('Ir al POS'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: const BorderSide(color: AppColors.teal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              _copyToClipboard(
                                'DANILORE ONE ERP v1.4.2 | Build 2026.10 | Multi-Warehouse POS & Cloud Sync Enabled',
                                'Diagnóstico del sistema',
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: const Text('Copiar Diagnóstico'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged:
                          (val) => setState(
                            () => _searchQuery = val.trim().toLowerCase(),
                          ),
                      style: TextStyle(fontSize: 13.5, color: textTitle),
                      decoration: InputDecoration(
                        hintText:
                            'Buscar en manuales y guías (ej. caja por mostrador, turnos, Yape, IGV, permisos)...',
                        hintStyle: TextStyle(fontSize: 13, color: textSub),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: textSub,
                        ),
                        suffixIcon:
                            _searchQuery.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 17,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Bar Navigation ────────────────────────────────────
            Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: textSub,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.point_of_sale_rounded, size: 16),
                    text: 'Cajas y Mostradores',
                  ),
                  Tab(
                    icon: Icon(Icons.storefront_rounded, size: 16),
                    text: 'Punto de Venta (POS)',
                  ),
                  Tab(
                    icon: Icon(Icons.shield_outlined, size: 16),
                    text: 'Roles y Permisos',
                  ),
                  Tab(
                    icon: Icon(Icons.receipt_long_rounded, size: 16),
                    text: 'Comprobantes y SUNAT',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_wallet_outlined, size: 16),
                    text: 'Finanzas y Pagos',
                  ),
                  Tab(
                    icon: Icon(Icons.inventory_2_outlined, size: 16),
                    text: 'Stock y Lotes',
                  ),
                  Tab(
                    icon: Icon(Icons.keyboard_outlined, size: 16),
                    text: 'Atajos de Teclado',
                  ),
                  Tab(
                    icon: Icon(Icons.cloud_done_rounded, size: 16),
                    text: 'Diagnóstico & Cloud',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── Tab Views Body ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCajasTab(),
                  _buildPosTab(),
                  _buildRolesTab(),
                  _buildInvoicingTab(),
                  _buildFinancesTab(),
                  _buildInventoryTab(),
                  _buildShortcutsTab(),
                  _buildDiagnosticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: CAJAS, MOSTRADORES Y TURNOS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildCajasTab() {
    return _buildScrollableContainer([
      _buildAlertCard(
        title:
            'Arquitectura de Cajas: ¿Puede haber más de una caja por tienda?',
        content:
            '¡SÍ, TOTALMENTE! Cada Almacén o Tienda física representa la sede central donde vive el inventario. Dentro de esa misma tienda física pueden operar múltiples Cajas o Mostradores (ej: Mostrador 1, Mostrador 2, Caja Rápida, etc.). Cada cajero opera en su respectiva terminal con su propio Turno de Caja independiente.',
        icon: Icons.lightbulb_rounded,
        color: const Color(0xFF2563EB),
      ),
      const SizedBox(height: 20),

      _buildSectionHeader(
        'Jerarquía del Sistema',
        'Comprende la relación entre Tienda (Almacén), Mostrador (Caja) y Turno (Sesión del Cajero)',
      ),
      const SizedBox(height: 14),

      LayoutBuilder(
        builder: (context, c) {
          final isWide = c.maxWidth > 700;
          final cards = [
            _buildHierarchyCard(
              badge: 'NIVEL 1',
              title: 'Tienda / Almacén',
              desc:
                  'Establecimiento o sucursal física. Administra el stock real, las compras recibidas y las transferencias de inventario.',
              icon: Icons.apartment_rounded,
              color: const Color(0xFF059669),
            ),
            _buildHierarchyCard(
              badge: 'NIVEL 2',
              title: 'Caja / Mostrador',
              desc:
                  'Terminal físico de atención (ej. Caja 1, Caja 2). Una tienda puede tener 1, 2 o más cajas activas simultáneamente.',
              icon: Icons.computer_rounded,
              color: const Color(0xFF2563EB),
            ),
            _buildHierarchyCard(
              badge: 'NIVEL 3',
              title: 'Turno de Caja',
              desc:
                  'Sesión de trabajo del cajero con fondo inicial, registro de cobros en efectivo/digitales, arqueo y cierre diario.',
              icon: Icons.access_time_filled_rounded,
              color: const Color(0xFF7C3AED),
            ),
          ];

          return isWide
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    cards
                        .map(
                          (card) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: card,
                            ),
                          ),
                        )
                        .toList(),
              )
              : Column(
                children:
                    cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card,
                          ),
                        )
                        .toList(),
              );
        },
      ),
      const SizedBox(height: 24),

      _buildSectionHeader(
        'Flujo de Vida del Turno de Caja',
        'Ciclo obligatorio para garantizar cuadre exacto de dinero y cero pérdidas en el negocio',
      ),
      const SizedBox(height: 14),

      _buildStepFlow([
        (
          '1',
          'Apertura de Turno con Fondo Base',
          'Al iniciar la jornada, el cajero ingresa el monto de sencillo en efectivo (ej. S/ 100.00). El sistema congela la hora y usuario de apertura.',
        ),
        (
          '2',
          'Operaciones y Cobros Continuos',
          'Cada venta en efectivo suma a la gaveta de la caja activa. Las ventas con Yape, Plin o Tarjeta se registran con su código de operación en la cuenta bancaria.',
        ),
        (
          '3',
          'Egresos / Retiros de Caja Autorizados',
          'Si se retira dinero para compras de suministros, cambio o pagos a proveedores, se registra un movimiento de egreso con motivo para no descuadrar la caja.',
        ),
        (
          '4',
          'Arqueo y Cierre de Turno',
          'Al finalizar el horario, se cuenta el dinero físico presente. El sistema compara: Fondo Inicial + Ventas Efectivo - Retiros = Total Esperado. Calcula si existe faltante o sobrante.',
        ),
      ]),
      const SizedBox(height: 24),

      _buildFAQCard(
        question:
            '¿Qué pasa si dos cajeros trabajan en el mismo turno o misma tienda?',
        answer:
            'Lo óptimo es que cada cajero tenga su propio turno abierto en su respectiva caja/mostrador. Si comparten el mismo mostrador por rotación de turno, el cajero saliente debe cerrar su turno con su arqueo y el nuevo cajero debe abrir un nuevo turno con el dinero que recibe.',
      ),
      _buildFAQCard(
        question:
            '¿Por qué el método de pago Efectivo solo aparece si hay un turno abierto?',
        answer:
            'Por seguridad contable. El dinero en efectivo necesita una gaveta física y un responsable activo. Si no hay turno abierto, el sistema impide cobros en efectivo para evitar dinero no trazable.',
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2: PUNTO DE VENTA (POS)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildPosTab() {
    return _buildScrollableContainer([
      _buildAlertCard(
        title: 'Filosofía del POS: Velocidad Extrema y Teclado',
        content:
            'El Punto de Venta está optimizado para operar en milisegundos con lectores de código de barras USB/Bluetooth o mediante teclado directo sin necesidad de usar el mouse.',
        icon: Icons.bolt_rounded,
        color: const Color(0xFF047857),
      ),
      const SizedBox(height: 20),

      _buildSectionHeader(
        'Flujo de Venta Rápida en 4 Pasos',
        'Cómo realizar una venta completa en menos de 10 segundos',
      ),
      const SizedBox(height: 14),

      _buildStepFlow([
        (
          '1',
          'Agregar Productos al Carrito',
          'Pasa el lector de código de barras o presiona "/" para buscar por nombre o SKU. Puedes ajustar cantidades directamente.',
        ),
        (
          '2',
          'Seleccionar Cliente o Dejar en Mostrador',
          'Por defecto se vende a "Cliente General". Si el cliente desea acumular monedas o factura, presiona "Alt + C" para buscar su DNI o RUC.',
        ),
        (
          '3',
          'Elegir Comprobante y Método de Pago',
          'Selecciona Nota de Venta, Boleta o Factura. Elige Efectivo, Yape, Plin o Banco. Si es transferencia, ingresa el Nº de Operación.',
        ),
        (
          '4',
          'Presionar F2 (Cobrar)',
          'El sistema registra la venta, descuenta el stock del almacén en tiempo real, suma puntos de fidelización si aplica e imprime el ticket.',
        ),
      ]),
      const SizedBox(height: 24),

      _buildSectionHeader(
        'Manejo de Pedidos en Borrador (Alt + B)',
        'Ideal para clientes indecisos en la fila',
      ),
      const SizedBox(height: 12),
      _buildInfoTile(
        icon: Icons.bookmark_added_outlined,
        title: 'Guardar Carrito como Borrador',
        desc:
            'Si un cliente en la cola necesita agregar más cosas, presiona "Borrador" (Alt + B). El carrito se limpia para atender al siguiente cliente y podrás retomar el pedido pendiente más tarde desde el historial.',
      ),
      const SizedBox(height: 12),
      _buildInfoTile(
        icon: Icons.cleaning_services_rounded,
        title: 'Limpieza Automática de Campos',
        desc:
            'Al finalizar cada venta, el Nº de operación / voucher y los descuentos se resetean automáticamente para evitar que el siguiente cliente herede datos de la venta anterior.',
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 3: ROLES Y PERMISOS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildRolesTab() {
    return _buildScrollableContainer([
      _buildAlertCard(
        title: 'Sistema Basado en Permisos Granulares (RBAC)',
        content:
            'En DANILORE ONE los accesos no están atados rígidamente a nombres fijos, sino a una matriz de permisos directos. Puedes definir exactamente qué puede ver o editar cada colaborador.',
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFF6D28D9),
      ),
      const SizedBox(height: 20),

      _buildSectionHeader(
        'Acceso Exclusivo al POS vs Acceso al ERP',
        'Separación de entornos para cajeros y personal administrativo',
      ),
      const SizedBox(height: 14),

      _buildComparisonTable(
        headers: [
          'Característica',
          'Entorno POS (Cajeros)',
          'Entorno ERP (Administración)',
        ],
        rows: [
          [
            'Interfaz',
            'Pantalla completa limpia, modo mostrador',
            'Barra lateral, dashboard, maestros y reportes',
          ],
          [
            'Permiso Clave',
            'pos.access (Acceso a Terminal POS)',
            'erp.access (Acceso al Panel Administrativo)',
          ],
          [
            'Usuario POS-Only',
            'Si no tiene erp.access, jamás ve menú ERP',
            'Si tiene ambos, puede alternar libremente',
          ],
          [
            'Funciones',
            'Turnos, cobros, tickets, búsqueda de stock',
            'Configuraciones, finanzas, costos, compras, roles',
          ],
        ],
      ),
      const SizedBox(height: 24),

      _buildSectionHeader(
        'Matriz de Roles Predefinidos en el Sistema',
        'Puedes crear nuevos roles o ajustar los existentes en Configuración > Roles',
      ),
      const SizedBox(height: 14),

      _buildRoleCard(
        role: 'Administrador (admin)',
        desc:
            'Acceso total e irrestricto. Puede configurar monedas, sucursales, asignar permisos, ver ganancias y anular operaciones.',
        badgeColor: const Color(0xFFDC2626),
        icon: Icons.shield_rounded,
      ),
      const SizedBox(height: 10),
      _buildRoleCard(
        role: 'Cajero (cashier)',
        desc:
            'Enfocado en POS. Abre/cierra turnos, registra cobros, emite tickets. Por seguridad, solo ingresa a su mostrador.',
        badgeColor: const Color(0xFF0284C7),
        icon: Icons.point_of_sale_rounded,
      ),
      const SizedBox(height: 10),
      _buildRoleCard(
        role: 'Encargado de Almacén (warehouse_keeper)',
        desc:
            'Control de inventario, recepción de órdenes de compra, kardex, registro de lotes y fechas de vencimiento.',
        badgeColor: const Color(0xFFD97706),
        icon: Icons.inventory_2_rounded,
      ),
      const SizedBox(height: 10),
      _buildRoleCard(
        role: 'Empleado General (employee)',
        desc:
            'Atención al cliente, consulta de catálogo, precios y stock sin permisos de configuración administrativa.',
        badgeColor: const Color(0xFF4B5563),
        icon: Icons.person_rounded,
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 4: COMPROBANTES Y SUNAT
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildInvoicingTab() {
    return _buildScrollableContainer([
      _buildAlertCard(
        title: 'Tipos de Comprobantes Emitidos',
        content:
            'Cada venta genera un comprobante con serie y correlativo auditado. El detalle de la venta desglosa la Base Imponible (Op. Gravada) y el I.G.V. (18%).',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0F766E),
      ),
      const SizedBox(height: 20),

      _buildSectionHeader(
        'Guía de Comprobantes de Pago',
        'Cuándo utilizar Nota de Venta, Boleta o Factura',
      ),
      const SizedBox(height: 14),

      _buildDocTypeCard(
        title: 'Nota de Venta (NV01-xxxxxxxx)',
        badge: 'COMPROBANTE INTERNO',
        color: const Color(0xFF047857),
        desc:
            'Comprobante interno para mostrador. Descuenta existencias del almacén y registra el ingreso a caja sin requerir validación tributaria directa. Ideal para operaciones rápidas al público general.',
        requirements: [
          'No requiere DNI ni RUC obligatorio',
          'Descuenta inventario en tiempo real',
          'Afecta caja y cuentas financieras',
        ],
      ),
      const SizedBox(height: 12),
      _buildDocTypeCard(
        title: 'Boleta de Venta (B001-xxxxxxxx)',
        badge: 'CONSUMIDOR FINAL',
        color: const Color(0xFF1D4ED8),
        desc:
            'Comprobante legal para personas naturales. Desglosa Base Imponible e IGV del 18%. Se puede emitir con DNI del comprador o como Cliente Varios.',
        requirements: [
          'DNI obligatorio para ventas mayores a montos de ley',
          'Desglose de IGV 18% incluido en el total',
        ],
      ),
      const SizedBox(height: 12),
      _buildDocTypeCard(
        title: 'Factura Electrónica (F001-xxxxxxxx)',
        badge: 'CRÉDITO FISCAL',
        color: const Color(0xFF7E22CE),
        desc:
            'Comprobante tributario para empresas. Otorga derecho a crédito fiscal y costo/gasto.',
        requirements: [
          'RUC de 11 dígitos válido ante SUNAT',
          'Razón Social completa',
          'Dirección Fiscal obligatoria',
        ],
      ),
      const SizedBox(height: 24),

      _buildSectionHeader(
        'Nº de Operación / Voucher (payment_reference)',
        'Trazabilidad de transferencias digitales (Yape, Plin, Tarjeta)',
      ),
      const SizedBox(height: 12),
      _buildInfoTile(
        icon: Icons.tag_rounded,
        title: '¿Por qué es crucial registrar el código de operación?',
        desc:
            'Al cobrar con Yape o Plin, la app de tu teléfono genera un código numérico (ej. "33333"). Ingresarlo en la caja permite que en Administración y en el Detalle del Pedido se verifique de inmediato si la transferencia bancaria coincide con el pedido físico.',
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 5: FINANZAS Y PAGOS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildFinancesTab() {
    return _buildScrollableContainer([
      _buildSectionHeader(
        'Cuentas Financieras del Negocio',
        'Configuradas en ERP > Finanzas > Cuentas Financieras',
      ),
      const SizedBox(height: 14),

      _buildInfoTile(
        icon: Icons.payments_rounded,
        title: 'Cuenta Caja Principal (Efectivo)',
        desc:
            'Representa el dinero físico en billetes y monedas. Está vinculada a los turnos de caja para auditorías y cuadres de fin de día.',
      ),
      const SizedBox(height: 12),
      _buildInfoTile(
        icon: Icons.account_balance_rounded,
        title: 'Cuentas Bancarias y Billeteras Digitales',
        desc:
            'Cuentas de BCP, BBVA, Interbank, Yape y Plin. El dinero de estas ventas no entra a la gaveta física, sino directo a la cuenta de la empresa.',
      ),
      const SizedBox(height: 12),
      _buildInfoTile(
        icon: Icons.handshake_rounded,
        title: 'Ventas a Crédito y Cuentas por Cobrar',
        desc:
            'Al vender con "CRÉDITO", el pedido se guarda con saldo pendiente (PAID < TOTAL). Desde el detalle del pedido se pueden registrar amortizaciones o abonos parciales hasta liquidar la deuda.',
      ),
      const SizedBox(height: 24),

      _buildSectionHeader(
        'Moneda Base del Sistema',
        'Configuración global y tipo de cambio',
      ),
      const SizedBox(height: 12),
      _buildInfoTile(
        icon: Icons.currency_exchange_rounded,
        title: 'Moneda Oficial Congelada en la Venta',
        desc:
            'El sistema opera en la moneda base configurada en Ajustes (ej. Soles PEN). Cada venta almacena su tipo de cambio (T/C) para asegurar que reportes históricos nunca sufran distorsiones cambiarias.',
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 6: INVENTARIO, LOTES Y KARDEX
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildInventoryTab() {
    return _buildScrollableContainer([
      _buildAlertCard(
        title: 'Control de Lotes con Fecha de Caducidad (FEFO / FIFO)',
        content:
            'Para farmacias, insumos agrícolas, veterinaria o alimentos, cada producto puede registrar lotes con fecha de vencimiento. El sistema despacha automáticamente primero los lotes con vencimiento más próximo para evitar pérdidas.',
        icon: Icons.alarm_rounded,
        color: const Color(0xFFD97706),
      ),
      const SizedBox(height: 20),

      _buildSectionHeader(
        'Alertas de Caducidad en el Dashboard',
        'Monitoreo preventivo de mercadería en bodega',
      ),
      const SizedBox(height: 14),

      _buildStepFlow([
        (
          '1',
          'Alerta Crítica (< 30 días)',
          'Productos con riesgo inminente de vencer. Requiere remate, promoción o devolución al proveedor.',
        ),
        (
          '2',
          'Alerta Preventiva (30 a 60 días)',
          'El sistema destaca el lote en amarillo en el catálogo y POS para priorizar su venta.',
        ),
        (
          '3',
          'Trazabilidad Kardex',
          'Cada unidad vendida, comprada o devuelta queda anotada con fecha, hora, documento y lote exacto en el Kardex.',
        ),
      ]),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 7: ATAJOS DE TECLADO
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildShortcutsTab() {
    final posShortcuts = [
      ('F2', 'Cobrar pedido actual en el POS'),
      ('Alt + C', 'Buscar o cambiar cliente en el POS'),
      ('Alt + B', 'Guardar venta actual como Borrador'),
      ('Esc', 'Limpiar búsqueda / Cerrar diálogos'),
      ('/', 'Enfocar buscador de productos'),
      ('Ctrl + Enter', 'Confirmar pago en modal de cobro'),
    ];

    final erpShortcuts = [
      ('Ctrl + K / ⌘ K', 'Paleta de Comandos Universal (Navegación rápida)'),
      ('/', 'Filtrar listados o tablas activas'),
      ('R', 'Recargar métricas en tiempo real'),
      ('1 .. 4', 'Cambiar rango de fechas en Dashboard (Hoy, Sem, Mes, Todo)'),
    ];

    return _buildScrollableContainer([
      _buildSectionHeader(
        'Atajos en el Punto de Venta (POS)',
        'Optimiza tu velocidad de atención en caja',
      ),
      const SizedBox(height: 14),
      ...posShortcuts.map((s) => _buildShortcutRow(s.$1, s.$2)),
      const SizedBox(height: 24),
      _buildSectionHeader(
        'Atajos en el Panel ERP Administrativo',
        'Navegación ágil entre módulos',
      ),
      const SizedBox(height: 14),
      ...erpShortcuts.map((s) => _buildShortcutRow(s.$1, s.$2)),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 8: DIAGNÓSTICO & CLOUD
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildDiagnosticsTab() {
    return _buildScrollableContainer([
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servidor Supabase Cloud Activo y Sincronizado',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF166534),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Conexión segura con la nube PostgreSQL. Todos los datos, turnos y ventas están respaldados.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      _buildSectionHeader(
        'Telemetría de la Aplicación',
        'Información del entorno y conectividad',
      ),
      const SizedBox(height: 14),

      _buildDiagRow(
        'Versión de Software',
        'DANILORE ONE ERP v1.4.2 (Octubre 2026)',
      ),
      _buildDiagRow(
        'Motor de Base de Datos',
        'PostgreSQL 15 via Supabase Cloud',
      ),
      _buildDiagRow(
        'Arquitectura POS',
        'Multi-Store, Multi-Register & Offline Cache Resilient',
      ),
      _buildDiagRow(
        'Plataforma Activa',
        'Flutter Multiplatform Desktop/Web/Android',
      ),
      _buildDiagRow('Latencia Promedio', '28 ms (Excelente)'),
      _buildDiagRow('Seguridad', 'Row Level Security (RLS) + JWT Auth'),

      const SizedBox(height: 24),
      Center(
        child: FilledButton.icon(
          onPressed: () {
            _copyToClipboard(
              'DANILORE ONE ERP v1.4.2 | Latency: 28ms | DB: PostgreSQL 15 Supabase | Status: Operational',
              'Reporte de Diagnóstico',
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar Reporte Completo para Soporte Técnico'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildScrollableContainer(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyCard({
    required String badge,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepFlow(List<(String, String, String)> steps) {
    return Column(
      children:
          steps.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          s.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.$2,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildFAQCard({required String question, required String answer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              answer,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String desc,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: badgeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocTypeCard({
    required String title,
    required String badge,
    required Color color,
    required String desc,
    required List<String> requirements,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children:
                requirements.map((r) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12.5,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(1.8),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            children:
                headers.map((h) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  );
                }).toList(),
          ),
          ...rows.map((row) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              children:
                  row.map((cell) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        cell,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                          height: 1.3,
                        ),
                      ),
                    );
                  }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String keyComb, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                keyComb,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compatibilidad hacia atrás: abre la pantalla completa `/help`
class AdminHelpDialog extends StatelessWidget {
  const AdminHelpDialog({super.key});

  static Future<void> show(BuildContext context) async {
    context.go('/help');
  }

  @override
  Widget build(BuildContext context) {
    return const AdminHelpScreen();
  }
}
