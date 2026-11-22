import 'package:flutter_test/flutter_test.dart';
import 'package:tattoo_studio/models/design_project.dart';

void main() {
  test('project JSON preserves editable layer values', () {
    final project = DesignProject(
      id: 'one',
      name: 'Roses',
      updatedAt: DateTime.utc(2026, 11, 22),
      layers: const [
        DesignLayer(
          id: 'two',
          name: 'Rose',
          assetPath: 'assets/two.png',
          x: 12,
          y: 30,
          width: 200,
          height: 300,
          rotation: 0.4,
          flipX: true,
        ),
      ],
    );
    final restored = DesignProject.fromJson(project.toJson());
    expect(restored.layers.first.rotation, 0.4);
    expect(restored.layers.first.flipX, true);
    expect(restored.layers.first.assetPath, 'assets/two.png');
    expect(restored.name, 'Roses');
  });
}
