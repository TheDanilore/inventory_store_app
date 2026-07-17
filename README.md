# Inventory Store App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![BLoC](https://img.shields.io/badge/BLoC-%23FF6B35.svg?style=for-the-badge&logo=flutter&logoColor=white)

**Inventory Store** es un sistema integral de gestión empresarial (ERP), punto de venta (POS) y tienda en línea (E-commerce) desarrollado en **Flutter**. Funciona en múltiples plataformas (Android, iOS, Web) y ofrece una experiencia completa tanto para administradores de negocios como para clientes finales.

---

## 🚀 Características Principales

El sistema está dividido en dos módulos basados en el rol del usuario (`admin` / `customer`), cada uno con su propio layout, rutas y flujos de navegación.

### 🛠️ Módulo de Administración (ERP & POS)

- **Dashboard & Analíticas:** Resumen de ventas, ingresos, clientes top y métricas clave del negocio.
- **Catálogo de Productos:** Gestión completa de productos con variantes, atributos (tallas, colores, etc.), categorías, principios activos y galería de imágenes.
- **Control de Inventario (Kardex):** Entradas, salidas y existencias por almacenes. Generación de reportes en PDF.
- **Punto de Venta (POS):** Caja rápida con turnos de caja (apertura/cierre), búsqueda de clientes, aplicación de crédito y descuentos.
- **Compras:** Órdenes de compra a proveedores y cuentas por pagar.
- **Finanzas:** Gestión de cuentas financieras e informes.
- **CRM – Clientes:** Fichas de clientes, líneas de crédito, movimientos de cuenta y lista de deseos.
- **Usuarios:** Alta y edición de usuarios del sistema con roles.
- **Configuración:** Ajustes globales del negocio (nombre, dirección, logo, programas de fidelización).

### 🛍️ Módulo de Clientes (E-commerce)

- **Catálogo:** Exploración de productos por categoría, búsqueda y filtros. Carga incremental (paginación).
- **Detalle de Producto:** Galería de imágenes, variantes, precio mayorista, reseñas y botón de agregar al carrito.
- **Carrito de Compras:** Gestión de ítems, cantidades y resumen de pedido.
- **Pedidos:** Historial y seguimiento de órdenes.
- **Perfil & Direcciones:** Gestión de datos personales y ubicaciones de entrega con mapa interactivo.
- **Lista de Deseos (Wishlist):** Guardado de productos favoritos.
- **Programa de Fidelización:** Consulta de puntos acumulados y ruleta de la suerte para ganar recompensas.

---

## 🏗️ Arquitectura

El proyecto sigue **Clean Architecture** con separación estricta en tres capas por feature:

```
feature/
├── data/           # Modelos, DTOs, datasources (Supabase) y repositorios implementados.
├── domain/         # Entidades, interfaces de repositorios y use cases.
└── presentation/   # BLoC/Cubits, pantallas (screens) y widgets.
```

**Patrones y principios aplicados:**
- **BLoC / Cubit** para toda la gestión de estado de presentación.
- **Functional Programming** con `fpdart` — los use cases retornan `Either<Failure, T>`.
- **Dependency Injection** con `get_it` + `injectable` (código generado con `build_runner`).
- **Enrutamiento declarativo** con `go_router` (rutas anidadas, shell routes, deep links).

---

## 📁 Estructura del Proyecto

```text
lib/
├── core/
│   ├── constants/      # Roles, constantes globales y datos de configuración.
│   ├── di/             # Inyección de dependencias (injection_container.dart + .config.dart).
│   ├── enums/          # Enumeraciones compartidas (ViewState, etc.).
│   ├── errors/         # Clases de Failure para manejo de errores.
│   ├── network/        # Cubit de conectividad y estados de red.
│   ├── router/         # AppRouter (GoRouter) con shell routes por rol.
│   ├── theme/          # AppColors, estilos globales.
│   ├── usecases/       # Interfaz base UseCase<T, P>.
│   ├── utils/          # Helpers y extensiones generales.
│   └── widgets/        # Widgets genéricos reutilizables (shimmer, snackbar, etc.).
│
├── features/
│   ├── app_config/     # Configuración del negocio (nombre, logo, loyalty config).
│   ├── auth/           # Autenticación (login, perfil, AuthCubit).
│   ├── catalog/        # Catálogo de productos (admin + customer), variantes, detalle.
│   ├── customers/      # CRM: clientes, créditos, wishlist, ubicaciones.
│   ├── dashboard/      # Analíticas y estadísticas del negocio.
│   ├── financial/      # Cuentas financieras e informes.
│   ├── inventory/      # Kardex, entradas, salidas, almacenes.
│   ├── loyalty/        # Programa de puntos, wallet, ruleta.
│   ├── main_navigation/# Layouts globales: AdminLayout, CustomerLayout.
│   ├── orders/         # Pedidos (admin y cliente), carrito.
│   ├── pos/            # Punto de venta, turno de caja, cart cubit.
│   ├── purchases/      # Órdenes de compra a proveedores.
│   └── users/          # Gestión de usuarios del sistema.
│
└── main.dart           # Punto de entrada de la aplicación.
```

---

## 🛠️ Stack Tecnológico

### Core & Arquitectura
| Paquete | Uso |
|---|---|
| `flutter_bloc` | Gestión de estado con BLoC/Cubit |
| `get_it` + `injectable` | Inyección de dependencias |
| `fpdart` | Tipos funcionales (`Either`, `Option`) |
| `equatable` | Comparación de valor en estados y entidades |
| `go_router` | Enrutamiento declarativo con rutas anidadas |

### Backend & Datos
| Paquete | Uso |
|---|---|
| `supabase_flutter` | Autenticación, base de datos en tiempo real y storage |
| `shared_preferences` | Persistencia local ligera (carrito, preferencias) |
| `connectivity_plus` | Detección de estado de red |

### Mapas & Geolocalización
| Paquete | Uso |
|---|---|
| `flutter_map` + `latlong2` | Mapa interactivo para gestión de direcciones |
| `geolocator` | Obtención de ubicación del dispositivo |

### UI & UX
| Paquete | Uso |
|---|---|
| `cached_network_image` | Carga y caché de imágenes de red |
| `shimmer` | Esqueletos de carga |
| `flutter_staggered_animations` | Animaciones de listas |
| `flutter_fortune_wheel` | Ruleta de fidelización |

### Documentos & Reportes
| Paquete | Uso |
|---|---|
| `pdf` + `printing` | Generación e impresión de facturas y reportes |
| `file_saver` | Guardado de archivos en dispositivo |

### Utilidades
| Paquete | Uso |
|---|---|
| `image_picker` + `flutter_image_compress` | Captura y optimización de imágenes |
| `url_launcher` | Apertura de URLs externas |
| `vibration` | Retroalimentación háptica |
| `intl` | Formateo de fechas y monedas |
| `http` | Peticiones HTTP directas |

---

## ⚙️ Requisitos Previos

- **Flutter SDK** `>=3.7.2`
- **Dart SDK** `^3.7.2`
- Proyecto en [Supabase](https://supabase.com/) con las tablas, funciones y políticas RLS configuradas.
- Variables de entorno: `SUPABASE_URL` y `SUPABASE_ANON_KEY`.

---

## 🚀 Instalación y Ejecución

1. **Clona el repositorio:**
   ```bash
   git clone <url-del-repo>
   cd inventory_store_app
   ```

2. **Instala las dependencias:**
   ```bash
   flutter pub get
   ```

3. **Configura Supabase** con tu URL y Anon Key en las constantes del proyecto.

4. **Regenera el código de inyección de dependencias** (si modificas cubits/use cases con `@injectable`):
   ```bash
   dart run build_runner build
   ```

5. **Ejecuta la aplicación:**
   ```bash
   flutter run
   ```

---

## 📄 Licencia

Este proyecto es de uso privado / restringido (`publish_to: "none"`).
