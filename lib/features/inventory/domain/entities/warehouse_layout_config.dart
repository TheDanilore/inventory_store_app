import 'package:equatable/equatable.dart';

/// Dimensiones físicas tridimensionales del almacén o tienda en metros.
class WarehouseDimensions extends Equatable {
  final double widthMeters;
  final double lengthMeters;
  final double heightMeters;

  const WarehouseDimensions({
    this.widthMeters = 20.0,
    this.lengthMeters = 30.0,
    this.heightMeters = 4.5,
  });

  double get areaSquareMeters => widthMeters * lengthMeters;
  double get volumeCubicMeters => widthMeters * lengthMeters * heightMeters;

  factory WarehouseDimensions.fromJson(Map<String, dynamic> json) {
    return WarehouseDimensions(
      widthMeters: (json['width_meters'] as num?)?.toDouble() ?? 20.0,
      lengthMeters: (json['length_meters'] as num?)?.toDouble() ?? 30.0,
      heightMeters: (json['height_meters'] as num?)?.toDouble() ?? 4.5,
    );
  }

  Map<String, dynamic> toJson() => {
    'width_meters': widthMeters,
    'length_meters': lengthMeters,
    'height_meters': heightMeters,
  };

  WarehouseDimensions copyWith({
    double? widthMeters,
    double? lengthMeters,
    double? heightMeters,
  }) {
    return WarehouseDimensions(
      widthMeters: widthMeters ?? this.widthMeters,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      heightMeters: heightMeters ?? this.heightMeters,
    );
  }

  @override
  List<Object?> get props => [widthMeters, lengthMeters, heightMeters];
}

/// Zona o mobiliario específico dentro del plano procedural (Góndola, Rack, Caja, etc.).
class WarehouseZone extends Equatable {
  final String id;
  final String name;
  final String
  type; // 'checkout', 'gondola', 'industrial_rack', 'loading_dock', 'backroom', 'packing_station', 'door'
  final String? code;
  final double x; // Posición X en metros (desde el origen 0,0)
  final double y; // Posición Y en metros
  final double width; // Ancho en metros
  final double length; // Largo en metros
  final double height; // Altura en metros
  final int levels; // Niveles de estantería (1 a 6)
  final int? colorValue; // Color ARGB personalizado

  const WarehouseZone({
    required this.id,
    required this.name,
    required this.type,
    this.code,
    required this.x,
    required this.y,
    required this.width,
    required this.length,
    this.height = 2.0,
    this.levels = 1,
    this.colorValue,
  });

  bool get isRack => type == 'industrial_rack';
  bool get isGondola => type == 'gondola';
  bool get isCheckout => type == 'checkout';
  bool get isDock => type == 'loading_dock';
  bool get isDoor => type == 'door';

  factory WarehouseZone.fromJson(Map<String, dynamic> json) {
    return WarehouseZone(
      id:
          json['id'] as String? ??
          'zone_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Zona',
      type: json['type'] as String? ?? 'gondola',
      code: json['code'] as String?,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['w'] ?? json['width'] as num?)?.toDouble() ?? 2.0,
      length: (json['l'] ?? json['length'] as num?)?.toDouble() ?? 4.0,
      height: (json['h'] ?? json['height'] as num?)?.toDouble() ?? 2.0,
      levels: (json['levels'] as num?)?.toInt() ?? 1,
      colorValue: (json['color'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    if (code != null) 'code': code,
    'x': x,
    'y': y,
    'w': width,
    'l': length,
    'h': height,
    'levels': levels,
    if (colorValue != null) 'color': colorValue,
  };

  WarehouseZone copyWith({
    String? id,
    String? name,
    String? type,
    String? code,
    double? x,
    double? y,
    double? width,
    double? length,
    double? height,
    int? levels,
    int? colorValue,
  }) {
    return WarehouseZone(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      code: code ?? this.code,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      length: length ?? this.length,
      height: height ?? this.height,
      levels: levels ?? this.levels,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    code,
    x,
    y,
    width,
    length,
    height,
    levels,
    colorValue,
  ];
}

/// Configuración procedural completa del Gemelo Digital de un almacén o tienda.
class WarehouseLayoutConfig extends Equatable {
  final WarehouseDimensions dimensions;
  final double
  gridSize; // Tamaño de celda en metros para snapping (default 1.0)
  final List<WarehouseZone> zones;
  final int aislesCount;
  final int shelvesPerAisle;
  final int levelsPerShelf;

  const WarehouseLayoutConfig({
    this.dimensions = const WarehouseDimensions(),
    this.gridSize = 1.0,
    this.zones = const [],
    this.aislesCount = 4,
    this.shelvesPerAisle = 4,
    this.levelsPerShelf = 3,
  });

  bool get isEmpty => zones.isEmpty;

  factory WarehouseLayoutConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const WarehouseLayoutConfig();
    }
    return WarehouseLayoutConfig(
      dimensions:
          json['dimensions'] != null
              ? WarehouseDimensions.fromJson(
                Map<String, dynamic>.from(json['dimensions'] as Map),
              )
              : const WarehouseDimensions(),
      gridSize: (json['grid_size'] as num?)?.toDouble() ?? 1.0,
      zones:
          (json['zones'] as List<dynamic>? ?? [])
              .map(
                (z) =>
                    WarehouseZone.fromJson(Map<String, dynamic>.from(z as Map)),
              )
              .toList(),
      aislesCount: (json['aisles_count'] as num?)?.toInt() ?? 4,
      shelvesPerAisle: (json['shelves_per_aisle'] as num?)?.toInt() ?? 4,
      levelsPerShelf: (json['levels_per_shelf'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
    'dimensions': dimensions.toJson(),
    'grid_size': gridSize,
    'zones': zones.map((z) => z.toJson()).toList(),
    'aisles_count': aislesCount,
    'shelves_per_aisle': shelvesPerAisle,
    'levels_per_shelf': levelsPerShelf,
  };

  WarehouseLayoutConfig copyWith({
    WarehouseDimensions? dimensions,
    double? gridSize,
    List<WarehouseZone>? zones,
    int? aislesCount,
    int? shelvesPerAisle,
    int? levelsPerShelf,
  }) {
    return WarehouseLayoutConfig(
      dimensions: dimensions ?? this.dimensions,
      gridSize: gridSize ?? this.gridSize,
      zones: zones ?? this.zones,
      aislesCount: aislesCount ?? this.aislesCount,
      shelvesPerAisle: shelvesPerAisle ?? this.shelvesPerAisle,
      levelsPerShelf: levelsPerShelf ?? this.levelsPerShelf,
    );
  }

  /// Generador procedural para Tienda Física / Retail Store con mostradores y góndolas.
  factory WarehouseLayoutConfig.generateDefaultStore({
    double width = 16.0,
    double length = 22.0,
    double height = 3.8,
    int gondolaColumns = 3,
    int gondolasPerColumn = 3,
  }) {
    final zones = <WarehouseZone>[];

    // 1. Puerta de Acceso Principal (Frente inferior)
    zones.add(
      WarehouseZone(
        id: 'door_main',
        name: 'Acceso Clientes',
        type: 'door',
        code: 'ACCESO',
        x: (width / 2) - 1.5,
        y: 0.5,
        width: 3.0,
        length: 0.6,
        height: 2.8,
        levels: 1,
        colorValue: 0xFF0284C7,
      ),
    );

    // 2. Área de Cajas Registradoras / Mostrador POS
    zones.add(
      WarehouseZone(
        id: 'pos_counter_1',
        name: 'Caja 1 / Mostrador',
        type: 'checkout',
        code: 'CAJA-01',
        x: 2.0,
        y: 2.5,
        width: 3.5,
        length: 1.8,
        height: 1.1,
        levels: 1,
        colorValue: 0xFF10B981,
      ),
    );

    // 3. Góndolas de Exhibición en Pasillos Amplios
    final startX = 2.0;
    final startY = 6.0;
    final spacingX = (width - 4.0) / gondolaColumns;
    final gondolaW = 1.8;
    final gondolaL = 3.5;

    for (int col = 0; col < gondolaColumns; col++) {
      final currentX = startX + (col * spacingX);
      for (int row = 0; row < gondolasPerColumn; row++) {
        final currentY = startY + (row * (gondolaL + 1.8));
        final code = 'G-${String.fromCharCode(65 + col)}${row + 1}';
        zones.add(
          WarehouseZone(
            id: 'gondola_${col}_$row',
            name: 'Góndola $code',
            type: 'gondola',
            code: code,
            x: currentX,
            y: currentY,
            width: gondolaW,
            length: gondolaL,
            height: 1.7,
            levels: 3,
            colorValue: 0xFF6366F1,
          ),
        );
      }
    }

    // 4. Trastienda / Almacén de Reposición (Fondo)
    zones.add(
      WarehouseZone(
        id: 'backroom_area',
        name: 'Trastienda / Reposición',
        type: 'backroom',
        code: 'TRASTIENDA',
        x: 1.0,
        y: length - 4.0,
        width: width - 2.0,
        length: 3.2,
        height: 2.8,
        levels: 2,
        colorValue: 0xFF64748B,
      ),
    );

    return WarehouseLayoutConfig(
      dimensions: WarehouseDimensions(
        widthMeters: width,
        lengthMeters: length,
        heightMeters: height,
      ),
      zones: zones,
      aislesCount: gondolaColumns,
      shelvesPerAisle: gondolasPerColumn,
      levelsPerShelf: 3,
    );
  }

  /// Generador procedural para Almacén Central / Depósito de Racks Industriales.
  factory WarehouseLayoutConfig.generateDefaultCentral({
    double width = 24.0,
    double length = 36.0,
    double height = 6.0,
    int aisles = 4,
    int racksPerAisle = 4,
    int levels = 4,
  }) {
    final zones = <WarehouseZone>[];

    // 1. Muelles de Carga y Descarga (Docks)
    zones.add(
      WarehouseZone(
        id: 'dock_1',
        name: 'Muelle 1 (Recepción)',
        type: 'loading_dock',
        code: 'DOCK-01',
        x: 2.0,
        y: 0.5,
        width: 4.5,
        length: 2.5,
        height: 4.0,
        levels: 1,
        colorValue: 0xFFF59E0B,
      ),
    );

    zones.add(
      WarehouseZone(
        id: 'dock_2',
        name: 'Muelle 2 (Despacho)',
        type: 'loading_dock',
        code: 'DOCK-02',
        x: width - 6.5,
        y: 0.5,
        width: 4.5,
        length: 2.5,
        height: 4.0,
        levels: 1,
        colorValue: 0xFFF97316,
      ),
    );

    // 2. Zona de Picking y Empaque
    zones.add(
      WarehouseZone(
        id: 'packing_area',
        name: 'Mesa de Packing y Control',
        type: 'packing_station',
        code: 'PACK-01',
        x: (width / 2) - 4.0,
        y: 1.5,
        width: 8.0,
        length: 3.0,
        height: 1.2,
        levels: 1,
        colorValue: 0xFF10B981,
      ),
    );

    // 3. Racks Industriales de Alta Capacidad
    final startX = 2.5;
    final startY = 7.0;
    final rackWidth = 2.2;
    final rackLength = 5.0;
    final aisleSpacingX = (width - 5.0) / aisles;

    for (int a = 0; a < aisles; a++) {
      final aisleCode = 'PAS-${String.fromCharCode(65 + a)}';
      final currentX = startX + (a * aisleSpacingX);

      for (int r = 0; r < racksPerAisle; r++) {
        final currentY = startY + (r * (rackLength + 2.0));
        final rackCode = '$aisleCode-${r + 1}';

        zones.add(
          WarehouseZone(
            id: 'rack_${a}_$r',
            name: 'Rack $rackCode',
            type: 'industrial_rack',
            code: rackCode,
            x: currentX,
            y: currentY,
            width: rackWidth,
            length: rackLength,
            height: height * 0.75,
            levels: levels,
            colorValue: 0xFF3B82F6,
          ),
        );
      }
    }

    return WarehouseLayoutConfig(
      dimensions: WarehouseDimensions(
        widthMeters: width,
        lengthMeters: length,
        heightMeters: height,
      ),
      zones: zones,
      aislesCount: aisles,
      shelvesPerAisle: racksPerAisle,
      levelsPerShelf: levels,
    );
  }

  /// Generador procedural para Dark Store / Micro-Fulfillment Express.
  factory WarehouseLayoutConfig.generateDefaultDarkStore({
    double width = 16.0,
    double length = 24.0,
    double height = 4.0,
    int aisles = 4,
    int racksPerAisle = 3,
  }) {
    final zones = <WarehouseZone>[];

    // Mesa de despacho express
    zones.add(
      WarehouseZone(
        id: 'dispatch_station',
        name: 'Despacho Rápido / Riders',
        type: 'packing_station',
        code: 'DESPACHO',
        x: 2.0,
        y: 1.0,
        width: width - 4.0,
        length: 2.2,
        height: 1.2,
        levels: 1,
        colorValue: 0xFF8B5CF6,
      ),
    );

    // Racks de picking denso
    final startX = 1.5;
    final startY = 4.5;
    final rackWidth = 1.6;
    final rackLength = 4.2;
    final spacingX = (width - 3.0) / aisles;

    for (int a = 0; a < aisles; a++) {
      final aisleCode = 'P${a + 1}';
      final currentX = startX + (a * spacingX);

      for (int r = 0; r < racksPerAisle; r++) {
        final currentY = startY + (r * (rackLength + 1.5));
        final code = '$aisleCode-R${r + 1}';

        zones.add(
          WarehouseZone(
            id: 'dark_rack_${a}_$r',
            name: 'Estantería $code',
            type: 'industrial_rack',
            code: code,
            x: currentX,
            y: currentY,
            width: rackWidth,
            length: rackLength,
            height: 2.6,
            levels: 4,
            colorValue: 0xFF06B6D4,
          ),
        );
      }
    }

    return WarehouseLayoutConfig(
      dimensions: WarehouseDimensions(
        widthMeters: width,
        lengthMeters: length,
        heightMeters: height,
      ),
      zones: zones,
      aislesCount: aisles,
      shelvesPerAisle: racksPerAisle,
      levelsPerShelf: 4,
    );
  }

  @override
  List<Object?> get props => [
    dimensions,
    gridSize,
    zones,
    aislesCount,
    shelvesPerAisle,
    levelsPerShelf,
  ];
}
