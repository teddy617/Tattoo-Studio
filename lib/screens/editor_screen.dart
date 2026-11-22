import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/design_project.dart';
import '../services/project_repository.dart';
import '../services/smart_extract.dart';

enum _ImportMode { smartCrop, splitSheet, unchanged }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.project});

  final DesignProject project;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final ProjectRepository _repository = ProjectRepository();
  final GlobalKey _artboardKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final Map<String, Uint8List> _images = {};
  final List<List<DesignLayer>> _undo = [];
  final List<List<DesignLayer>> _redo = [];

  late DesignProject _project;
  Future<void> _saveChain = Future<void>.value();
  String? _selectedId;
  DesignLayer? _gestureStart;
  Offset _gestureDrag = Offset.zero;
  double _boardScale = 1;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _readLayerImages();
  }

  Future<void> _readLayerImages() async {
    for (final layer in _project.layers) {
      if (_images.containsKey(layer.assetPath)) continue;
      try {
        final image = await _repository.readAsset(_project.id, layer.assetPath);
        if (!mounted) return;
        setState(() => _images[layer.assetPath] = image);
      } catch (error) {
        debugPrint('Could not load ${layer.assetPath}: $error');
      }
    }
  }

  DesignLayer? get _selected {
    for (final layer in _project.layers) {
      if (layer.id == _selectedId) return layer;
    }
    return null;
  }

  void _checkpoint() {
    _undo.add(List<DesignLayer>.of(_project.layers));
    if (_undo.length > 35) _undo.removeAt(0);
    _redo.clear();
  }

  void _persist() {
    _project.updatedAt = DateTime.now();
    final snapshot = DesignProject(
      id: _project.id,
      name: _project.name,
      updatedAt: _project.updatedAt,
      layers: List<DesignLayer>.of(_project.layers),
    );
    _saveChain = _saveChain.then((_) => _repository.save(snapshot)).catchError(
      (Object error) => debugPrint('Project save failed: $error'),
    );
  }

  void _change(VoidCallback action) {
    _checkpoint();
    setState(action);
    _persist();
  }

  void _undoAction() {
    if (_undo.isEmpty) return;
    _redo.add(List<DesignLayer>.of(_project.layers));
    setState(() => _project.layers = _undo.removeLast());
    _persist();
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    _undo.add(List<DesignLayer>.of(_project.layers));
    setState(() => _project.layers = _redo.removeLast());
    _persist();
  }

  void _editSelected(DesignLayer Function(DesignLayer) transform) {
    final index = _project.layers.indexWhere((layer) => layer.id == _selectedId);
    if (index < 0 || _project.layers[index].locked) return;
    _change(() {
      _project.layers[index] = transform(_project.layers[index]);
    });
  }

  Future<void> _import(_ImportMode mode) async {
    if (_busy) return;
    try {
      List<XFile> picks;
      if (mode == _ImportMode.splitSheet) {
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        picks = picked == null ? [] : [picked];
      } else {
        picks = await _picker.pickMultiImage();
      }
      if (picks.isEmpty || !mounted) return;
      setState(() => _busy = true);
      _checkpoint();
      var added = 0;
      for (final file in picks.take(12)) {
        final extracted = await SmartExtract.process(
          await file.readAsBytes(),
          splitSheet: mode == _ImportMode.splitSheet,
          keepBackground: mode == _ImportMode.unchanged,
        );
        for (final artwork in extracted) {
          final id = makeId();
          final path = await _repository.writeLayerAsset(
            _project.id,
            id,
            artwork.pngBytes,
          );
          final fit = math.min(
            620 / artwork.width,
            820 / artwork.height,
          );
          final width = artwork.width * fit;
          final height = artwork.height * fit;
          final shift = (added % 7) * 18.0;
          final layer = DesignLayer(
            id: id,
            name: extracted.length > 1
                ? '${file.name} · ${added + 1}'
                : file.name,
            assetPath: path,
            x: (canvasWidth - width) / 2 + shift,
            y: (canvasHeight - height) / 2 + shift,
            width: width,
            height: height,
          );
          if (!mounted) return;
          setState(() {
            _images[path] = artwork.pngBytes;
            _project.layers.add(layer);
            _selectedId = id;
          });
          added++;
        }
      }
      _persist();
      if (mounted) _toast('Added $added editable layer${added == 1 ? '' : 's'}');
    } catch (error) {
      if (mounted) _toast('Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _beginGesture(DesignLayer layer) {
    if (layer.locked) return;
    _checkpoint();
    _gestureStart = layer;
    _gestureDrag = Offset.zero;
    setState(() => _selectedId = layer.id);
  }

  void _updateGesture(DesignLayer layer, ScaleUpdateDetails details) {
    final start = _gestureStart;
    if (start == null || layer.locked || start.id != layer.id) return;
    _gestureDrag += details.focalPointDelta / _boardScale;
    final zoom = details.scale.clamp(0.12, 8.0).toDouble();
    final width = (start.width * zoom).clamp(24.0, 2400.0).toDouble();
    final height = (start.height * zoom).clamp(24.0, 3200.0).toDouble();
    final index = _project.layers.indexWhere((item) => item.id == layer.id);
    if (index < 0) return;
    setState(() {
      _project.layers[index] = start.copyWith(
        x: start.x + _gestureDrag.dx + (start.width - width) / 2,
        y: start.y + _gestureDrag.dy + (start.height - height) / 2,
        width: width,
        height: height,
        rotation: start.rotation + details.rotation,
      );
    });
  }

  void _endGesture(DesignLayer layer) {
    if (_gestureStart?.id != layer.id) return;
    _gestureStart = null;
    _persist();
  }

  void _duplicate() {
    final original = _selected;
    if (original == null) return;
    final duplicate = DesignLayer(
      id: makeId(),
      name: '${original.name} copy',
      assetPath: original.assetPath,
      x: original.x + 35,
      y: original.y + 35,
      width: original.width,
      height: original.height,
      rotation: original.rotation,
      flipX: original.flipX,
    );
    _change(() {
      _project.layers.add(duplicate);
      _selectedId = duplicate.id;
    });
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    _change(() {
      _project.layers.removeWhere((layer) => layer.id == _selectedId);
      _selectedId = null;
    });
    // Kept asset files can still be referenced by undo/redo or duplicates.
  }

  void _moveSelected(int amount) {
    final index = _project.layers.indexWhere((layer) => layer.id == _selectedId);
    final target = index + amount;
    if (index < 0 || target < 0 || target >= _project.layers.length) return;
    _change(() {
      final layer = _project.layers.removeAt(index);
      _project.layers.insert(target, layer);
    });
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Design name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Name your tattoo design'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _project.name = name);
    _persist();
  }

  Future<void> _exportPng() async {
    if (_busy) return;
    final previousSelection = _selectedId;
    try {
      setState(() {
        _busy = true;
        _selectedId = null;
      });
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _artboardKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Canvas is not ready.');
      }
      final rendered = await boundary.toImage(pixelRatio: 2);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      rendered.dispose();
      if (data == null) throw StateError('Could not export canvas.');
      final png = data.buffer.asUint8List();
      final file = await _repository.writeExport(_project.id, png);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '${_project.name} — Tattoo Studio',
      ));
    } catch (error) {
      if (mounted) _toast('Export failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _selectedId = previousSelection;
        });
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLayers() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, sheetSetState) {
          final reversed = _project.layers.reversed.toList();
          return SafeArea(
            child: SizedBox(
              height: math.min(MediaQuery.sizeOf(context).height * 0.68, 540.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Text('Layers', style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        Text('${reversed.length} elements'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: reversed.isEmpty
                        ? const Center(child: Text('No layers yet. Import an image.'))
                        : ListView.builder(
                            itemCount: reversed.length,
                            itemBuilder: (context, index) {
                              final layer = reversed[index];
                              final selected = layer.id == _selectedId;
                              return ListTile(
                                selected: selected,
                                dense: true,
                                leading: IconButton(
                                  tooltip: layer.visible ? 'Hide layer' : 'Show layer',
                                  onPressed: () {
                                    _change(() {
                                      final i = _project.layers.indexWhere(
                                        (item) => item.id == layer.id,
                                      );
                                      _project.layers[i] = layer.copyWith(
                                        visible: !layer.visible,
                                      );
                                    });
                                    sheetSetState(() {});
                                  },
                                  icon: Icon(layer.visible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                ),
                                title: Text(layer.name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () {
                                  setState(() => _selectedId = layer.id);
                                  Navigator.pop(sheetContext);
                                },
                                trailing: Wrap(
                                  spacing: 0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    IconButton(
                                      tooltip: layer.locked ? 'Unlock' : 'Lock',
                                      onPressed: () {
                                        _change(() {
                                          final i = _project.layers.indexWhere(
                                            (item) => item.id == layer.id,
                                          );
                                          _project.layers[i] = layer.copyWith(
                                            locked: !layer.locked,
                                          );
                                        });
                                        sheetSetState(() {});
                                      },
                                      icon: Icon(layer.locked
                                          ? Icons.lock_outline
                                          : Icons.lock_open_outlined),
                                    ),
                                    if (selected) const Icon(Icons.check_circle_outline),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLayer(DesignLayer layer) {
    if (!layer.visible) return const SizedBox.shrink();
    final bytes = _images[layer.assetPath];
    if (bytes == null) return const SizedBox.shrink();
    final isSelected = layer.id == _selectedId;
    return Positioned(
      left: layer.x,
      top: layer.y,
      child: Transform.rotate(
        angle: layer.rotation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedId = layer.id),
          onScaleStart: layer.locked ? null : (_) => _beginGesture(layer),
          onScaleUpdate: layer.locked
              ? null
              : (details) => _updateGesture(layer, details),
          onScaleEnd: layer.locked ? null : (_) => _endGesture(layer),
          child: Container(
            width: layer.width,
            height: layer.height,
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: const Color(0xFF2B76BE), width: 3)
                  : null,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(layer.flipX ? -1 : 1, 1, 1),
              child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(BoxConstraints constraints) {
    _boardScale = math.min(
      (constraints.maxWidth - 24) / canvasWidth,
      (constraints.maxHeight - 24) / canvasHeight,
    );
    return Container(
      color: const Color(0xFFE9E9E6),
      padding: const EdgeInsets.all(12),
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: RepaintBoundary(
              key: _artboardKey,
              child: Container(
                color: Colors.white,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (final layer in _project.layers) _buildLayer(layer),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _rename,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_project.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined, size: 17),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: _undo.isNotEmpty ? _undoAction : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redo.isNotEmpty ? _redoAction : null,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: 'Export PNG',
            onPressed: _busy ? null : _exportPng,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  PopupMenuButton<_ImportMode>(
                    tooltip: 'Import artwork',
                    enabled: !_busy,
                    onSelected: _import,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ImportMode.smartCrop,
                        child: Text('Smart Crop · remove white and trim'),
                      ),
                      PopupMenuItem(
                        value: _ImportMode.splitSheet,
                        child: Text('Split Sheet · separate designs'),
                      ),
                      PopupMenuItem(
                        value: _ImportMode.unchanged,
                        child: Text('Import unchanged'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      child: Row(
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined),
                          const SizedBox(width: 6),
                          Text('Import',
                              style: Theme.of(context).textTheme.labelLarge),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showLayers,
                    icon: const Icon(Icons.layers_outlined),
                    label: Text('Layers (${_project.layers.length})'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: LayoutBuilder(builder: (context, c) => _buildCanvas(c))),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 76,
                child: selected == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Import artwork, then drag to move. Pinch to resize or rotate.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _tool(Icons.rotate_right, 'Rotate 90°',
                                selected.locked
                                    ? null
                                    : () => _editSelected((layer) => layer.copyWith(
                                          rotation: layer.rotation + math.pi / 2,
                                        ))),
                            _tool(Icons.flip, 'Mirror',
                                selected.locked
                                    ? null
                                    : () => _editSelected((layer) => layer.copyWith(
                                          flipX: !layer.flipX,
                                        ))),
                            _tool(Icons.content_copy, 'Duplicate', _duplicate),
                            _tool(Icons.vertical_align_top, 'Forward',
                                () => _moveSelected(1)),
                            _tool(Icons.vertical_align_bottom, 'Backward',
                                () => _moveSelected(-1)),
                            _tool(Icons.delete_outline, 'Delete', _deleteSelected),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback? action) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: label,
              onPressed: action,
              icon: Icon(icon),
              visualDensity: VisualDensity.compact,
            ),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}
