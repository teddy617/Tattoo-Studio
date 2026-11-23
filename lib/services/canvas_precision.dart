/// Geometry helpers for precision positioning in canvas coordinates.
/// Pure Dart so snapping can be tested without Flutter or Android.
class SnapPlacement {
  const SnapPlacement(this.x, this.y, this.vertical, this.horizontal);
  final double x;
  final double y;
  final bool vertical;
  final bool horizontal;
}

SnapPlacement snapToCanvasCenter({
  required double x,
  required double y,
  required double width,
  required double height,
  required double canvasWidth,
  required double canvasHeight,
  bool enabled = true,
  double tolerance = 12,
}) {
  final vertical = enabled &&
      (x + width / 2 - canvasWidth / 2).abs() < tolerance;
  final horizontal = enabled &&
      (y + height / 2 - canvasHeight / 2).abs() < tolerance;
  return SnapPlacement(
    vertical ? (canvasWidth - width) / 2 : x,
    horizontal ? (canvasHeight - height) / 2 : y,
    vertical, horizontal,
  );
}
