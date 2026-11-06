import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
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
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Developer — map site (debug only)',
            style: PixelType.title(context),
          ),
          SizedBox(height: grid.px(2)),
          PixelTextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            label: 'Map site origin',
            hint: 'http://127.0.0.1:3120',
          ),
          if (_message != null) ...[
            SizedBox(height: grid.px(1)),
            Text(
              _message!,
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
          ],
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelButton(
                onPressed: _busy ? null : _save,
                variant: PixelButtonVariant.secondary,
                label: 'Save map site',
              ),
              PixelButton(
                onPressed: _busy ? null : () => _save(reset: true),
                variant: PixelButtonVariant.secondary,
                label: 'Reset map site',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
