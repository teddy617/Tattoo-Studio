import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/services/smart_extract.dart';

void main() {
  test('selection excludes screenshot chrome and splits two ink motifs', () {
    final source = img.Image(width: 360, height: 220, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(255, 255, 255, 255));

    // A dark webpage header must NOT become a layer.
    for (var y = 0; y < 48; y++) {
      for (var x = 0; x < 360; x++) {
        source.setPixelRgba(x, y, 15, 15, 15, 255);
      }
    }
    // Two designs inside the manually selected content area.
    for (var y = 90; y < 170; y++) {
      for (var x = 58; x < 92; x++) {
        source.setPixelRgba(x, y, 0, 0, 0, 255);
      }
      for (var x = 266; x < 300; x++) {
        source.setPixelRgba(x, y, 0, 0, 0, 255);
      }
    }

    final result = SmartExtract.processSync(
      Uint8List.fromList(img.encodePng(source)),
      splitSheet: true,
      forceWhiteRemoval: true,
      selection: const ExtractionSelection(
        rectangle: true,
        points: [
          NormalizedPoint(0.08, 0.28),
          NormalizedPoint(0.92, 0.85),
        ],
      ),
    );

    expect(result.length, 2);
    for (final item in result) {
      expect(item.height, lessThan(110));
      expect(item.width, lessThan(90));
    }
  });
}
