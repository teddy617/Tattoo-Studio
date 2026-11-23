import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tattoo_studio/models/design_project.dart';
import 'package:tattoo_studio/services/mask_engine.dart';

void main() {
  final art = img.Image(width: 80, height: 80, numChannels: 4);
  img.fill(art, color: img.ColorRgba8(0, 0, 0, 255));
  final source = Uint8List.fromList(img.encodePng(art));
  const brush = MaskStroke(
      radius: 0.12,
      points: [[0.2, 0.5], [0.8, 0.5]]);

  test('erases along an entire stroke without changing original bytes', () {
    final before = Uint8List.fromList(source);
    final erased = img.decodePng(MaskEngine.applySync(source, [brush]))!;
    expect(erased.getPixel(40, 40).a, 0);
    expect(erased.getPixel(40, 0).a, 255);
    expect(source, orderedEquals(before));
  });

  test('reversible mask restores original when strokes are removed', () {
    final erased = img.decodePng(MaskEngine.applySync(source, [brush]))!;
    final restored = img.decodePng(MaskEngine.applySync(source, []))!;
    expect(erased.getPixel(40, 40).a, 0);
    expect(restored.getPixel(40, 40).a, 255);
  });

  test('mask strokes round-trip in project JSON and old projects still load', () {
    const layer = DesignLayer(
      id: 'one', name: 'Ink', assetPath: 'assets/one.png',
      x: 0, y: 0, width: 80, height: 80, maskStrokes: [brush],
    );
    final json = layer.toJson();
    expect(DesignLayer.fromJson(json).maskStrokes.first.points.length, 2);
    json.remove('maskStrokes');
    expect(DesignLayer.fromJson(json).maskStrokes, isEmpty);
  });
}
