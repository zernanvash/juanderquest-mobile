import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../trail/models/trail_models.dart';
import '../providers/navigation_provider.dart';

class OriginPickerSheet extends StatefulWidget {
  final NavOrigin currentOrigin;
  final ValueChanged<NavOrigin> onSelect;
  final bool? avoidCongested;
  final VoidCallback? onToggleAvoidCongested;
  final int selectedDetoursCount;
  final VoidCallback? onOpenDetours;

  const OriginPickerSheet({
    super.key,
    required this.currentOrigin,
    required this.onSelect,
    this.avoidCongested,
    this.onToggleAvoidCongested,
    this.selectedDetoursCount = 0,
    this.onOpenDetours,
  });

  static Future<void> show(
    BuildContext context, {
    required NavOrigin currentOrigin,
    required ValueChanged<NavOrigin> onSelect,
    bool? avoidCongested,
    VoidCallback? onToggleAvoidCongested,
    int selectedDetoursCount = 0,
    VoidCallback? onOpenDetours,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => OriginPickerSheet(
        currentOrigin: currentOrigin,
        onSelect: onSelect,
        avoidCongested: avoidCongested,
        onToggleAvoidCongested: onToggleAvoidCongested,
        selectedDetoursCount: selectedDetoursCount,
        onOpenDetours: onOpenDetours,
      ),
    );
  }

  @override
  State<OriginPickerSheet> createState() => _OriginPickerSheetState();
}

class _OriginPickerSheetState extends State<OriginPickerSheet> {
  late bool _avoidCongested;

  @override
  void initState() {
    super.initState();
    _avoidCongested = widget.avoidCongested ?? true;
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
              padding: EdgeInsets.fromLTRB(
                  grid.px(3), grid.px(2), grid.px(3), grid.px(1)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'ROUTE OPTIONS',
                      style: PixelType.title(context,
                          color: PixelPalette.woodDeep),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  if (widget.onToggleAvoidCongested != null) ...[
                    PixelPanel(
                      style: PixelBoxStyle.parchment,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUIET ROADS',
                                  style: PixelType.body(context,
                                          color: PixelPalette.woodDeep)
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Avoid tourist bottlenecks',
                                  style: PixelType.small(context,
                                      color: PixelPalette.woodMid),
                                ),
                              ],
                            ),
                          ),
                          PixelSwitch(
                            key: const ValueKey('nav_anti_crowd'),
                            value: _avoidCongested,
                            onChanged: (val) {
                              setState(() => _avoidCongested = val);
                              widget.onToggleAvoidCongested!();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: grid.px(1)),
                  ],
                  if (widget.onOpenDetours != null) ...[
                    PixelButton(
                      key: const ValueKey('origin_picker_detours'),
                      label: widget.selectedDetoursCount > 0
                          ? '+ SCENIC DETOURS (${widget.selectedDetoursCount})'
                          : '+ SCENIC DETOURS',
                      variant: PixelButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onOpenDetours!();
                      },
                    ),
                    SizedBox(height: grid.px(1)),
                  ],
                  // GPS option
                  _buildOption(
                    context,
                    title: 'MY GPS LOCATION',
                    subtitle: 'Use device live location',
                    isSelected: widget.currentOrigin.isGps,
                    onTap: () {
                      widget.onSelect(const NavOrigin(
                        name: 'My Location',
                        point: kDefaultOrigin,
                        isGps: true,
                      ));
                      Navigator.of(context).pop();
                    },
                  ),
                  SizedBox(height: grid.px(1)),

                  Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: grid.px(1), horizontal: grid.px(1)),
                    child: Text(
                      'POPULAR STARTING HUBS',
                      style:
                          PixelType.small(context, color: PixelPalette.woodMid),
                    ),
                  ),

                  // Gateway origins
                  for (final origin in kTripOrigins) ...[
                    _buildOption(
                      context,
                      title: origin.name.toUpperCase(),
                      subtitle:
                          '${origin.lat.toStringAsFixed(4)}, ${origin.lng.toStringAsFixed(4)}',
                      isSelected: !widget.currentOrigin.isGps &&
                          widget.currentOrigin.name == origin.name,
                      onTap: () {
                        widget.onSelect(NavOrigin(
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
