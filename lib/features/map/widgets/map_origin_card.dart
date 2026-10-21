import 'package:flutter/material.dart';
import '../../../core/widgets/primary_button.dart';
import '../engine/style_loader.dart';

class MapOriginCard extends StatefulWidget {
  const MapOriginCard({super.key});
  @override
  State<MapOriginCard> createState() => _MapOriginCardState();
}

class _MapOriginCardState extends State<MapOriginCard> {
  final _controller = TextEditingController();
  String? _message;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    MapOriginStore.read().then((value) {
      if (mounted) _controller.text = value;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool reset = false}) async {
    setState(() => _busy = true);
    try {
      if (reset) {
        await MapOriginStore.clear();
        _controller.text = mapSiteOrigin;
      } else {
        await MapOriginStore.write(_controller.text);
      }
      if (mounted) {
        setState(() => _message = 'Saved. Reopen Map to reload the style.');
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _message = 'Use a site origin, e.g. http://127.0.0.1:3120');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Developer — map site (debug only)'),
            TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Map site origin',
                    hintText: 'http://127.0.0.1:3120')),
            if (_message != null) Text(_message!),
            Wrap(spacing: 8, children: [
              SecondaryButton(
                  onPressed: _busy ? null : _save,
                  fullWidth: false,
                  label: 'Save map site'),
              SecondaryButton(
                  onPressed: _busy ? null : () => _save(reset: true),
                  fullWidth: false,
                  label: 'Reset map site'),
            ]),
          ])));
}
