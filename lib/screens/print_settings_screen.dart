import 'package:flutter/material.dart';

import '../services/print_export.dart';

/// Width is measured across visible artwork after trimming transparent space.
class PrintSettingsScreen extends StatefulWidget {
  const PrintSettingsScreen({
    super.key,
    this.stencil = false,
    this.initialTransparent = false,
  });

  final bool stencil;
  final bool initialTransparent;

  @override
  State<PrintSettingsScreen> createState() => _PrintSettingsScreenState();
}

class _PrintSettingsScreenState extends State<PrintSettingsScreen> {
  bool _centimeters = false;
  late bool _transparent;
  double _inches = 4;
  int _dpi = 300;

  @override
  void initState() {
    super.initState();
    _transparent = widget.initialTransparent;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _centimeters ? _inches * 2.54 : _inches;
    final unit = _centimeters ? 'cm' : 'in';
    return Scaffold(
      appBar: AppBar(title: Text(widget.stencil
          ? 'Stencil print size' : 'Artwork print size')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Width applies to the visible tattoo artwork, '
              'after empty transparent margins are removed.',
            ),
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Inches')),
                ButtonSegment(value: true, label: Text('Centimeters')),
              ],
              selected: {_centimeters},
              onSelectionChanged: (values) =>
                  setState(() => _centimeters = values.first),
            ),
            const SizedBox(height: 18),
            Text(
              'Artwork width: ' + shown.toStringAsFixed(1) + ' ' + unit,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _inches,
              min: 0.5,
              max: 8,
              divisions: 30,
              onChanged: (value) => setState(() => _inches = value),
            ),
            const Text('Resolution'),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 150, label: Text('150 DPI')),
                ButtonSegment(value: 300, label: Text('300 DPI')),
              ],
              selected: {_dpi},
              onSelectionChanged: (values) =>
                  setState(() => _dpi = values.first),
            ),
            const SizedBox(height: 8),
            Text('Width: ' + (_inches * _dpi).round().toString() + ' pixels'),
            const SizedBox(height: 12),
            if (!widget.stencil)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Transparent background'),
                value: _transparent,
                onChanged: (value) =>
                    setState(() => _transparent = value),
              ),
            if (widget.stencil)
              const Text('Stencil preview provides its own '
                  'threshold and background controls.'),
            const SizedBox(height: 12),
            const Text(
              'Print at Actual Size / 100%. Disable Fit to Page or automatic '
              'scaling. Some viewers ignore PNG DPI metadata; verify '
              'size with a ruler or test print before tattoo use.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(PrintOptions(
                widthInches: _inches,
                dpi: _dpi,
                transparent: widget.stencil ? true : _transparent,
              )),
              icon: const Icon(Icons.check),
              label: Text(widget.stencil
                  ? 'Prepare stencil' : 'Export sized PNG'),
            ),
          ],
        ),
      ),
    );
  }
}
