import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tattoo_studio/models/design_project.dart';
import 'package:tattoo_studio/screens/editor_screen.dart';

void main() {
  testWidgets('empty editor shows import and layers controls', (tester) async {
    final project = DesignProject(
      id: 'sample',
      name: 'Test design',
      updatedAt: DateTime.utc(2026, 11, 22),
      layers: [],
    );
    await tester.pumpWidget(MaterialApp(home: EditorScreen(project: project)));
    expect(find.text('Test design'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Layers (0)'), findsOneWidget);
  });
}
