import 'package:flutter_test/flutter_test.dart';
import 'package:tattoo_studio/services/canvas_precision.dart';

void main() {
  test('snaps both axes when selected layer is close to canvas center', () {
    final result = snapToCanvasCenter(
      x: 349, y: 498, width: 200, height: 200,
      canvasWidth: 900, canvasHeight: 1200,
    );
    expect(result.vertical, true);
    expect(result.horizontal, true);
    expect(result.x, 350);
    expect(result.y, 500);
  });

  test('does not snap distant artwork or when guides are disabled', () {
    final far = snapToCanvasCenter(
      x: 100, y: 300, width: 200, height: 200,
      canvasWidth: 900, canvasHeight: 1200,
    );
    expect(far.x, 100);
    expect(far.y, 300);
    final disabled = snapToCanvasCenter(
      x: 349, y: 498, width: 200, height: 200,
      canvasWidth: 900, canvasHeight: 1200, enabled: false,
    );
    expect(disabled.vertical, false);
    expect(disabled.horizontal, false);
    expect(disabled.x, 349);
    expect(disabled.y, 498);
  });
}
