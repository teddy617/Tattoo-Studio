import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/services/smart_extract.dart';

void main() {
  final source = img.Image(width: 100, height: 100, numChannels: 4);
  img.fill(source, color: img.ColorRgba8(255, 255, 255, 255));
  for (var y = 15; y < 85; y++) {
    for (var x = 15; x < 85; x++) {
      source.setPixelRgba(x, y, 0, 0, 0, 255);
    }
  }
  final bytes = Uint8List.fromList(img.encodePng(source));
  test('rectangle extracts only selected region', () {
    final selected = SmartExtract.processSync(bytes,
      selection: const ExtractionSelection(rectangle: true, points: [
        NormalizedPoint(0.1, 0.1), NormalizedPoint(0.5, 0.5),
      ]));
    final output = img.decodePng(selected.first.pngBytes)!;
    expect(output.width, lessThan(60));
    expect(output.height, lessThan(60));
  });
  test('lasso extracts region with transparency outside polygon', () {
    final selected = SmartExtract.processSync(bytes,
      selection: const ExtractionSelection(points: [
        NormalizedPoint(0.1, 0.1), NormalizedPoint(0.5, 0.1),
        NormalizedPoint(0.1, 0.5),
      ]));
    final output = img.decodePng(selected.first.pngBytes)!;
    expect(output.width, lessThan(60));
    expect(output.height, lessThan(60));
    expect(output.getPixel(output.width - 1, output.height - 1).a, 0);
  });
}
