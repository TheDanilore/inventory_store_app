# Inventory Store App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

**Inventory Store** es un sistema integral de gestión de inventario, punto de venta (POS) y tienda en línea (E-commerce) desarrollado en **Flutter**. Este proyecto está diseñado para funcionar en múltiples plataformas, ofreciendo una experiencia completa tanto para administradores de negocios como para clientes finales.

## 🚀 Características Principales

El proyecto se divide en dos módulos principales basados en los roles de usuario (`Admin` y `Customer`):

### 🛠️ Módulo de Administración (Admin / ERP & POS)
Una suite completa para la gestión del negocio:
- **Dashboard & Analíticas:** Visualización de estadísticas clave del negocio.
- **Gestión de Catálogo:** Administración de productos, categorías, atributos (tallas, colores, etc.) y principios activos.
- **Control de Inventario (Kardex):** Seguimiento detallado de entradas, salidas y existencias por almacenes.
- **Punto de Venta (POS):** Sistema de caja, gestión de turnos de caja (aperturas/cierres) y facturación rápida.
- **Gestión de Proveedores y Compras:** Órdenes de compra y cuentas por pagar.
- **CRM y Cuentas:** Administración de clientes, usuarios del sistema, líneas de crédito y cuentas financieras.
- **Fidelización:** Configuración de programa de puntos y recompensas.

### 🛍️ Módulo de Clientes (Customer / E-commerce)
Una experiencia de compra intuitiva para el usuario final:
- **Exploración de Catálogo:** Búsqueda de productos, categorías y lista de deseos (Wishlist).
- **Carrito y Compras:** Gestión de carrito de compras y seguimiento de pedidos.
- **Geolocalización:** Configuración de direcciones de entrega mediante mapas interactivos.
- **Programa de Fidelización:** Consulta de puntos acumulados y minijuegos (Ruleta de la Suerte) para ganar recompensas.

## 🛠️ Stack Tecnológico

El proyecto hace uso de librerías modernas y robustas del ecosistema Flutter:

- **Core & Arquitectura:**
  - `provider`: Gestión de estado simple y escalable.
  - `go_router`: Enrutamiento declarativo y navegación profunda.
- **Backend & Base de Datos:**
  - `supabase_flutter`: Autenticación, base de datos en tiempo real y almacenamiento.
- **Mapas y Geolocalización:**
  - `flutter_map`, `geolocator`, `latlong2`: Integración de mapas interactivos y obtención de ubicación del dispositivo.
- **Documentos & Reportes:**
  - `pdf`, `printing`: Generación e impresión de reportes y facturas en formato PDF.
- **UI & UX:**
  - `shimmer`, `cached_network_image`: Carga progresiva e imágenes cacheadas para una interfaz fluida.
  - `flutter_staggered_animations`: Animaciones de listas y grids.
  - `flutter_fortune_wheel`: Componente de ruleta para gamificación (módulo de fidelización).
- **Utilidades:**
  - `image_picker`, `flutter_image_compress`: Manejo y optimización de imágenes.
  - `shared_preferences`: Almacenamiento local ligero.
  - `url_launcher`, `connectivity_plus`, `vibration`, `file_saver`.

## 📁 Estructura del Proyecto

La estructura dentro del directorio `lib/` está organizada por dominios y características:

```text
lib/
├── data/           # Repositorios, fuentes de datos (Supabase) y DAOs.
├── models/         # Modelos de datos y entidades del negocio.
├── providers/      # Manejadores de estado (Providers) de la aplicación.
├── router/         # Configuración de rutas (GoRouter).
├── screens/        # Vistas de la aplicación, separadas por dominio:
│   ├── admin/      # Vistas del panel de administración (Inventario, POS, etc.)
│   ├── auth/       # Pantallas de autenticación y registro.
│   ├── customer/   # Vistas de la tienda para clientes (Catálogo, carrito, juegos).
│   ├── shared/     # Componentes visuales compartidos entre módulos.
│   └── splash_screen.dart # Pantalla de carga inicial.
├── services/       # Servicios externos e integraciones.
├── shared/         # Constantes, configuraciones globales y widgets genéricos.
├── utils/          # Funciones de ayuda (helpers), formateadores y extensiones.
└── main.dart       # Punto de entrada de la aplicación.
```

## ⚙️ Requisitos Previos

- Flutter SDK (versión `>=3.7.2` o superior)
- Dart SDK
- Proyecto configurado en [Supabase](https://supabase.com/) con sus respectivas variables de entorno (URL y Anon Key).

## 🚀 Instalación y Ejecución

1. Clona este repositorio.
2. Instala las dependencias del proyecto:
   ```bash
   flutter pub get
   ```
3. Configura tus variables de entorno para la conexión con Supabase (comúnmente en un archivo `.env` o en las constantes del proyecto).
4. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## 📄 Licencia

Este proyecto es de uso privado / restringido (`publish_to: "none"`).
