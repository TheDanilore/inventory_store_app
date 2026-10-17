/// Puntos de corte únicos para toda la pantalla de Inventario.
///
/// Antes cada archivo definía los suyos (640/1024 en el header, 600/900 en
/// Stock y 840 en Lotes), por lo que entre 840 y 900 dp una pestaña mostraba
/// master-detail y la otra no. Ahora ambas cambian exactamente al mismo ancho.
abstract class InventoryBreakpoints {
  /// < 640: móvil. Lista a ancho completo + detalle en bottom sheet.
  static const double mobile = 640;

  /// >= 900: lista/tabla a la izquierda + panel de detalle fijo a la derecha.
  static const double split = 900;

  /// >= 1360: cabe la tabla (mín. 960) + panel (400) lado a lado.
  /// Entre 900 y 1360 el panel se superpone en vez de apretar la tabla.
  static const double wide = 1360;

  /// Ancho del panel de detalle en modo split.
  static const double detailPaneWidth = 400;
}
