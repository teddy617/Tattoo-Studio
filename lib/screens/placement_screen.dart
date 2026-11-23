import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/placement_repository.dart';

/// v0.8 proof of concept: a bundled, completely offline WebGL limb viewer.
/// The tattoo image comes from the current project composition.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({
    super.key, required this.artworkPng, required this.projectId,
  });
  final Uint8List artworkPng;
  final String projectId;

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
  String? _error;
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
            _sendArtwork().then((_) => _restoreState());
          } else if (message.message.startsWith('{')) {
            try {
              final data = jsonDecode(message.message) as Map<String, dynamic>;
              if (data['type'] == 'state') {
                _anchor = {
                  'point': data['point'],
                  'normal': data['normal'],
                };
                _saveState();
              }
            } catch (_) { /* Ignore malformed WebView messages. */ }
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
      ..loadFlutterAsset('assets/placement/viewer.html');
  }

  Future<void> _restoreState() async {
    final saved = await _repository.read(widget.projectId);
    if (!mounted || saved == null) return;
    setState(() {
      _opacity = ((saved['opacity'] as num?)?.toDouble() ?? .9).clamp(0, 1);
      _size = ((saved['scale'] as num?)?.toDouble() ?? .65).clamp(.15, 1.5);
      _rotation = ((saved['rotation'] as num?)?.toDouble() ?? 0).clamp(-180, 180);
      _depth = ((saved['depth'] as num?)?.toDouble() ?? .6).clamp(.15, 1.2);
    });
    _anchor = {
      if (saved['point'] is List) 'point': saved['point'],
      if (saved['normal'] is List) 'normal': saved['normal'],
    };
    await _controller.runJavaScript('restorePlacement('
        + jsonEncode(jsonEncode({...saved, ..._anchor})) + ')');
  }

  void _saveState() {
    final snapshot = <String, dynamic>{
      'opacity': _opacity,
      'scale': _size,
      'rotation': _rotation,
      'depth': _depth,
      ..._anchor,
    };
    _saveChain = _saveChain.then(
      (_) => _repository.write(widget.projectId, snapshot),
    ).catchError((Object error) {
      debugPrint('Could not save 3D placement: $error');
    });
  }

  Future<void> _sendArtwork() async {
    if (!_ready) return;
    final uri = 'data:image/png;base64,' + base64Encode(widget.artworkPng);
    await _controller.runJavaScript('setTattoo(' + jsonEncode(uri) + ')');
    await _syncPlacement();
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
      appBar: AppBar(title: const Text('3D Placement — prototype')),
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
                              'assets/placement/viewer.html',
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
              _slider('Size', _size, .15, 1.5, (v) => _size = v),
              _slider('Rotation', _rotation, -180, 180, (v) => _rotation = v),
              _slider('Opacity', _opacity, 0, 1, (v) => _opacity = v),
              _slider('Wrap depth', _depth, .15, 1.2, (v) => _depth = v),
              const Text(
                'Prototype mannequin, not your anatomy. Orbit to rotate or '
                'Place to tap the limb. Placement saves automatically.',
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
