import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/smart_extract.dart';

enum ImportKind { smart, rectangle, lasso, split, unchanged }

/// Users approve the processed result before any layer is added.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.source, required this.initialMode});
  final XFile source;
  final ImportKind initialMode;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  Uint8List? _original;
  List<ExtractedArtwork> _result = [];
  late ImportKind _kind;
  bool _working = false;
  bool _showResult = true;
  bool _removeWhite = true;
  bool _detectSelection = false;
  Set<int> _chosenPieces = {};
  int _threshold = 242;
  int _imageWidth = 1;
  int _imageHeight = 1;
  Offset? _start;
  Offset? _end;
  List<Offset> _lasso = [];
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialMode;
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw const FormatException('Unsupported image.');
      if (!mounted) return;
      setState(() {
        _original = bytes;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
      });
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cannot open image: $e')));
      }
    }
  }

  ExtractionSelection? get _selection {
    if (_kind == ImportKind.rectangle && _start != null && _end != null) {
      final a = _start!;
      final b = _end!;
      if ((a - b).distance < 0.01) return null;
      return ExtractionSelection(rectangle: true, points: [
        NormalizedPoint(math.min(a.dx, b.dx), math.min(a.dy, b.dy)),
        NormalizedPoint(math.max(a.dx, b.dx), math.max(a.dy, b.dy)),
      ]);
    }
    if (_kind == ImportKind.lasso && _lasso.length >= 3) {
      return ExtractionSelection(
        points: _lasso.map((p) => NormalizedPoint(p.dx, p.dy)).toList(),
      );
    }
    return null;
  }

  Future<void> _refresh() async {
    final bytes = _original;
    if (bytes == null) return;
    final token = ++_requestId;
    setState(() => _working = true);
    try {
      final pieces = await SmartExtract.process(
        bytes,
        splitSheet: _kind == ImportKind.split || (_detectSelection && _selection != null),
        keepBackground: _kind == ImportKind.unchanged || !_removeWhite,
        forceWhiteRemoval: _removeWhite && _kind != ImportKind.unchanged,
        whiteThreshold: _threshold,
        selection: _selection,
      );
      if (!mounted || token != _requestId) return;
      setState(() {
        _result = pieces;
        _chosenPieces = {for (var i = 0; i < pieces.length; i++) i};
        _working = false;
      });
    } catch (e) {
      if (!mounted || token != _requestId) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
    }
  }

  Offset _normalized(Offset position, Size size) => Offset(
        (position.dx / size.width).clamp(0.0, 1.0),
        (position.dy / size.height).clamp(0.0, 1.0),
      );

  void _newMode(ImportKind? next) {
    if (next == null) return;
    ++_requestId;
    setState(() {
      _kind = next;
      _start = null;
      _end = null;
      _lasso = [];
      _detectSelection = false;
      _chosenPieces = {};
      _showResult = next != ImportKind.rectangle && next != ImportKind.lasso;
      _result = [];
    });
    if (_showResult) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final original = _original;
    final selecting = _kind == ImportKind.rectangle || _kind == ImportKind.lasso;
    final selectionReady = _selection != null;
    final aspect = _imageWidth / _imageHeight;
    return Scaffold(
      appBar: AppBar(title: const Text('Extract artwork')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: DropdownButtonFormField<ImportKind>(
                value: _kind,
                decoration: const InputDecoration(
                  labelText: 'Extraction method',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: ImportKind.smart, child: Text('Smart Crop')),
                  DropdownMenuItem(value: ImportKind.rectangle, child: Text('Rectangle')),
                  DropdownMenuItem(value: ImportKind.lasso, child: Text('Lasso')),
                  DropdownMenuItem(value: ImportKind.split, child: Text('Split Sheet')),
                  DropdownMenuItem(value: ImportKind.unchanged, child: Text('Keep original')),
                ],
                onChanged: _working ? null : _newMode,
              ),
            ),
            if (_kind != ImportKind.unchanged) ...[
              SwitchListTile(
                dense: true,
                title: const Text('Remove white background'),
                value: _removeWhite,
                onChanged: (value) {
                  setState(() => _removeWhite = value);
                  if (!selecting || selectionReady) _refresh();
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  const Text('Sensitivity'),
                  Expanded(
                    child: Slider(
                      min: 220,
                      max: 252,
                      divisions: 32,
                      value: _threshold.toDouble(),
                      label: '$_threshold',
                      onChanged: (value) => setState(
                          () => _threshold = value.round()),
                      onChangeEnd: (_) {
                        if (!selecting || selectionReady) _refresh();
                      },
                    ),
                  ),
                ]),
              ),
            ],
            if (_kind == ImportKind.smart)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Screenshot? Select only the artwork before removing its background.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _working ? null :
                          () => _newMode(ImportKind.rectangle),
                      child: const Text('Select area'),
                    ),
                  ],
                ),
              ),
            if (selecting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Text(
                  _kind == ImportKind.rectangle
                      ? 'Drag a box around the artwork, then tap Preview.'
                      : 'Draw around the artwork in one stroke, then tap Preview.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (selecting && selectionReady)
              SwitchListTile(
                dense: true,
                title: const Text('Detect multiple designs within selection'),
                value: _detectSelection,
                onChanged: _working ? null : (value) => setState(() {
                  _detectSelection = value;
                  _result = [];
                  _chosenPieces = {};
                  _showResult = false;
                }),
              ),
            if (!selecting)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Original')),
                  ButtonSegment(value: true, label: Text('Result')),
                ],
                selected: {_showResult},
                onSelectionChanged: (values) =>
                    setState(() => _showResult = values.first),
              ),
            Expanded(
              child: Center(
                child: original == null
                    ? const CircularProgressIndicator()
                    : LayoutBuilder(builder: (context, constraints) {
                        final availableWidth = math.max(1.0, constraints.maxWidth - 24);
                        final availableHeight = math.max(1.0, constraints.maxHeight - 24);
                        final width = math.min(availableWidth, availableHeight * aspect);
                        final height = width / aspect;
                        final size = Size(width, height);
                        final preview = _result.isEmpty ? null : _result.first.pngBytes;
                        return SizedBox(
                          width: width,
                          height: height,
                          child: Stack(fit: StackFit.expand, children: [
                            CustomPaint(painter: _CheckerboardPainter()),
                            if (!_showResult || preview == null)
                              Image.memory(original, fit: BoxFit.fill)
                            else
                              Image.memory(preview, fit: BoxFit.contain),
                            if (selecting && !_showResult)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) {
                                  final p = _normalized(details.localPosition, size);
                                  setState(() {
                                    _result = [];
                                    _start = p;
                                    _end = p;
                                    _lasso = [p];
                                  });
                                },
                                onPanUpdate: (details) {
                                  final p = _normalized(details.localPosition, size);
                                  setState(() {
                                    if (_kind == ImportKind.rectangle) {
                                      _end = p;
                                    } else {
                                      _lasso.add(p);
                                    }
                                  });
                                },
                                child: CustomPaint(
                                  painter: _SelectionPainter(
                                    kind: _kind,
                                    start: _start,
                                    end: _end,
                                    lasso: _lasso,
                                  ),
                                  size: size,
                                ),
                              ),
                          ]),
                        );
                      }),
              ),
            ),
            if (_result.length > 1 && _showResult)
              SizedBox(
                height: 94,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _result.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => FilterChip(
                    selected: _chosenPieces.contains(index),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _chosenPieces.add(index);
                      } else {
                        _chosenPieces.remove(index);
                      }
                    }),
                    label: SizedBox(
                      width: 64,
                      height: 58,
                      child: Image.memory(_result[index].pngBytes,
                          fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            if (_working) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                if (selecting) ...[
                  OutlinedButton(
                    onPressed: _working ? null : () {
                      setState(() {
                        _start = null;
                        _end = null;
                        _lasso = [];
                        _result = [];
                        _showResult = false;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: !_working && selectionReady ? () async {
                      await _refresh();
                      if (mounted) setState(() => _showResult = true);
                    } : null,
                    child: const Text('Preview'),
                  ),
                ],
                const Spacer(),
                FilledButton.icon(
                  onPressed: _working || _result.isEmpty || _chosenPieces.isEmpty ||
                          (selecting && !_showResult)
                      ? null
                      : () => Navigator.pop(context, [
                          for (var i = 0; i < _result.length; i++)
                            if (_chosenPieces.contains(i)) _result[i],
                        ]),
                  icon: const Icon(Icons.add),
                  label: Text('Add ${_chosenPieces.length} layer${_chosenPieces.length == 1 ? '' : 's'}'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({
    required this.kind,
    required this.start,
    required this.end,
    required this.lasso,
  });
  final ImportKind kind;
  final Offset? start;
  final Offset? end;
  final List<Offset> lasso;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF078FCE)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    if (kind == ImportKind.rectangle && start != null && end != null) {
      final a = Offset(start!.dx * size.width, start!.dy * size.height);
      final b = Offset(end!.dx * size.width, end!.dy * size.height);
      canvas.drawRect(Rect.fromPoints(a, b), paint);
    } else if (kind == ImportKind.lasso && lasso.length > 1) {
      final path = Path()..moveTo(lasso.first.dx * size.width,
          lasso.first.dy * size.height);
      for (final p in lasso.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) => true;
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFFFFFFFF));
    final shaded = Paint()..color = const Color(0xFFD5D9DE);
    for (var row = 0; row < (size.height / cell).ceil(); row++) {
      for (var column = row % 2;
          column < (size.width / cell).ceil(); column += 2) {
        canvas.drawRect(
            Rect.fromLTWH(column * cell, row * cell, cell, cell), shaded);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}
