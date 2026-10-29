import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Plan 66: the old coordinate form is retired. `/spots/new` now opens map-first posting
/// (crosshair aim, recognized place, one-page composer) on the map tab.
class AddSpotScreen extends StatefulWidget {
  const AddSpotScreen({super.key});

  @override
  State<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends State<AddSpotScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/map?post=1');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Opening the map to add a spot…')),
    );
  }
}
