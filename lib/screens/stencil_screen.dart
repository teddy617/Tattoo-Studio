import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/project_repository.dart';
import '../services/stencil_processor.dart';

/// Produces a preview/export from the current composition without modifying
/// any saved layers. The canvas capture is supplied by EditorScreen.
class StencilScreen extends StatefulWidget {
  const StencilScreen({
    super.key,
    required this.compositePng,
    required this.projectId,
  });

  final Uint8List compositePng;
  final String projectId;

  @override
  State<StencilScreen> createState() => _StencilScreenState();
}

class _StencilScreenState extends State<StencilScreen> {
  int _threshold = 150;
  bool _transparent = false;
  bool _removeNoise = false;
  bool _busy = false;
  Uint8List? _result;
  int _revision = 0;
  final _repository = ProjectRepository();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    setState(() => _busy = true);
    try {
      final output = await StencilProcessor.process(
        widget.compositePng,
        threshold: _threshold,
        transparent: _transparent,
        removeIsolatedPixels: _removeNoise,
      );
      if (!mounted || _revision != revision) return;
      setState(() {
        _result = output;
        _busy = false;
      });
    } catch (error) {
      if (!mounted || _revision != revision) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stencil processing failed: $error')),
      );
    }
  }

  Future<void> _share() async {
    final result = _result;
    if (_busy || result == null) return;
    setState(() => _busy = true);
    try {
      final file = await _repository.writeExport(widget.projectId, result);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Tattoo Studio stencil preview — verify sizing before printing',
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share stencil: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stencil preparation')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Preview black linework. The original design is never changed.',
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Text('Line threshold'),
                Expanded(
                  child: Slider(
                    value: _threshold.toDouble(),
                    min: 45,
                    max: 230,
                    divisions: 37,
                    label: '$_threshold',
                    onChanged: (value) => setState(
                      () => _threshold = value.round(),
                    ),
                    onChangeEnd: (_) => _refresh(),
                  ),
                ),
              ]),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Transparent background'),
              value: _transparent,
              onChanged: (value) {
                setState(() => _transparent = value);
                _refresh();
              },
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Remove isolated noise pixels'),
              subtitle: const Text('May remove tiny intentional dots.'),
              value: _removeNoise,
              onChanged: (value) {
                setState(() => _removeNoise = value);
                _refresh();
              },
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Container(
                color: const Color(0xFFDBDBDB),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: _result == null
                    ? const CircularProgressIndicator()
                    : Image.memory(
                        _result!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'This is a raster preview, not an automatic transfer-ready stencil. '
                'Confirm final physical size and fine-line detail before use.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('Export stencil PNG'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
