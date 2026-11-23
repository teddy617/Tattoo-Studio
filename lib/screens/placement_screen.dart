import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/placement_repository.dart';
import '../services/project_repository.dart';
import '../models/design_project.dart';

/// Offline WebGL placement studio using a procedural full-body mannequin.
/// The tattoo image comes from the current project composition.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({
    super.key, required this.artworkPng, required this.projectId,
    required this.project,
  });
  final Uint8List artworkPng;
  final String projectId;
  final DesignProject project;

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  late final WebViewController _controller;
  bool _ready = false;
  double _opacity = 0.9;
  double _size = 0.65;
  double _rotation = 0;
  double _depth = 0.6;
  bool _placeMode = false;
  String _viewPart = 'full';
  static const Map<String, String> _regions = {
    'full': 'Full body',
    'head': 'Head',
    'chest': 'Chest',
    'back': 'Upper back',
    'abdomen': 'Abdomen',
    'pelvis': 'Hips',
    'leftUpperArm': 'Left upper arm',
    'rightUpperArm': 'Right upper arm',
    'leftForearm': 'Left forearm',
    'rightForearm': 'Right forearm',
    'leftHand': 'Left hand',
    'rightHand': 'Right hand',
    'leftThigh': 'Left thigh',
    'rightThigh': 'Right thigh',
    'leftCalf': 'Left calf',
    'rightCalf': 'Right calf',
    'leftFoot': 'Left foot',
    'rightFoot': 'Right foot',
  };
  String? _error;
  bool _restoring = false;
  String _activeTattooId = 'current';
  List<Map<String, dynamic>> _tattoos = [
    {'id': 'current', 'name': 'Current design'},
  ];
  List<Map<String, dynamic>> _tattooStates = [];
  final ProjectRepository _projectRepository = ProjectRepository();
  final ImagePicker _imagePicker = ImagePicker();
  final PlacementRepository _repository = PlacementRepository();
  Map<String, dynamic> _anchor = {};
  Future<void> _saveChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF202127))
      ..addJavaScriptChannel(
        'PlacementBridge',
        onMessageReceived: (message) {
          if (!mounted) return;
          if (message.message == 'ready') {
            setState(() {
              _ready = true;
              _error = null;
            });
            _initializeViewer();
          } else if (message.message.startsWith('{')) {
            try {
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              if (data['type'] == 'state') {
                _tattooStates = (data['tattoos'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
                if (data['activeId'] is String) {
                  _activeTattooId = data['activeId'] as String;
                }
                if (data['viewPart'] is String &&
                    _regions.containsKey(data['viewPart'])) {
                  setState(() => _viewPart = data['viewPart'] as String);
                }
                final active = _tattooStates.where(
                  (t) => t['id'] == _activeTattooId,
                );
                if (active.isNotEmpty) {
                  final t = active.first;
                  setState(() {
                    _size = ((t['scale'] as num?)?.toDouble() ?? .65).clamp(.15, 1.5);
                    _rotation = ((t['rotation'] as num?)?.toDouble() ?? 0).clamp(-180, 180);
                    _opacity = ((t['opacity'] as num?)?.toDouble() ?? .9).clamp(0, 1);
                    _depth = ((t['depth'] as num?)?.toDouble() ?? .65).clamp(.15, 1.2);
                  });
                }
                if (!_restoring) _saveState();
              }
            } catch (error) {
              debugPrint('3D placement message: $error');
            }
          } else if (message.message != 'placed') {
            setState(() => _error = message.message);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri?.host == 'appassets.androidplatform.net') {
            return NavigationDecision.navigate;
          }
          if (uri?.scheme == 'http' || uri?.scheme == 'https') {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == false) return;
          if (mounted) setState(() => _error = error.description);
        },
        onPageFinished: (_) async {
          // Detect failed script initialization instead of spinning forever.
          await Future<void>.delayed(const Duration(seconds: 3));
          if (mounted && !_ready && _error == null) {
            setState(() => _error = '3D viewer could not initialize. Tap Retry.');
          }
        },
      ))
      ..loadFlutterAsset('assets/placement/full_body.html');
  }

  Future<void> _initializeViewer() async {
    _restoring = true;
    try {
      final saved = await _repository.read(widget.projectId);
      if (saved != null && mounted) {
        final stored = (saved['tattoos'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .where((t) => t['id'] is String)
            .toList();
        if (stored.isNotEmpty) {
          _tattoos = stored.map((record) => {
            'id': record['id'],
            'name': record['name'] ?? 'Tattoo',
            if (record['path'] is String) 'path': record['path'],
          }).toList();
          if (!_tattoos.any((t) => t['id'] == 'current')) {
            _tattoos.insert(0, {'id': 'current', 'name': 'Current design'});
          }
        }
      }
      if (!mounted) return;
      await _sendArtwork();
      for (final tattoo in _tattoos) {
        if (tattoo['id'] == 'current' || tattoo['path'] is! String) continue;
        try {
          final bytes = await _projectRepository.readAsset(
            widget.projectId, tattoo['path'] as String,
          );
          await _controller.runJavaScript('addTattoo(' +
              jsonEncode(tattoo['id']) + ',' +
              jsonEncode('data:image/png;base64,' + base64Encode(bytes)) +
              ',null)');
        } catch (error) {
          debugPrint('Placement image could not load: $error');
        }
      }
      if (saved != null) {
        _tattooStates = (saved['tattoos'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _activeTattooId = saved['activeId'] is String
            ? saved['activeId'] as String : 'current';
        _viewPart = _regions.containsKey(saved['viewPart'])
            ? saved['viewPart'] as String : 'full';
        if (mounted) setState(() {});
        await _controller.runJavaScript('restorePlacement(' +
            jsonEncode(jsonEncode(saved)) + ')');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Placement loading failed: $error');
    } finally {
      _restoring = false;
    }
  }

  void _saveState() {
    if (_restoring) return;
    final previous = {for (final t in _tattooStates) t['id']: t};
    final snapshot = <String, dynamic>{
      'activeId': _activeTattooId,
      'viewPart': _viewPart,
      'tattoos': _tattoos.map((t) => {
        ...t,
        ...?previous[t['id']],
      }).toList(),
    };
    _saveChain = _saveChain.then(
      (_) => _repository.write(widget.projectId, snapshot),
    ).catchError((Object error) {
      debugPrint('Could not save placement: $error');
    });
  }

  Future<void> _selectTattoo(String id) async {
    setState(() => _activeTattooId = id);
    await _controller.runJavaScript('selectTattoo(' + jsonEncode(id) + ')');
  }

  Future<void> _addPng(Uint8List data, String name) async {
    if (_tattoos.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 12 tattoos per preview')),
      );
      return;
    }
    try {
      final bytes = await compute(_prepareTattooTexture, data);
      final id = makeId();
      final path = await _projectRepository.writeLayerAsset(
        widget.projectId, id, bytes,
      );
      if (!mounted) return;
      setState(() {
        _tattoos.add({'id': id, 'name': name, 'path': path});
        _activeTattooId = id;
      });
      await _controller.runJavaScript('addTattoo(' +
          jsonEncode(id) + ',' +
          jsonEncode('data:image/png;base64,' + base64Encode(bytes)) +
          ',null)');
      _saveState();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add tattoo: $error')),
        );
      }
    }
  }

  Future<void> _addFromGallery() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _addPng(bytes, picked.name);
  }

  Future<void> _addProjectLayer() async {
    if (widget.project.layers.isEmpty) return;
    final layer = await showModalBottomSheet<DesignLayer>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Choose a project layer')),
            for (final item in widget.project.layers)
              ListTile(
                title: Text(item.name),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (layer == null) return;
    final bytes = await _projectRepository.readAsset(
      widget.projectId, layer.assetPath,
    );
    await _addPng(bytes, layer.name);
  }

  Future<void> _removeSelected() async {
    final id = _activeTattooId;
    if (id == 'current') return;
    await _controller.runJavaScript('removeTattoo(' + jsonEncode(id) + ')');
    setState(() {
      _tattoos.removeWhere((t) => t['id'] == id);
      _activeTattooId = 'current';
    });
    _saveState();
  }

  Future<void> _sendArtwork() async {
    if (!_ready) return;
    final uri = 'data:image/png;base64,' + base64Encode(widget.artworkPng);
    await _controller.runJavaScript('setTattoo(' + jsonEncode(uri) + ')');
  }

  Future<void> _syncPlacement() async {
    if (!_ready) return;
    final data = jsonEncode({
      'opacity': _opacity,
      'scale': _size,
      'rotation': _rotation,
      'depth': _depth,
    });
    await _controller.runJavaScript('setPlacement(' + jsonEncode(data) + ')');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D Placement Studio')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: WebViewWidget(controller: _controller)),
              if (!_ready && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                        style: const TextStyle(color: Colors.amber),
                        textAlign: TextAlign.center),
                      if (!_ready)
                        TextButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _controller.loadFlutterAsset(
                              'assets/placement/full_body.html',
                            );
                          },
                          child: const Text('Retry 3D viewer'),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: [
              Row(children: [
                Expanded(child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Orbit')),
                    ButtonSegment(value: true, label: Text('Place')),
                  ],
                  selected: {_placeMode},
                  onSelectionChanged: (values) {
                    setState(() => _placeMode = values.first);
                    _controller.runJavaScript('setMode(' +
                        jsonEncode(_placeMode ? 'place' : 'orbit') + ')');
                  },
                )),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  const Text('View  '),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _viewPart,
                      isExpanded: true,
                      items: _regions.entries
                          .map((entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ))
                          .toList(),
                      onChanged: !_ready ? null : (value) {
                        if (value == null) return;
                        setState(() => _viewPart = value);
                        _controller.runJavaScript('selectPart(' +
                            jsonEncode(value) + ')');
                        _saveState();
                      },
                    ),
                  ),
                ]),
              ),
              Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _ready ? _sendArtwork : null,
                    icon: const Icon(Icons.layers),
                    label: const Text('Place current design'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _size = .65;
                      _rotation = 0;
                      _opacity = .9;
                      _depth = .6;
                    });
                    _syncPlacement();
                    _controller.runJavaScript('resetPlacement()');
                    _saveState();
                  },
                  child: const Text('Reset'),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _tattoos.any((t) => t['id'] == _activeTattooId)
                        ? _activeTattooId : 'current',
                    isExpanded: true,
                    items: _tattoos.map((t) => DropdownMenuItem<String>(
                      value: t['id'] as String,
                      child: Text(t['name'] as String,
                        overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: !_ready ? null : (value) {
                      if (value != null) _selectTattoo(value);
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Add tattoo',
                  enabled: _ready,
                  icon: const Icon(Icons.add_circle_outline),
                  onSelected: (choice) {
                    if (choice == 'gallery') _addFromGallery();
                    if (choice == 'layer') _addProjectLayer();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'gallery',
                        child: Text('Add from gallery')),
                    PopupMenuItem(value: 'layer',
                        child: Text('Add project layer')),
                  ],
                ),
                IconButton(
                  tooltip: 'Remove selected tattoo',
                  onPressed: !_ready || _activeTattooId == 'current'
                      ? null : _removeSelected,
                  icon: const Icon(Icons.delete_outline),
                ),
              ]),
              _slider('Size', _size, .15, 1.5, (v) => _size = v),
              _slider('Rotation', _rotation, -180, 180, (v) => _rotation = v),
              _slider('Opacity', _opacity, 0, 1, (v) => _opacity = v),
              _slider('Wrap depth', _depth, .15, 1.2, (v) => _depth = v),
              const Text(
                'Select a tattoo to adjust it separately. Add designs from '
                'the gallery or project layers. Anatomical proportions are approximate.',
                style: TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> setter) {
    return Row(children: [
      SizedBox(width: 76, child: Text(label)),
      Expanded(child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) {
          setState(() => setter(v));
          _syncPlacement();
          _saveState();
        },
      )),
      SizedBox(width: 44, child: Text(value.toStringAsFixed(1))),
    ]);
  }
}


/// Reduce image sizes to avoid mobile GPU texture exhaustion.
Uint8List _prepareTattooTexture(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) throw const FormatException('Unsupported image');
  final oriented = img.bakeOrientation(original);
  final resized = oriented.width > 1200 || oriented.height > 1200
      ? img.copyResize(oriented,
          width: oriented.width >= oriented.height ? 1200 : null,
          height: oriented.height > oriented.width ? 1200 : null)
      : oriented;
  return Uint8List.fromList(img.encodePng(resized));
}
