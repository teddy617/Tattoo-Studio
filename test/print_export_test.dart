import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/services/print_export.dart';

void main() {
  Uint8List sample() {
    final source = img.Image(width: 100, height: 80, numChannels: 4);
    // Transparent page with a 20x10-pixel black tattoo.
    img.fill(source, color: img.ColorRgba8(255, 255, 255, 0));
    for (var y = 20; y < 30; y++) {
      for (var x = 30; x < 50; x++) {
        source.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }
    return Uint8List.fromList(img.encodePng(source));
  }

  test('width is measured across artwork, not transparent canvas', () {
    final options = PrintOptions(widthInches: 2, dpi: 150,
        transparent: true);
    final bytes = PrintExport.prepareSync(sample(), options);
    final output = img.decodePng(bytes)!;
    expect(output.width, 300);
    expect(output.height, 150);
    expect(output.getPixel(0, 0).a.toInt(), 255);
  });

  test('white background export preserves black ink and opaque background', () {
    final output = img.decodePng(PrintExport.prepareSync(
      sample(), const PrintOptions(
        widthInches: 1, dpi: 150, transparent: false,
      ),
    ))!;
    expect(output.width, 150);
    expect(output.getPixel(50, 40).a.toInt(), 255);
    expect(output.getPixel(50, 40).r.toInt(), 0);
  });

  test('PNG contains pHYs print resolution metadata', () {
    final bytes = PrintExport.prepareSync(
      sample(), const PrintOptions(
        widthInches: 2, dpi: 300, transparent: true,
      ),
    );
    final pngChunks = String.fromCharCodes(bytes);
    expect(pngChunks.contains('pHYs'), true);
    expect(img.decodePng(bytes)!.width, 600);
  });

  test('cannot export blank transparent artwork', () {
    final blank = img.Image(width: 40, height: 40, numChannels: 4);
    img.fill(blank, color: img.ColorRgba8(255, 255, 255, 0));
    expect(
      () => PrintExport.prepareSync(
        Uint8List.fromList(img.encodePng(blank)),
        const PrintOptions(),
      ),
      throwsFormatException,
    );
  });
}
