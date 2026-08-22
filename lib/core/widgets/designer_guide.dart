import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Global provider to toggle Designer Guide Mode ON/OFF
final designerGuideProvider = StateProvider<bool>((ref) => false);

/// Detailed specification metadata for UI/UX designers and frontend developers
class UiSpec {
  final String title;
  final String figmaLayer;
  final String dimensions;
  final String dataBinding;
  final String stateNotes;
  final String uxNotes;
  final bool deferred;

  const UiSpec({
    required this.title,
    required this.figmaLayer,
    required this.dimensions,
    required this.dataBinding,
    required this.stateNotes,
    required this.uxNotes,
    this.deferred = false,
  });
}

/// A wrapper widget that conditionally displays blueprint wireframe outlines
/// and an interactive inspection chip when Designer Guide Mode is ON.
class UiSpecContainer extends ConsumerWidget {
  final UiSpec spec;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const UiSpecContainer({
    super.key,
    required this.spec,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuideEnabled = ref.watch(designerGuideProvider);

    if (!isGuideEnabled) {
      return child;
    }

    final radius = borderRadius ?? AppSpacing.roundedXl;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Blueprint Outline Container
          Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: spec.deferred ? const Color(0xFFE63946) : const Color(0xFF0096C7),
                width: 1.5,
              ),
              color: (spec.deferred ? const Color(0xFFE63946) : const Color(0xFF0096C7)).withOpacity(0.04),
            ),
            child: child,
          ),

          // Interactive Spec Chip (Top Right)
          Positioned(
            top: -10,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showSpecSheet(context, spec),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: spec.deferred ? const Color(0xFFE63946) : const Color(0xFF0096C7),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.design_services_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        spec.figmaLayer,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.info_outline_rounded, size: 11, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showSpecSheet(BuildContext context, UiSpec spec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UiSpecBottomSheet(spec: spec),
    );
  }
}

/// Polished Bottom Sheet Inspector detailing component specs
class _UiSpecBottomSheet extends StatelessWidget {
  final UiSpec spec;

  const _UiSpecBottomSheet({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Deep Blueprint Slate
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: spec.deferred ? const Color(0xFFE63946).withOpacity(0.2) : const Color(0xFF0096C7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  spec.deferred ? Icons.construction_rounded : Icons.palette_outlined,
                  size: 20,
                  color: spec.deferred ? const Color(0xFFFF6B6B) : const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          spec.figmaLayer,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: spec.deferred ? const Color(0xFFFF8787) : const Color(0xFF7DD3FC),
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (spec.deferred) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE63946),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PROTOTYPE PLACEHOLDER',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Spec Details Grid
          _buildSpecRow(
            icon: Icons.aspect_ratio_rounded,
            title: 'Dimensions & Asset Specs',
            value: spec.dimensions,
            accentColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 12),

          _buildSpecRow(
            icon: Icons.data_object_rounded,
            title: 'Backend API & Data Binding',
            value: spec.dataBinding,
            accentColor: const Color(0xFF34D399),
          ),
          const SizedBox(height: 12),

          _buildSpecRow(
            icon: Icons.sync_alt_rounded,
            title: 'Interactive States',
            value: spec.stateNotes,
            accentColor: const Color(0xFFFBBF24),
          ),
          const SizedBox(height: 12),

          _buildSpecRow(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Designer & UX Guidelines',
            value: spec.uxNotes,
            accentColor: const Color(0xFFA78BFA),
          ),

          const SizedBox(height: 18),

          // Copy Spec Tag Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Figma Layer Tag to Clipboard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: spec.figmaLayer));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied "${spec.figmaLayer}" to clipboard'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF0096C7),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE2E8F0),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Draggable Floating HUD toggle button for Designer Guide Mode
class DesignerGuideFloatingHud extends ConsumerStatefulWidget {
  final Widget child;

  const DesignerGuideFloatingHud({super.key, required this.child});

  @override
  ConsumerState<DesignerGuideFloatingHud> createState() => _DesignerGuideFloatingHudState();
}

class _DesignerGuideFloatingHudState extends ConsumerState<DesignerGuideFloatingHud> {
  double _x = 16.0;
  double _y = 100.0;
  bool _hasInitializedPos = false;

  @override
  Widget build(BuildContext context) {
    final isGuideEnabled = ref.watch(designerGuideProvider);
    final size = MediaQuery.of(context).size;

    if (!_hasInitializedPos && size.width > 0) {
      _x = size.width - 130.0;
      _y = size.height - 140.0;
      _hasInitializedPos = true;
    }

    return Stack(
      children: [
        widget.child,

        // Draggable HUD Button
        Positioned(
          left: _x.clamp(8.0, (size.width - 124.0).clamp(8.0, double.infinity)),
          top: _y.clamp(40.0, (size.height - 70.0).clamp(40.0, double.infinity)),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _x += details.delta.dx;
                _y += details.delta.dy;
              });
            },
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  final next = !isGuideEnabled;
                  ref.read(designerGuideProvider.notifier).state = next;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        next
                          ? '🎨 Designer Guide Mode: ENABLED (Tap any blueprint tag for specs)'
                          : '🎨 Designer Guide Mode: DISABLED',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: next ? const Color(0xFF0096C7) : AppColors.woodBrown,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isGuideEnabled
                        ? const Color(0xFF0096C7)
                        : const Color(0xFF1E293B).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isGuideEnabled ? Colors.white : Colors.white24,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGuideEnabled ? Icons.palette_rounded : Icons.palette_outlined,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isGuideEnabled ? 'GUIDE ON' : 'UI GUIDE',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
