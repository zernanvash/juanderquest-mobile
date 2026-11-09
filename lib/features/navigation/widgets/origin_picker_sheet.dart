import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../providers/navigation_provider.dart';

class OriginPickerSheet extends StatelessWidget {
  final NavOrigin currentOrigin;
  final ValueChanged<NavOrigin> onSelect;

  const OriginPickerSheet({
    super.key,
    required this.currentOrigin,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required NavOrigin currentOrigin,
    required ValueChanged<NavOrigin> onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => OriginPickerSheet(
        currentOrigin: currentOrigin,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.75,
      ),
      margin: EdgeInsets.only(bottom: media.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: PixelPalette.paper,
        border: Border(
          top: BorderSide(color: PixelPalette.woodDeep, width: 3),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(grid.px(3), grid.px(2), grid.px(3), grid.px(1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CHOOSE STARTING POINT',
                    style: PixelType.title(context, color: PixelPalette.woodDeep),
                  ),
                  PixelButton(
                    key: const ValueKey('origin_picker_close'),
                    label: 'X',
                    variant: PixelButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: PixelPalette.woodLight, height: 1),

            Expanded(
              child: ListView(
                padding: EdgeInsets.all(grid.px(2)),
                children: [
                  // GPS option
                  _buildOption(
                    context,
                    title: 'MY GPS LOCATION',
                    subtitle: 'Use device live location',
                    isSelected: currentOrigin.isGps,
                    onTap: () {
                      onSelect(const NavOrigin(
                        name: 'My Location',
                        point: kDefaultOrigin,
                        isGps: true,
                      ));
                      Navigator.of(context).pop();
                    },
                  ),
                  SizedBox(height: grid.px(1)),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: grid.px(1), horizontal: grid.px(1)),
                    child: Text(
                      'POPULAR STARTING HUBS',
                      style: PixelType.small(context, color: PixelPalette.woodMid),
                    ),
                  ),

                  // Gateway origins
                  for (final origin in kTripOrigins) ...[
                    _buildOption(
                      context,
                      title: origin.name.toUpperCase(),
                      subtitle: '${origin.lat.toStringAsFixed(4)}, ${origin.lng.toStringAsFixed(4)}',
                      isSelected: !currentOrigin.isGps && currentOrigin.name == origin.name,
                      onTap: () {
                        onSelect(NavOrigin(
                          name: origin.name,
                          point: origin.point,
                          isGps: false,
                        ));
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(height: grid.px(1)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: PixelPanel(
        style: isSelected ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: PixelType.body(
                      context,
                      color: isSelected ? PixelPalette.woodDeep : PixelPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: PixelType.small(
                      context,
                      color: isSelected ? PixelPalette.woodDeep : PixelPalette.woodMid,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const PixelChip(
                'SELECTED',
                style: PixelBoxStyle.wood,
              ),
          ],
        ),
      ),
    );
  }
}
