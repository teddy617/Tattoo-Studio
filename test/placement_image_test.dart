import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/services/placement_image.dart';

void main() {
  test('keeps transparency when converting a tattoo to WebGL PNG', () {
    final artwork = img.Image(width: 8, height: 8, numChannels: 4);
    img.fill(artwork, color: img.ColorRgba8(255, 255, 255, 0));
    artwork.setPixelRgba(4, 4, 0, 0, 0, 255);
    final prepared = prepareTattooTexture(
      Uint8List.fromList(img.encodePng(artwork)),
    );
    final output = img.decodePng(prepared)!;
    expect(output.getPixel(0, 0).a.toInt(), 0);
    expect(output.getPixel(4, 4).a.toInt(), 255);
  });

  test('limits oversized tattoo images without changing aspect ratio', () {
    final artwork = img.Image(width: 2400, height: 1200);
    final output = img.decodePng(prepareTattooTexture(
      Uint8List.fromList(img.encodePng(artwork)),
    ))!;
    expect(output.width, 1200);
    expect(output.height, 600);
  });

  test('rejects invalid tattoo assets', () {
    expect(
      () => prepareTattooTexture(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
