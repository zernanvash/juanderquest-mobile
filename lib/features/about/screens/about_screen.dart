import 'package:flutter/material.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
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
                    title: 'About JuanDerQuest',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
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
                          Text('Tri-party tourism flywheel',
                              style: PixelType.title(context)),
                          SizedBox(height: grid.px(2)),
                          _flywheel(
                            context,
                            grid,
                            'Travelers & Explorers',
                            'Complete GPS quest trails and earn demo mJDQ rewards. Soulbound badges are under development.',
                          ),
                          SizedBox(height: grid.px(2)),
                          _flywheel(
                            context,
                            grid,
                            'Local MSME Merchants',
                            'Fund discount vouchers with zero upfront costs; enjoy foot traffic diverted away from crowded hotspots.',
                          ),
                          SizedBox(height: grid.px(2)),
                          _flywheel(
                            context,
                            grid,
                            'Municipal LGUs & Tourism Boards',
                            'Balance tourism distribution, prevent overcrowding, and sponsor event campaigns with locked escrow pools.',
                          ),
                          SizedBox(height: grid.px(3)),
                          Text('Research authors & development team',
                              style: PixelType.title(context)),
                          SizedBox(height: grid.px(2)),
                          for (final author in _authors) ...[
                            PixelPanel(
                              style: PixelBoxStyle.parchment,
                              child: Row(
                                children: [
                                  PixelPanel(
                                    style: PixelBoxStyle.gold,
                                    padding: 1,
                                    child: SizedBox(
                                      width: grid.px(9),
                                      child: Text(
                                        author.substring(0, 1),
                                        textAlign: TextAlign.center,
                                        style: PixelType.title(context),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: grid.px(2)),
                                  Expanded(
                                    child: Text(
                                      author,
                                      style: PixelType.title(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: grid.px(1)),
                          ],
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

  Widget _flywheel(
      BuildContext context, PixelGrid grid, String title, String body) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
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
