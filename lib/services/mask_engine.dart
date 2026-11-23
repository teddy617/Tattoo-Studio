import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/design_project.dart';

/// Non-destructive eraser: original bytes remain untouched. These strokes
/// are saved in project JSON and reapplied whenever the project is opened.
class MaskEngine {
  static Future<Uint8List> apply(
    Uint8List original, List<MaskStroke> strokes,
  ) => compute(_render, _Request(original, strokes));

  static Uint8List applySync(
    Uint8List original, List<MaskStroke> strokes,
  ) => _render(_Request(original, strokes));
}

class _Request {
  const _Request(this.original, this.strokes);
  final Uint8List original;
  final List<MaskStroke> strokes;
}

Uint8List _render(_Request request) {
  final decoded = img.decodeImage(request.original);
  if (decoded == null) throw const FormatException('Invalid image layer');
  final source = img.bakeOrientation(decoded).convert(numChannels: 4);
  final scale = math.min(source.width, source.height).toDouble();

  void clearCircle(double cx, double cy, double radius) {
    final r = radius.clamp(0.5, scale / 2).toDouble();
    final left = math.max(0, (cx - r).floor());
    final top = math.max(0, (cy - r).floor());
    final right = math.min(source.width - 1, (cx + r).ceil());
    final bottom = math.min(source.height - 1, (cy + r).ceil());
    final rSquared = r * r;
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        if (dx * dx + dy * dy > rSquared) continue;
        final pixel = source.getPixel(x, y);
        source.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 0);
      }
    }
  }

  for (final stroke in request.strokes) {
    if (stroke.points.isEmpty) continue;
    final radius = stroke.radius.clamp(0.002, 0.25) * scale;
    for (var i = 0; i < stroke.points.length; i++) {
      final current = stroke.points[i];
      if (current.length < 2) continue;
      final x = current[0].clamp(0.0, 1.0) * source.width;
      final y = current[1].clamp(0.0, 1.0) * source.height;
      if (i == 0) {
        clearCircle(x, y, radius);
        continue;
      }
      final previous = stroke.points[i - 1];
      if (previous.length < 2) continue;
      final fromX = previous[0].clamp(0.0, 1.0) * source.width;
      final fromY = previous[1].clamp(0.0, 1.0) * source.height;
      final distance = math.sqrt(
          math.pow(x - fromX, 2) + math.pow(y - fromY, 2));
      final steps = math.max(1, (distance / math.max(1, radius * 0.5)).ceil());
      for (var step = 0; step <= steps; step++) {
        final t = step / steps;
        clearCircle(fromX + (x - fromX) * t,
            fromY + (y - fromY) * t, radius);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(source));
}
