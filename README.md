# Danilore One ERP & POS

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Database%20%26%20Auth-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![BLoC](https://img.shields.io/badge/BLoC%20%2F%20Cubit-State%20Management-FF6B35?style=for-the-badge&logo=flutter&logoColor=white)
![Clean Architecture](https://img.shields.io/badge/Clean%20Architecture-Enterprise%20Ready-blueviolet?style=for-the-badge)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-4CAF50?style=for-the-badge)

</div>

**Danilore One** es una plataforma integral de gestión empresarial (**ERP**), punto de venta de alta velocidad (**POS**) y tienda digital omnicanal (**E-commerce**) desarrollada en **Flutter**. Diseñada para ofrecer rendimiento nativo en dispositivos móviles (Android / iOS), tablets, terminales táctiles de mostrador y navegadores web, con arquitectura limpia, reactividad en tiempo real y soporte avanzado de hardware.

---

## 📑 Tabla de Contenidos

- [Características Principales](#-características-principales)
  - [Módulo ERP & Administración](#-módulo-erp--administración)
  - [Punto de Venta (POS Pro) & Hardware](#-punto-de-venta-pos-pro--hardware)
  - [Módulo de Clientes (E-commerce Omnicanal)](#-módulo-de-clientes-e-commerce-omnicanal)
- [Arquitectura de Software](#-arquitectura-de-software)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Stack Tecnológico](#-stack-tecnológico)
- [Servicio de Retroalimentación de Hardware (`AppFeedbackService`)](#-servicio-de-retroalimentación-de-hardware-appfeedbackservice)
- [Requisitos Previos y Entorno](#-requisitos-previos-y-entorno)
- [Instalación y Puesta en Marcha](#-instalación-y-puesta-en-marcha)
- [Compilación y Despliegue](#-compilación-y-despliegue)
- [Atajos de Teclado para Terminales POS y Almacén](#-atajos-de-teclado-para-terminales-pos-y-almacén)
- [Licencia](#-licencia)

---

## 🚀 Características Principales

El sistema implementa una segmentación segura por roles (`admin` / `customer`) con interfaces, permisos y flujos de navegación optimizados para cada perfil.

### 🛠️ Módulo ERP & Administración

- **Dashboard Ejecutivo & Bento Grid:** Panel visual modular y personalizable con métricas clave de ventas, ingresos netos, productos más vendidos, monitoreo de metas de ahorro y widgets configurables mediante drag & drop.
- **Catálogo de Productos & Variantes:** Control exhaustivo de productos con variantes (talla, color, presentación, concentración), SKU y códigos de barra independientes, control de principios activos farmacéuticos/químicos y galería fotográfica.
- **Control de Inventario & Kardex Multialmacén:** 
  - Gestión integral de existencias por almacén central, sucursales y mostradores.
  - Trazabilidad estricta de lotes con fechas de fabricación y vencimiento bajo política **FEFO** (*First Expired, First Out*).
  - Movimientos de entrada, salida y ajustes de inventario con costeo ponderado.
  - Exportación de kardex e informes en formatos **PDF**, **Excel** y **CSV**.
- **Compras & Proveedores:** Emisión y control de órdenes de compra, control de estados (*DRAFT*, *SENT*, *RECEIVED*, *CANCELLED*), cuentas por pagar y recepción parcial o total de mercancías.
- **Tesorería & Finanzas:** Gestión de cuentas financieras (caja chica, cuentas bancarias, billeteras digitales), registro categorizado de ingresos y egresos, transferencias entre cuentas y balance en tiempo real.
- **CRM & Clientes:** Fichas integrales de clientes, historial transaccional, líneas de crédito comercial con amortizaciones, estados de cuenta y lista de deseos sincronizada.
- **Control de Acceso (RBAC):** Administración de roles y permisos granulares a nivel de pantalla y acción.
- **Configuración Empresarial:** Identidad corporativa (nombre comercial, RUC/NIT, dirección fiscal, logo), configuraciones de fidelización y parámetros del sistema.

### 🛒 Punto de Venta (POS Pro) & Hardware

- **Validación de Stock en Tiempo Real:** Validación preventiva en el almacén de despacho antes de admitir cualquier producto al carrito o registrar la venta.
- **Escaneo Físico y Óptico:**
  - **Pistolas de Códigos de Barra:** Detección de lectores láser y ópticos (USB HID / Bluetooth) con discriminación de ráfagas de teclado y detección de sufijos (*Enter / Tab*).
  - **Cámara Integrada:** Escaneo ultrarrápido de códigos 1D y QR mediante `mobile_scanner`.
  - **OCR Inteligente de Etiquetas:** Reconocimiento de texto en tiempo real con Google ML Kit para leer etiquetas complejas, marcas y selección automática de variantes.
- **Gestión de Turnos y Cajas:** Apertura, control de saldo inicial, registro de arqueos, desglose por métodos de pago y cierre ciego con comprobante impreso.
- **Venta Rápida & Métodos de Pago Mixtos:** Efectivo con cálculo de cambio, transferencias digitales, tarjetas bancarias y cargos a línea de crédito del cliente.

### 🛍️ Módulo de Clientes (E-commerce Omnicanal)

- **Catálogo Interactivo:** Navegación por categorías con chips animados, búsqueda instantánea y paginación incremental.
- **Detalle de Producto:** Galería con zoom, selección de variantes dinámicas, visualización de precios mayoristas escalonados y reseñas.
- **Carrito de Compras Persistente:** Cálculo automático de impuestos, totales y verificación de disponibilidad.
- **Seguimiento de Órdenes:** Historial de compras con línea de tiempo del estado del pedido.
- **Geolocalización & Direcciones:** Selección de punto de entrega interactivo con mapas OpenStreetMap (`flutter_map`) y geolocalización satelital.
- **Programa de Fidelización (Loyalty Club):** Acumulación de puntos por compras y ruleta de la suerte interactiva (*Fortune Wheel*) con recompensas canjeables.

---

## 🏗️ Arquitectura de Software

El proyecto implementa los principios de **Clean Architecture** (Arquitectura Limpia) junto con patrones de programación funcional, garantizando escalabilidad, testeabilidad y desacoplamiento absoluto de la interfaz con la infraestructura externa:

```
feature_name/
├── data/
│   ├── datasources/     # Comunicación con APIs externas y Supabase client
│   ├── models/          # Modelos de datos y serializadores JSON (fromJson / toJson)
│   └── repositories/    # Implementación concreta de los contratos de dominio
├── domain/
│   ├── entities/        # Objetos puros de negocio (inmutables con Equatable)
│   ├── repositories/    # Interfaces abstractas del repositorio
│   └── usecases/        # Casos de uso atómicos (retornan Either<Failure, T>)
└── presentation/
    ├── bloc/ (o cubit/) # Gestión de estados y eventos de la UI
    ├── screens/         # Vistas principales y páginas de la aplicación
    └── widgets/         # Componentes y bloques visuales modulares
```

### Principios y Patrones Aplicados

1. **BLoC / Cubit:** Gestión reactiva del estado visual, separando la lógica de presentación del renderizado de widgets.
2. **Programación Funcional (`fpdart`):** Manejo consistente de errores sin excepciones no controladas mediante el tipo `Either<Failure, T>`.
3. **Inyección de Dependencias (`get_it` + `injectable`):** Registro e inyección automatizada de dependencias mediante generador de código (`build_runner`).
4. **Enrutamiento Declarativo (`go_router`):** Shell routes por perfil, control de guards de autenticación, preservación de estado en pestañas y navegación profunda (*deep linking*).

---

## 📁 Estructura del Proyecto

```text
lib/
├── core/
│   ├── constants/       # Permisos del sistema, roles y configuraciones estáticas
│   ├── di/              # Inyección de dependencias (GetIt + Injectable config)
│   ├── enums/           # Enumeradores globales (ViewState, etc.)
│   ├── errors/          # Jerarquía de fallos y excepciones (ServerFailure, NetworkFailure)
│   ├── network/         # Monitor de conectividad y reconexión automática
│   ├── router/          # Configuración de GoRouter y guards de navegación
│   ├── services/        # Servicios globales (AppFeedbackService, BarcodeScanner, Logging)
│   ├── theme/           # Paleta de colores (AppColors), tipografías y tema claro/oscuro
│   ├── usecases/        # Contrato genérico base UseCase<Type, Params>
│   ├── utils/           # Extensiones de Dart, formateadores y detectores de teclado
│   └── widgets/         # Componentes transversales (AdaptiveDialog, ProTable, Shimmer)
│
├── features/
│   ├── app_config/      # Parámetros del negocio, logo, moneda y ajustes de escáner
│   ├── auth/            # Autenticación, sesión activa, recuperación y AuthCubit
│   ├── cart/            # Carrito de compras global y checkout
│   ├── catalog/         # Catálogo de productos, variantes, marcas, categorías y stock
│   ├── customers/       # CRM de clientes, crédito comercial y domicilios
│   ├── dashboard/       # Analítica gerencial, bento grid y metas del negocio
│   ├── financial/       # Cuentas bancarias, caja general y movimientos contables
│   ├── inventory/       # Kardex, movimientos de entrada/salida, lotes y vencimientos
│   ├── loyalty/         # Puntos de fidelización, wallet y ruleta interactiva
│   ├── main_navigation/# Layout maestro de administración (AdminLayout) y cliente
│   ├── orders/          # Gestión de pedidos, facturación y estados de despacho
│   ├── pos/             # Punto de venta, visor de cámara, OCR, turnos de caja
│   ├── purchases/       # Órdenes de compra a proveedores y recepción de mercancía
│   └── users/           # Administración de colaboradores y asignación de roles
│
└── main.dart            # Entrada principal, inicialización de servicios y arranque
```

---

## 🛠️ Stack Tecnológico

| Dominio | Paquete | Versión | Propósito |
|---|---|---|---|
| **Framework Base** | `flutter` | `>=3.47.0` (Canal Stable) | Framework UI multiplataforma de Google |
| **Lenguaje** | `dart` | `^3.13.0` | Lenguaje orientado a objetos fuertemente tipado |
| **Backend & Cloud** | `supabase_flutter` | `^2.16.0` | Base de datos PostgreSQL, Auth, Storage y RLS |
| **Estado** | `flutter_bloc` | `^9.1.1` | Patrón BLoC / Cubit para flujos de datos unidireccionales |
| **Inyección de Dependencias** | `get_it` + `injectable` | `^9.2.1` | Service Locator declarativo y modular |
| **Programación Funcional** | `fpdart` | `^1.2.0` | Tipos monádicos `Either` y `Option` para control de errores |
| **Enrutamiento** | `go_router` | `^18.0.0` | Enrutamiento declarativo con soporte para web y deep links |
| **Hardware & Vibración** | `vibration` | `^3.2.0` | Control del actuador físico/háptico nativo en Android/iOS |
| **Audio de Hardware** | `audioplayers` | `^6.8.1` | Reproducción de sonidos táctiles y tonos de escáner POS |
| **Escaneo de Cámara** | `mobile_scanner` | `^7.4.2` | Lector de códigos de barra 1D y QR de alta velocidad |
| **Visión Artificial (OCR)** | `google_mlkit_text_recognition` | `^0.17.1` | Reconocimiento óptico de etiquetas y empaques en tiempo real |
| **Documentos & Reportes** | `pdf` + `printing` | `^3.13.0` | Maquetación e impresión de reportes y tickets térmicos |
| **Exportación de Datos** | `excel` + `csv` | `^4.0.6` | Exportación de inventarios y finanzas para auditorías |
| **Mapas & Geodatos** | `flutter_map` + `latlong2` | `^8.3.1` | Mapas interactivos vectoriales OpenStreetMap |
| **Geolocalización** | `geolocator` | `^14.0.3` | Coordenadas GPS en tiempo real para entrega de pedidos |
| **Generación de Códigos** | `barcode_widget` + `qr_flutter`| `^2.0.4` | Renderizado dinámico de códigos EAN, Code128 y QR |

---

## 📳 Servicio de Retroalimentación de Hardware (`AppFeedbackService`)

Para superar los problemas comunes en Android donde `HapticFeedback` nativo es silenciado por la configuración de "Vibración al tocar" del sistema o cuando el modo silencio apaga los bips del sistema, se construyó el servicio centralizado **`AppFeedbackService`**:

- **Hardware Vibrator Directo:** Se comunica de forma nativa con el servicio del motor háptico utilizando `vibration` con caché de comprobación de capacidades para evitar latencia de canal.
- **Intensidades Estandarizadas:**
  - `selectionClick()`: Micro-vibración (`25ms`, amplitud `60`) para dropdowns, pestañas y chips de filtrado.
  - `lightImpact()`: Vibración ligera (`30ms`, amplitud `64`) para botones de navegación y toques comunes.
  - `mediumImpact()`: Vibración media (`50ms`, amplitud `128`) para confirmaciones, escaneo y adición a caja.
  - `heavyImpact()`: Vibración fuerte (`70ms`, amplitud `160`) para eliminaciones y acciones irreversibles.
- **Canal de Audio Multimedia:** Disparo acústico de confirmación (`scanner_beep.wav`) mediante el canal de medios para sonar con nitidez en terminales de caja sin importar el modo de timbre del dispositivo.

---

## ⚙️ Requisitos Previos y Entorno

1. **Flutter SDK:** Versión `>=3.47.0` (o superior en canal stable) instalada y configurada en el `PATH`.
2. **Dart SDK:** Versión `^3.13.0`.
3. **Instancia de Supabase:** Proyecto activo con el esquema relacional, funciones RPC y políticas RLS configuradas.
4. **Archivo de Credenciales:** Crea un archivo `env.json` en la raíz del proyecto basándote en la plantilla:

```json
{
  "SUPABASE_URL": "https://tu-proyecto.supabase.co",
  "SUPABASE_KEY": "tu-supabase-anon-key"
}
```

> [!NOTE]
> El archivo `env.json` está incluido en el `.gitignore` para salvaguardar las credenciales del proyecto.

---

## 🚀 Instalación y Puesta en Marcha

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/TheDanilore/inventory_store_app.git
   cd inventory_store_app
   ```

2. **Obtener dependencias:**
   ```bash
   flutter pub get
   ```

3. **Generar código de inyección de dependencias:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Ejecutar en modo desarrollo:**
   ```bash
   # En emulador o dispositivo conectado
   flutter run --dart-define-from-file=env.json
   ```

---

## 📦 Compilación y Despliegue

Sigue el flujo ordenado para construir instalables de producción:

```bash
# 1. Limpieza de artefactos previos y descarga de paquetes
flutter clean
flutter pub get

# 2. Generación de código inyectable
dart run build_runner build --delete-conflicting-outputs

# 3. Compilación para Android:
# APK para pruebas rápidas en dispositivo (Debug)
flutter build apk --debug --dart-define-from-file=env.json

# APK de producción universal (Release)
flutter build apk --release --dart-define-from-file=env.json

# APKs optimizados por arquitectura de procesador (Split ABI - Recomendado para reducir tamaño)
flutter build apk --split-per-abi --release --dart-define-from-file=env.json

# Android App Bundle para publicación en Google Play Console
flutter build appbundle --release --dart-define-from-file=env.json

# 4. Compilación para la Web:
flutter build web --release --dart-define-from-file=env.json
```

---

## ⌨️ Atajos de Teclado para Terminales POS y Almacén

Para agilizar el flujo de trabajo en cajas registradoras y terminales táctiles de almacén, el sistema cuenta con integración de atajos de teclado globales:

| Atajo | Módulo | Acción |
|---|---|---|
| <kbd>F2</kbd> / <kbd>Ctrl</kbd> + <kbd>B</kbd> | Global | Enfocar barra de búsqueda de productos / escaneo |
| <kbd>F4</kbd> | POS | Abrir visor de cámara / escáner de códigos |
| <kbd>Ctrl</kbd> + <kbd>K</kbd> | Dashboard / Admin | Abrir paleta rápida de comandos ejecutivos |
| <kbd>R</kbd> | Dashboard | Recargar métricas y estadísticas en tiempo real |
| <kbd>1</kbd> - <kbd>4</kbd> | Filtros | Alternar períodos de tiempo (Hoy, 7 días, Mes, Año) |
| <kbd>Esc</kbd> | Modales | Cerrar paneles flotantes, hojas de edición o cancelar acción |
| <kbd>Enter</kbd> | Formularios | Confirmar adición de producto o validar entrada de inventario |

---

## 📄 Licencia

Este software es de carácter privado y confidencial (`publish_to: "none"`). Todos los derechos reservados.
