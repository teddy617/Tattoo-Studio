import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/design_project.dart';
import '../services/mask_engine.dart';

/// Touch-friendly eraser for one raster layer. No original pixels are changed:
/// the saved output is a list of reversible strokes.
class EraserScreen extends StatefulWidget {
  const EraserScreen({
    super.key,
    required this.original,
    required this.initialStrokes,
  });

  final Uint8List original;
  final List<MaskStroke> initialStrokes;

  @override
  State<EraserScreen> createState() => _EraserScreenState();
}

class _EraserScreenState extends State<EraserScreen> {
  late List<MaskStroke> _strokes;
  Uint8List? _preview;
  List<List<double>> _current = [];
  double _radius = 0.025;
  bool _working = false;
  int _revision = 0;
  late final double _aspect;

  @override
  void initState() {
    super.initState();
    _strokes = List.of(widget.initialStrokes);
    final image = img.decodeImage(widget.original);
    _aspect = image == null ? 1 : image.width / image.height;
    _render();
  }

  Future<void> _render() async {
    final revision = ++_revision;
    setState(() => _working = true);
    try {
      final image = await MaskEngine.apply(widget.original, List.of(_strokes));
      if (!mounted || revision != _revision) return;
      setState(() {
        _preview = image;
        _working = false;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not render eraser: $error')),
      );
    }
  }

  List<double> _point(Offset local, Size canvas) => [
        (local.dx / canvas.width).clamp(0.0, 1.0),
        (local.dy / canvas.height).clamp(0.0, 1.0),
      ];

  void _begin(Offset p, Size size) => setState(() {
        _current = [_point(p, size)];
      });

  void _move(Offset p, Size size) => setState(() {
        _current.add(_point(p, size));
      });

  void _finish() {
    if (_current.isEmpty) return;
    setState(() {
      _strokes = [..._strokes, MaskStroke(points: _current, radius: _radius)];
      _current = [];
    });
    _render();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erase layer'),
        actions: [
          IconButton(
            tooltip: 'Undo last eraser stroke',
            onPressed: _working || _strokes.isEmpty ? null : () {
              setState(() => _strokes = _strokes.sublist(0, _strokes.length - 1));
              _render();
            },
            icon: const Icon(Icons.undo),
          ),
          TextButton(
            onPressed: _working ? null : () {
              setState(() => _strokes = []);
              _render();
            },
            child: const Text('Restore all'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text('Drag over unwanted lines. Changes remain editable.'),
            ),
            if (_working) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = math.max(1.0, constraints.maxWidth - 24);
                  final availableHeight = math.max(1.0, constraints.maxHeight - 24);
                  final width = math.min(availableWidth, availableHeight * _aspect);
                  final height = width / _aspect;
                  final size = Size(width, height);
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _EraserCheckerPainter()),
                          Image.memory(_preview ?? widget.original,
                              fit: BoxFit.fill, gaplessPlayback: true),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _working ? null :
                                (details) => _begin(details.localPosition, size),
                            onPanUpdate: _working ? null :
                                (details) => _move(details.localPosition, size),
                            onPanEnd: _working ? null : (_) => _finish(),
                            onTapDown: _working ? null : (details) {
                              _begin(details.localPosition, size);
                              _finish();
                            },
                            child: CustomPaint(
                              painter: _CurrentStrokePainter(_current, _radius),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('Brush'),
                  Expanded(
                    child: Slider(
                      min: 0.005,
                      max: 0.1,
                      value: _radius,
                      divisions: 19,
                      onChanged: (value) => setState(() => _radius = value),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _working ? null : () =>
                    Navigator.of(context).pop(_strokes),
                icon: const Icon(Icons.check),
                label: const Text('Apply to layer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentStrokePainter extends CustomPainter {
  const _CurrentStrokePainter(this.points, this.radius);
  final List<List<double>> points;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xAA00A4CF)
      ..strokeWidth = radius * math.min(size.width, size.height) * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(
        points.first[0] * size.width, points.first[1] * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point[0] * size.width, point[1] * size.height);
    }
    if (points.length == 1) {
      canvas.drawCircle(
          Offset(points.first[0] * size.width, points.first[1] * size.height),
          paint.strokeWidth / 2, Paint()..color = paint.color);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CurrentStrokePainter oldDelegate) => true;
}

class _EraserCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFFFFFFFF));
    final dark = Paint()..color = const Color(0xFFD5D9DE);
    for (var row = 0; row < (size.height / cell).ceil(); row++) {
      for (var col = row % 2; col < (size.width / cell).ceil(); col += 2) {
        canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), dark);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _EraserCheckerPainter oldDelegate) => false;
}
