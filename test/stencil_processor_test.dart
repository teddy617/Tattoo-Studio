import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/services/stencil_processor.dart';

void main() {
  Uint8List makeArtwork() {
    final input = img.Image(width: 9, height: 9, numChannels: 4);
    img.fill(input, color: img.ColorRgba8(255, 255, 255, 255));
    input.setPixelRgba(4, 4, 0, 0, 0, 255);
    input.setPixelRgba(0, 0, 0, 0, 0, 255);
    input.setPixelRgba(2, 2, 0, 0, 0, 0);
    return Uint8List.fromList(img.encodePng(input));
  }

  test('stencil preserves black strokes, clears transparent or white pixels', () {
    final decoded = img.decodePng(StencilProcessor.processSync(
      makeArtwork(), threshold: 150, transparent: true,
    ))!;
    expect(decoded.getPixel(4, 4).a.toInt(), 255);
    expect(decoded.getPixel(4, 4).r.toInt(), 0);
    expect(decoded.getPixel(2, 2).a.toInt(), 0);
    expect(decoded.getPixel(6, 6).a.toInt(), 0);
  });

  test('opaque stencil output has a white background', () {
    final decoded = img.decodePng(StencilProcessor.processSync(
      makeArtwork(), threshold: 150,
    ))!;
    expect(decoded.getPixel(8, 8).a.toInt(), 255);
    expect(decoded.getPixel(8, 8).r.toInt(), 255);
  });

  test('cleanup removes isolated ink pixels without deleting grouped pixels', () {
    final input = img.Image(width: 8, height: 8, numChannels: 4);
    img.fill(input, color: img.ColorRgba8(255, 255, 255, 255));
    input.setPixelRgba(2, 2, 0, 0, 0, 255);
    input.setPixelRgba(4, 4, 0, 0, 0, 255);
    input.setPixelRgba(5, 4, 0, 0, 0, 255);
    final decoded = img.decodePng(StencilProcessor.processSync(
      Uint8List.fromList(img.encodePng(input)),
      removeIsolatedPixels: true, transparent: true,
    ))!;
    expect(decoded.getPixel(2, 2).a.toInt(), 0);
    expect(decoded.getPixel(4, 4).a.toInt(), 255);
    expect(decoded.getPixel(5, 4).a.toInt(), 255);
  });
}
