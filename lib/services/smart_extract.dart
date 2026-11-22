import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ExtractedArtwork {
  const ExtractedArtwork({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  final Uint8List pngBytes;
  final int width;
  final int height;
}

class _ExtractionInput {
  const _ExtractionInput(this.source, this.splitSheet, this.keepBackground);

  final Uint8List source;
  final bool splitSheet;
  final bool keepBackground;
}

/// Works offline; best suited to black/colored artwork on plain white or
/// transparent backgrounds. It does NOT reconstruct overlapping shapes.
class SmartExtract {
  static Future<List<ExtractedArtwork>> process(
    Uint8List source, {
    bool splitSheet = false,
    bool keepBackground = false,
  }) =>
      compute(_processInIsolate, _ExtractionInput(source, splitSheet, keepBackground));

  /// Also exposed synchronously for repeatable unit tests.
  static List<ExtractedArtwork> processSync(
    Uint8List source, {
    bool splitSheet = false,
    bool keepBackground = false,
  }) =>
      _processInIsolate(_ExtractionInput(source, splitSheet, keepBackground));
}

List<ExtractedArtwork> _processInIsolate(_ExtractionInput request) {
  final decoded = img.decodeImage(request.source);
  if (decoded == null) throw const FormatException('Unsupported image file.');
  var source = img.bakeOrientation(decoded);

  // Protect mobile RAM. The source file is not overwritten, but imported layer
  // pixels are limited to 2400px on the longest side for this early prototype.
  const maxSide = 2400;
  if (math.max(source.width, source.height) > maxSide) {
    if (source.width >= source.height) {
      source = img.copyResize(source, width: maxSide);
    } else {
      source = img.copyResize(source, height: maxSide);
    }
  }

  final removeWhite = !request.keepBackground && _whiteBorder(source);
  final transparent = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final px = source.getPixel(x, y);
      final r = px.r.toInt();
      final g = px.g.toInt();
      final b = px.b.toInt();
      final a = px.a.toInt();
      var alpha = a;
      if (removeWhite) {
        final darkest = math.min(r, math.min(g, b));
        // White becomes clear; light paper edges get anti-aliased opacity.
        final backgroundOpacity = ((247 - darkest) / 18).clamp(0.0, 1.0);
        alpha = (a * backgroundOpacity).round();
      }
      transparent.setPixelRgba(x, y, r, g, b, alpha);
    }
  }

  final whole = _trim(transparent);
  if (!request.splitSheet) return [_encode(whole)];

  final rectangles = _findSeparatedDesigns(transparent);
  if (rectangles.length < 2) return [_encode(whole)];

  final results = <ExtractedArtwork>[];
  for (final rectangle in rectangles) {
    final crop = img.copyCrop(
      transparent,
      x: rectangle.x,
      y: rectangle.y,
      width: rectangle.width,
      height: rectangle.height,
    );
    results.add(_encode(_trim(crop)));
  }
  return results;
}

bool _whiteBorder(img.Image source) {
  var white = 0;
  var opaque = 0;
  const samplesPerEdge = 48;
  for (var i = 0; i < samplesPerEdge; i++) {
    final x = i * (source.width - 1) ~/ (samplesPerEdge - 1);
    final y = i * (source.height - 1) ~/ (samplesPerEdge - 1);
    for (final sample in [
      source.getPixel(x, 0),
      source.getPixel(x, source.height - 1),
      source.getPixel(0, y),
      source.getPixel(source.width - 1, y),
    ]) {
      if (sample.a < 100) continue;
      opaque++;
      if (sample.r >= 235 && sample.g >= 235 && sample.b >= 235) {
        white++;
      }
    }
  }
  return opaque > 0 && white / opaque >= 0.7;
}

img.Image _trim(img.Image source) {
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a <= 14) continue;
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x);
      bottom = math.max(bottom, y);
    }
  }
  if (right == -1) {
    // Keep an empty layer valid rather than making a zero-sized bitmap.
    return img.Image(width: 1, height: 1, numChannels: 4);
  }
  final pad = (math.min(source.width, source.height) * 0.012)
      .round()
      .clamp(2, 20)
      .toInt();
  left = math.max(0, left - pad);
  top = math.max(0, top - pad);
  right = math.min(source.width - 1, right + pad);
  bottom = math.min(source.height - 1, bottom + pad);
  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

ExtractedArtwork _encode(img.Image source) => ExtractedArtwork(
      pngBytes: Uint8List.fromList(img.encodePng(source)),
      width: source.width,
      height: source.height,
    );

class _PixelRectangle {
  const _PixelRectangle(this.x, this.y, this.width, this.height, this.mass);

  final int x;
  final int y;
  final int width;
  final int height;
  final int mass;
}

List<_PixelRectangle> _findSeparatedDesigns(img.Image source) {
  // Coarse occupancy plus a small dilation connects separated strokes inside
  // individual illustrations while leaving distinct flash-sheet motifs apart.
  final step = math.max(1, (math.max(source.width, source.height) / 210).ceil());
  final columns = (source.width / step).ceil();
  final rows = (source.height / step).ceil();
  final ink = Uint8List(columns * rows);
  for (var y = 0; y < source.height; y += 1) {
    for (var x = 0; x < source.width; x += 1) {
      if (source.getPixel(x, y).a > 90) {
        ink[(y ~/ step) * columns + x ~/ step] = 1;
      }
    }
  }

  final joined = Uint8List(ink.length);
  const radius = 3;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < columns; x++) {
      if (ink[y * columns + x] == 0) continue;
      for (var dy = -radius; dy <= radius; dy++) {
        final yy = y + dy;
        if (yy < 0 || yy >= rows) continue;
        for (var dx = -radius; dx <= radius; dx++) {
          final xx = x + dx;
          if (xx >= 0 && xx < columns) joined[yy * columns + xx] = 1;
        }
      }
    }
  }

  final seen = Uint8List(ink.length);
  final regions = <_PixelRectangle>[];
  for (var start = 0; start < joined.length; start++) {
    if (joined[start] == 0 || seen[start] == 1) continue;
    final queue = Queue<int>()..add(start);
    seen[start] = 1;
    var minX = columns;
    var minY = rows;
    var maxX = -1;
    var maxY = -1;
    var mass = 0;
    while (queue.isNotEmpty) {
      final index = queue.removeFirst();
      final x = index % columns;
      final y = index ~/ columns;
      if (ink[index] == 1) {
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        mass++;
      }
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx;
          final yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= columns || yy >= rows) continue;
          final neighbor = yy * columns + xx;
          if (joined[neighbor] == 1 && seen[neighbor] == 0) {
            seen[neighbor] = 1;
            queue.add(neighbor);
          }
        }
      }
    }
    if (mass < 5 || maxX < 0) continue;
    final pxLeft = math.max(0, minX * step - step);
    final pxTop = math.max(0, minY * step - step);
    final pxRight = math.min(source.width, (maxX + 2) * step);
    final pxBottom = math.min(source.height, (maxY + 2) * step);
    regions.add(_PixelRectangle(
      pxLeft,
      pxTop,
      pxRight - pxLeft,
      pxBottom - pxTop,
      mass,
    ));
  }

  regions.sort((a, b) => b.mass.compareTo(a.mass));
  // Small isolated specks are often grain or background noise.
  if (regions.isEmpty || regions.length > 24) return [];
  final strongest = regions.first.mass;
  final filtered = regions
      .where((region) => region.mass >= math.max(5, strongest * 0.025))
      .toList();
  filtered.sort((a, b) {
    final row = a.y.compareTo(b.y);
    return row == 0 ? a.x.compareTo(b.x) : row;
  });
  return filtered;
}
