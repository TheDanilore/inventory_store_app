import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

class HelpTabsContent {
  static const Color _green = Color(0xFF059669);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _purple = Color(0xFF7C3AED);

  static List<HelpTabModel> buildTabs() => [
    _cajasTab(),
    _posTab(),
    _rolesTab(),
    _invoicingTab(),
    _financesTab(),
    _inventoryTab(),
    _shortcutsTab(),
  ];

  // ── TAB 1: CAJAS ──────────────────────────────────────────────────────────
  static HelpTabModel _cajasTab() {
    const calloutTitle =
        'Arquitectura de Cajas: ¿Puede haber más de una caja por tienda?';
    const calloutBody =
        'Cada Almacén o Tienda física representa la sede central donde vive el inventario. Dentro de esa misma tienda física pueden operar múltiples Cajas o Mostradores (ej: Mostrador 1, Mostrador 2, Caja Rápida, etc.). Cada cajero opera en su respectiva terminal con su propio Turno de Caja independiente.';

    return HelpTabModel(
      label: 'Cajas y Mostradores',
      icon: Icons.point_of_sale_rounded,
      groups: [
        HelpGroupModel(
          items: [
            HelpItemModel(
              '$calloutTitle $calloutBody',
              HelpCallout(
                title: calloutTitle,
                lead: '¡SÍ, TOTALMENTE!',
                content: calloutBody,
                icon: Icons.lightbulb_rounded,
                color: _blue,
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Jerarquía del Sistema',
          subtitle:
              'Comprende la relación entre Tienda (Almacén), Mostrador (Caja) y Turno (Sesión del Cajero)',
          columns: 3,
          items: [
            HelpItemModel(
              'Nivel 1 Tienda Almacén establecimiento sucursal stock compras transferencias',
              HelpHierarchyCard(
                badge: 'NIVEL 1',
                title: 'Tienda / Almacén',
                desc:
                    'Establecimiento o sucursal física. Administra el stock real, las compras recibidas y las transferencias de inventario.',
                icon: Icons.apartment_rounded,
                color: _green,
              ),
            ),
            HelpItemModel(
              'Nivel 2 Caja Mostrador terminal atención cajas activas',
              HelpHierarchyCard(
                badge: 'NIVEL 2',
                title: 'Caja / Mostrador',
                desc:
                    'Terminal físico de atención (ej. Caja 1, Caja 2). Una tienda puede tener 1, 2 o más cajas activas simultáneamente.',
                icon: Icons.computer_rounded,
                color: _blue,
              ),
            ),
            HelpItemModel(
              'Nivel 3 Turno de Caja sesión cajero fondo inicial cobros efectivo digitales arqueo cierre',
              HelpHierarchyCard(
                badge: 'NIVEL 3',
                title: 'Turno de Caja',
                desc:
                    'Sesión de trabajo del cajero con fondo inicial, registro de cobros en efectivo/digitales, arqueo y cierre diario.',
                icon: Icons.access_time_filled_rounded,
                color: _purple,
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Flujo de Vida del Turno de Caja',
          subtitle:
              'Ciclo obligatorio para garantizar cuadre exacto de dinero y cero pérdidas en el negocio',
          items: [
            HelpItemModel(
              'apertura turno fondo base sencillo operaciones cobros yape plin tarjeta egresos retiros arqueo cierre faltante sobrante',
              HelpStepFlow([
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
                  'Al finalizar el horario, se cuenta el dinero físico presente. El sistema compara: Fondo Inicial + Ventas Efectivo − Retiros = Total Esperado. Calcula si existe faltante o sobrante.',
                ),
              ]),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Preguntas frecuentes',
          subtitle: 'Dudas comunes sobre turnos y cajeros',
          items: [
            HelpItemModel(
              'dos cajeros mismo turno misma tienda rotación',
              HelpFaqAccordion(
                '¿Qué pasa si dos cajeros trabajan en el mismo turno o misma tienda?',
                'Lo óptimo es que cada cajero tenga su propio turno abierto en su respectiva caja/mostrador. Si comparten el mismo mostrador por rotación de turno, el cajero saliente debe cerrar su turno con su arqueo y el nuevo cajero debe abrir un nuevo turno con el dinero que recibe.',
              ),
            ),
            HelpItemModel(
              'método de pago efectivo turno abierto seguridad contable',
              HelpFaqAccordion(
                '¿Por qué el método de pago Efectivo solo aparece si hay un turno abierto?',
                'Por seguridad contable. El dinero en efectivo necesita una gaveta física y un responsable activo. Si no hay turno abierto, el sistema impide cobros en efectivo para evitar dinero no trazable.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── TAB 2: POS ────────────────────────────────────────────────────────────
  static HelpTabModel _posTab() {
    const cTitle = 'Filosofía del POS: Velocidad Extrema y Teclado';
    const cBody =
        'El Punto de Venta está optimizado para operar en milisegundos con lectores de código de barras USB/Bluetooth o mediante teclado directo sin necesidad de usar el mouse.';
    return HelpTabModel(
      label: 'Punto de Venta (POS)',
      icon: Icons.storefront_rounded,
      groups: [
        HelpGroupModel(
          items: [
            HelpItemModel(
              '$cTitle $cBody',
              HelpCallout(
                title: cTitle,
                content: cBody,
                icon: Icons.bolt_rounded,
                color: const Color(0xFF047857),
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Flujo de Venta Rápida en 4 Pasos',
          subtitle: 'Cómo realizar una venta completa en menos de 10 segundos',
          items: [
            HelpItemModel(
              'venta rápida carrito productos lector código de barras cliente dni ruc comprobante nota de venta boleta factura efectivo yape plin banco f2 cobrar ticket',
              HelpStepFlow([
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
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Manejo de Pedidos en Borrador (Alt + B)',
          subtitle: 'Ideal para clientes indecisos en la fila',
          columns: 2,
          items: [
            HelpItemModel(
              'guardar carrito borrador alt b cola historial',
              HelpInfoTile(
                icon: Icons.bookmark_added_outlined,
                title: 'Guardar Carrito como Borrador',
                desc:
                    'Si un cliente en la cola necesita agregar más cosas, presiona "Borrador" (Alt + B). El carrito se limpia para atender al siguiente cliente y podrás retomar el pedido pendiente más tarde desde el historial.',
              ),
            ),
            HelpItemModel(
              'limpieza automática campos voucher descuentos operación',
              HelpInfoTile(
                icon: Icons.cleaning_services_rounded,
                title: 'Limpieza Automática de Campos',
                desc:
                    'Al finalizar cada venta, el Nº de operación / voucher y los descuentos se resetean automáticamente para evitar que el siguiente cliente herede datos de la venta anterior.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── TAB 3: ROLES ──────────────────────────────────────────────────────────
  static HelpTabModel _rolesTab() {
    const cTitle = 'Sistema Basado en Permisos Granulares (RBAC)';
    const cBody =
        'En DANILORE ONE los accesos no están atados rígidamente a nombres fijos, sino a una matriz de permisos directos. Puedes definir exactamente qué puede ver o editar cada colaborador.';
    const headers = [
      'Característica',
      'Entorno POS (Cajeros)',
      'Entorno ERP (Administración)',
    ];
    const rows = [
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
    ];

    return HelpTabModel(
      label: 'Roles y Permisos',
      icon: Icons.shield_outlined,
      groups: [
        HelpGroupModel(
          items: [
            HelpItemModel(
              '$cTitle $cBody',
              HelpCallout(
                title: cTitle,
                content: cBody,
                icon: Icons.admin_panel_settings_rounded,
                color: const Color(0xFF6D28D9),
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Acceso Exclusivo al POS vs Acceso al ERP',
          subtitle:
              'Separación de entornos para cajeros y personal administrativo',
          items: [
            HelpItemModel(
              [...headers, ...rows.expand((r) => r)].join(' '),
              HelpComparisonTable(headers: headers, rows: rows),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Matriz de Roles Predefinidos en el Sistema',
          subtitle:
              'Puedes crear nuevos roles o ajustar los existentes en Configuración > Roles',
          columns: 2,
          items: [
            HelpItemModel(
              'administrador admin acceso total monedas sucursales permisos ganancias anular',
              HelpRoleCard(
                role: 'Administrador',
                code: 'admin',
                desc:
                    'Acceso total e irrestricto. Puede configurar monedas, sucursales, asignar permisos, ver ganancias y anular operaciones.',
                color: const Color(0xFFDC2626),
                icon: Icons.shield_rounded,
              ),
            ),
            HelpItemModel(
              'cajero cashier pos turnos cobros tickets mostrador',
              HelpRoleCard(
                role: 'Cajero',
                code: 'cashier',
                desc:
                    'Enfocado en POS. Abre/cierra turnos, registra cobros, emite tickets. Por seguridad, solo ingresa a su mostrador.',
                color: const Color(0xFF0284C7),
                icon: Icons.point_of_sale_rounded,
              ),
            ),
            HelpItemModel(
              'encargado de almacén warehouse keeper inventario recepción órdenes de compra kardex lotes vencimiento',
              HelpRoleCard(
                role: 'Encargado de Almacén',
                code: 'warehouse_keeper',
                desc:
                    'Control de inventario, recepción de órdenes de compra, kardex, registro de lotes y fechas de vencimiento.',
                color: const Color(0xFFD97706),
                icon: Icons.inventory_2_rounded,
              ),
            ),
            HelpItemModel(
              'empleado general employee atención al cliente catálogo precios stock',
              HelpRoleCard(
                role: 'Empleado General',
                code: 'employee',
                desc:
                    'Atención al cliente, consulta de catálogo, precios y stock sin permisos de configuración administrativa.',
                color: const Color(0xFF64748B),
                icon: Icons.person_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── TAB 4: COMPROBANTES ───────────────────────────────────────────────────
  static HelpTabModel _invoicingTab() {
    const cTitle = 'Tipos de Comprobantes Emitidos';
    const cBody =
        'Cada venta genera un comprobante con serie y correlativo auditado. El detalle de la venta desglosa la Base Imponible (Op. Gravada) y el I.G.V. (18%).';
    return HelpTabModel(
      label: 'Comprobantes y SUNAT',
      icon: Icons.receipt_long_rounded,
      groups: [
        HelpGroupModel(
          items: [
            HelpItemModel(
              '$cTitle $cBody',
              HelpCallout(
                title: cTitle,
                content: cBody,
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF0F766E),
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Guía de Comprobantes de Pago',
          subtitle: 'Cuándo utilizar Nota de Venta, Boleta o Factura',
          items: [
            HelpItemModel(
              'nota de venta comprobante interno mostrador descuenta existencias dni ruc',
              HelpDocTypeCard(
                title: 'Nota de Venta',
                series: 'NV01-00000001',
                badge: 'COMPROBANTE INTERNO',
                color: const Color(0xFF047857),
                desc:
                    'Comprobante interno para mostrador. Descuenta existencias del almacén y registra el ingreso a caja sin requerir validación tributaria directa. Ideal para operaciones rápidas al público general.',
                requirements: const [
                  'No requiere DNI ni RUC obligatorio',
                  'Descuenta inventario en tiempo real',
                  'Afecta caja y cuentas financieras',
                ],
              ),
            ),
            HelpItemModel(
              'boleta de venta consumidor final dni igv 18 cliente varios',
              HelpDocTypeCard(
                title: 'Boleta de Venta',
                series: 'B001-00000001',
                badge: 'CONSUMIDOR FINAL',
                color: const Color(0xFF1D4ED8),
                desc:
                    'Comprobante legal para personas naturales. Desglosa Base Imponible e IGV del 18%. Se puede emitir con DNI del comprador o como Cliente Varios.',
                requirements: const [
                  'DNI obligatorio para ventas mayores a montos de ley',
                  'Desglose de IGV 18% incluido en el total',
                ],
              ),
            ),
            HelpItemModel(
              'factura electrónica crédito fiscal ruc razón social dirección fiscal sunat empresas',
              HelpDocTypeCard(
                title: 'Factura Electrónica',
                series: 'F001-00000001',
                badge: 'CRÉDITO FISCAL',
                color: const Color(0xFF7E22CE),
                desc:
                    'Comprobante tributario para empresas. Otorga derecho a crédito fiscal y costo/gasto.',
                requirements: const [
                  'RUC de 11 dígitos válido ante SUNAT',
                  'Razón Social completa',
                  'Dirección Fiscal obligatoria',
                ],
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Nº de Operación / Voucher',
          subtitle:
              'Trazabilidad de transferencias digitales (Yape, Plin, Tarjeta) · campo payment_reference',
          items: [
            HelpItemModel(
              'código de operación voucher yape plin transferencia bancaria detalle del pedido payment_reference',
              HelpInfoTile(
                icon: Icons.tag_rounded,
                title: '¿Por qué es crucial registrar el código de operación?',
                desc:
                    'Al cobrar con Yape o Plin, la app de tu teléfono genera un código numérico (ej. "33333"). Ingresarlo en la caja permite que en Administración y en el Detalle del Pedido se verifique de inmediato si la transferencia bancaria coincide con el pedido físico.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── TAB 5: FINANZAS ───────────────────────────────────────────────────────
  static HelpTabModel _financesTab() {
    return HelpTabModel(
      label: 'Finanzas y Pagos',
      icon: Icons.account_balance_wallet_outlined,
      groups: [
        HelpGroupModel(
          title: 'Cuentas Financieras del Negocio',
          subtitle: 'Configuradas en ERP > Finanzas > Cuentas Financieras',
          items: [
            HelpItemModel(
              'cuenta caja principal efectivo billetes monedas turnos auditorías cuadres',
              HelpInfoTile(
                icon: Icons.payments_rounded,
                title: 'Cuenta Caja Principal (Efectivo)',
                desc:
                    'Representa el dinero físico en billetes y monedas. Está vinculada a los turnos de caja para auditorías y cuadres de fin de día.',
              ),
            ),
            HelpItemModel(
              'cuentas bancarias billeteras digitales bcp bbva interbank yape plin',
              HelpInfoTile(
                icon: Icons.account_balance_rounded,
                title: 'Cuentas Bancarias y Billeteras Digitales',
                desc:
                    'Cuentas de BCP, BBVA, Interbank, Yape y Plin. El dinero de estas ventas no entra a la gaveta física, sino directo a la cuenta de la empresa.',
              ),
            ),
            HelpItemModel(
              'ventas a crédito cuentas por cobrar saldo pendiente amortizaciones abonos deuda',
              HelpInfoTile(
                icon: Icons.handshake_rounded,
                title: 'Ventas a Crédito y Cuentas por Cobrar',
                desc:
                    'Al vender con "CRÉDITO", el pedido se guarda con saldo pendiente (PAID < TOTAL). Desde el detalle del pedido se pueden registrar amortizaciones o abonos parciales hasta liquidar la deuda.',
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Moneda Base del Sistema',
          subtitle: 'Configuración global y tipo de cambio',
          items: [
            HelpItemModel(
              'moneda oficial tipo de cambio soles pen reportes históricos',
              HelpInfoTile(
                icon: Icons.currency_exchange_rounded,
                title: 'Moneda Oficial Congelada en la Venta',
                desc:
                    'El sistema opera en la moneda base configurada en Ajustes (ej. Soles PEN). Cada venta almacena su tipo de cambio (T/C) para asegurar que reportes históricos nunca sufran distorsiones cambiarias.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── TAB 6: INVENTARIO ─────────────────────────────────────────────────────
  static HelpTabModel _inventoryTab() {
    const cTitle = 'Control de Lotes con Fecha de Caducidad (FEFO / FIFO)';
    const cBody =
        'Para farmacias, insumos agrícolas, veterinaria o alimentos, cada producto puede registrar lotes con fecha de vencimiento. El sistema despacha automáticamente primero los lotes con vencimiento más próximo para evitar pérdidas.';
    return HelpTabModel(
      label: 'Stock y Lotes',
      icon: Icons.inventory_2_outlined,
      groups: [
        HelpGroupModel(
          items: [
            HelpItemModel(
              '$cTitle $cBody',
              HelpCallout(
                title: cTitle,
                content: cBody,
                icon: Icons.alarm_rounded,
                color: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        HelpGroupModel(
          title: 'Alertas de Caducidad en el Dashboard',
          subtitle: 'Monitoreo preventivo de mercadería en bodega',
          items: [
            HelpItemModel(
              'alerta crítica preventiva vencer caducidad remate promoción devolución proveedor trazabilidad kardex lote',
              HelpStepFlow(
                [
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
                ],
                colors: const [
                  Color(0xFFDC2626),
                  Color(0xFFD97706),
                  Color(0xFF2563EB),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── TAB 7: ATAJOS ─────────────────────────────────────────────────────────
  static HelpTabModel _shortcutsTab() {
    const pos = [
      ('F2', 'Cobrar pedido actual en el POS'),
      ('Alt + C', 'Buscar o cambiar cliente en el POS'),
      ('Alt + B', 'Guardar venta actual como Borrador'),
      ('Esc', 'Limpiar búsqueda / Cerrar diálogos'),
      ('/', 'Enfocar buscador de productos'),
      ('Ctrl + Enter', 'Confirmar pago en modal de cobro'),
    ];
    const erp = [
      ('Ctrl + K / ⌘ + K', 'Paleta de Comandos Universal (navegación rápida)'),
      ('/', 'Filtrar listados o tablas activas'),
      ('R', 'Recargar métricas en tiempo real'),
      ('1 .. 4', 'Cambiar rango de fechas en Dashboard (Hoy, Sem, Mes, Todo)'),
    ];
    return HelpTabModel(
      label: 'Atajos de Teclado',
      icon: Icons.keyboard_outlined,
      groups: [
        HelpGroupModel(
          title: 'Atajos en el Punto de Venta (POS)',
          subtitle: 'Optimiza tu velocidad de atención en caja',
          columns: 2,
          items: [
            for (final s in pos)
              HelpItemModel('${s.$1} ${s.$2}', HelpShortcutRow(s.$1, s.$2)),
          ],
        ),
        HelpGroupModel(
          title: 'Atajos en el Panel ERP Administrativo',
          subtitle: 'Navegación ágil entre módulos',
          columns: 2,
          items: [
            for (final s in erp)
              HelpItemModel('${s.$1} ${s.$2}', HelpShortcutRow(s.$1, s.$2)),
          ],
        ),
      ],
    );
  }
}
