import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// v0.8 proof of concept: a bundled, completely offline WebGL limb viewer.
/// The tattoo image comes from the current project composition.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key, required this.artworkPng});
  final Uint8List artworkPng;

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  late final WebViewController _controller;
  bool _ready = false;
  double _opacity = 0.9;
  double _size = 0.65;
  double _rotation = 0;
  String? _error;

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
          } else {
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
          if (mounted) setState(() => _error = error.description);
        },
      ))
      ..loadFlutterAsset('assets/placement/viewer.html');
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
              if (!_ready)
                const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.amber),
                    textAlign: TextAlign.center),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: [
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
                    });
                    _syncPlacement();
                  },
                  child: const Text('Reset'),
                ),
              ]),
              _slider('Size', _size, .15, 1.5, (v) => _size = v),
              _slider('Rotation', _rotation, -180, 180, (v) => _rotation = v),
              _slider('Opacity', _opacity, 0, 1, (v) => _opacity = v),
              const Text(
                'Proof of concept: curved generic forearm, not your anatomy. '
                'Placement is not saved yet. Rotate by dragging.',
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
        },
      )),
      SizedBox(width: 44, child: Text(value.toStringAsFixed(1))),
    ]);
  }
}
