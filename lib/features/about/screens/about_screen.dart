import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final List<String> _authors = const [
    'Ana Victoria V. Alentajan',
    'Zernan Vash L. Arive',
    'Clarissa Angel A. Gutlay',
    'Carl Jacob Lavaro',
    'Alyana Soriano',
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'About',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        grid.gutter,
                        grid.px(3),
                        grid.gutter,
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PixelPanel(
                            style: PixelBoxStyle.wood,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Universidad de Dagupan',
                                  style: PixelType.title(
                                    context,
                                    color: PixelPalette.paper,
                                  ),
                                ),
                                SizedBox(height: grid.px(1)),
                                Text(
                                  'JuanDerQuest: A Gamified Blockchain-based System for Promoting Tourist Destinations in Pangasinan',
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.sun,
                                  ),
                                ),
                                SizedBox(height: grid.px(1)),
                                Text(
                                  'School of Information Technology Education (SITE)\nCapstone Research Prototype 2026',
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.cream,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: grid.px(3)),
                          PixelPanel(
                            style: PixelBoxStyle.parchment,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const PixelSectionTitle(
                                  'Tri-party tourism flywheel',
                                ),
                                SizedBox(height: grid.px(1)),
                                _flywheelRow(
                                  context,
                                  grid,
                                  'Travelers & Explorers',
                                  'Complete GPS quest trails and earn demo mJDQ rewards. Soulbound badges are under development.',
                                ),
                                Container(
                                  height: grid.unit,
                                  color: PixelPalette.paperDim,
                                ),
                                _flywheelRow(
                                  context,
                                  grid,
                                  'Local MSME Merchants',
                                  'Fund discount vouchers with zero upfront costs; enjoy foot traffic diverted away from crowded hotspots.',
                                ),
                                Container(
                                  height: grid.unit,
                                  color: PixelPalette.paperDim,
                                ),
                                _flywheelRow(
                                  context,
                                  grid,
                                  'Municipal LGUs & Tourism Boards',
                                  'Balance tourism distribution, prevent overcrowding, and sponsor event campaigns with locked escrow pools.',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: grid.px(3)),
                          PixelPanel(
                            style: PixelBoxStyle.parchment,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PixelSectionTitle(
                                  'Research authors & development team',
                                  value: '${_authors.length}',
                                  valueColor: PixelPalette.greenDark,
                                ),
                                SizedBox(height: grid.px(1)),
                                for (var i = 0; i < _authors.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                      height: grid.unit,
                                      color: PixelPalette.paperDim,
                                    ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: grid.px(2),
                                    ),
                                    child: Text(
                                      _authors[i],
                                      style: PixelType.title(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _flywheelRow(
      BuildContext context, PixelGrid grid, String title, String body) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: grid.px(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: PixelType.title(context, color: PixelPalette.greenDark)),
          SizedBox(height: grid.px(1)),
          Text(body, style: PixelType.body(context, color: PixelPalette.slate)),
        ],
      ),
    );
  }
}
