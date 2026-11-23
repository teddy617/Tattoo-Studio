import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Stencil preview is a derived export, not a destructive edit of the project.
/// Dark pixels become ink; light pixels become clear or white.
class StencilProcessor {
  static Future<Uint8List> process(
    Uint8List png, {
    int threshold = 150,
    bool transparent = false,
    bool removeIsolatedPixels = false,
  }) => compute(_process, _StencilRequest(
    png, threshold, transparent, removeIsolatedPixels,
  ));

  static Uint8List processSync(
    Uint8List png, {
    int threshold = 150,
    bool transparent = false,
    bool removeIsolatedPixels = false,
  }) => _process(_StencilRequest(
    png, threshold, transparent, removeIsolatedPixels,
  ));
}

class _StencilRequest {
  const _StencilRequest(
      this.png, this.threshold, this.transparent, this.removeNoise);
  final Uint8List png;
  final int threshold;
  final bool transparent;
  final bool removeNoise;
}

Uint8List _process(_StencilRequest request) {
  final decoded = img.decodeImage(request.png);
  if (decoded == null) throw const FormatException('Invalid artwork image');
  final input = img.bakeOrientation(decoded);
  final width = input.width;
  final height = input.height;
  final mask = Uint8List(width * height);
  final limit = request.threshold.clamp(0, 255);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = input.getPixel(x, y);
      // Composite semi-transparent ink onto white for stencil thresholding.
      final opacity = pixel.a / 255.0;
      final luminance = (0.2126 * pixel.r +
          0.7152 * pixel.g + 0.0722 * pixel.b);
      final onWhite = 255 * (1 - opacity) + luminance * opacity;
      mask[y * width + x] = onWhite < limit ? 1 : 0;
    }
  }
  final output = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      var ink = mask[index] == 1;
      if (ink && request.removeNoise && x > 0 && y > 0 &&
          x < width - 1 && y < height - 1) {
        var neighbors = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            neighbors += mask[(y + dy) * width + x + dx];
          }
        }
        if (neighbors == 0) ink = false;
      }
      if (ink) {
        output.setPixelRgba(x, y, 0, 0, 0, 255);
      } else if (request.transparent) {
        output.setPixelRgba(x, y, 255, 255, 255, 0);
      } else {
        output.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(output));
}
