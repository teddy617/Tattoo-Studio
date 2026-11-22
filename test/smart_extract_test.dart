import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/services/smart_extract.dart';

Uint8List sheetWithTwoDesigns() {
  final input = img.Image(width: 160, height: 100, numChannels: 4);
  img.fill(input, color: img.ColorRgba8(255, 255, 255, 255));
  for (var y = 20; y < 55; y++) {
    for (var x = 12; x < 42; x++) {
      input.setPixelRgba(x, y, 0, 0, 0, 255);
    }
    for (var x = 115; x < 145; x++) {
      input.setPixelRgba(x, y, 0, 0, 0, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(input));
}

void main() {
  test('smart crop trims surrounding whitespace and clears white pixels', () {
    final output = SmartExtract.processSync(sheetWithTwoDesigns());
    expect(output, hasLength(1));
    final decoded = img.decodePng(output.first.pngBytes)!;
    expect(decoded.width, lessThan(160));
    expect(decoded.height, lessThan(100));
    expect(decoded.getPixel(0, 0).a, 0);
  });

  test('split sheet finds two separated designs', () {
    final pieces = SmartExtract.processSync(
      sheetWithTwoDesigns(),
      splitSheet: true,
    );
    expect(pieces, hasLength(2));
    for (final item in pieces) {
      expect(item.width, lessThan(80));
      expect(item.height, greaterThan(0));
    }
  });

  test('unchanged mode retains its white background', () {
    final original = SmartExtract.processSync(
      sheetWithTwoDesigns(),
      keepBackground: true,
    );
    final decoded = img.decodePng(original.first.pngBytes)!;
    expect(decoded.width, 160);
    expect(decoded.getPixel(0, 0).a, 255);
  });
}
