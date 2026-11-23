import 'dart:math';

const double canvasWidth = 900;
const double canvasHeight = 1200;

String makeId() {
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '${DateTime.now().microsecondsSinceEpoch}_$random';
}

class MaskStroke {
  const MaskStroke({required this.points, required this.radius});
  /// [x,y] pairs normalized to the original image dimensions.
  final List<List<double>> points;
  /// Brush radius, normalized to the smaller image dimension.
  final double radius;

  Map<String, dynamic> toJson() => {
        'points': points,
        'radius': radius,
      };

  factory MaskStroke.fromJson(Map<String, dynamic> json) => MaskStroke(
        points: (json['points'] as List<dynamic>).map((item) =>
            (item as List<dynamic>).map((v) => (v as num).toDouble()).toList()
        ).toList(),
        radius: (json['radius'] as num).toDouble(),
      );
}

class DesignLayer {
  const DesignLayer({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.visible = true,
    this.locked = false,
    this.flipX = false,
    this.maskStrokes = const [],
  });

  final String id;
  final String name;
  final String assetPath;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final bool visible;
  final bool locked;
  final bool flipX;
  final List<MaskStroke> maskStrokes;

  DesignLayer copyWith({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? visible,
    bool? locked,
    bool? flipX,
    List<MaskStroke>? maskStrokes,
  }) =>
      DesignLayer(
        id: id,
        name: name ?? this.name,
        assetPath: assetPath,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        flipX: flipX ?? this.flipX,
        maskStrokes: maskStrokes ?? this.maskStrokes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assetPath': assetPath,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'visible': visible,
        'locked': locked,
        'flipX': flipX,
        'maskStrokes': maskStrokes.map((stroke) => stroke.toJson()).toList(),
      };

  factory DesignLayer.fromJson(Map<String, dynamic> json) => DesignLayer(
        id: json['id'] as String,
        name: json['name'] as String,
        assetPath: json['assetPath'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        visible: json['visible'] as bool? ?? true,
        locked: json['locked'] as bool? ?? false,
        flipX: json['flipX'] as bool? ?? false,
        maskStrokes: ((json['maskStrokes'] as List<dynamic>?) ?? const [])
            .map((value) => MaskStroke.fromJson(value as Map<String, dynamic>))
            .toList(),
      );
}

class DesignProject {
  DesignProject({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.layers,
  });

  final String id;
  String name;
  DateTime updatedAt;
  List<DesignLayer> layers;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'name': name,
        'updatedAt': updatedAt.toIso8601String(),
        'layers': layers.map((layer) => layer.toJson()).toList(),
      };

  factory DesignProject.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported project format.');
    }
    return DesignProject(
      id: json['id'] as String,
      name: json['name'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      layers: (json['layers'] as List<dynamic>)
          .map((value) => DesignLayer.fromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }
}
