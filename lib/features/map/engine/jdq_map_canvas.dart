import 'dart:async';
import 'package:flutter/material.dart';
import 'jdq_map.dart';

/// One load per mount, bounded including platform creation, no Future in build.
class JdqMapCanvas extends StatefulWidget {
  const JdqMapCanvas(
      {super.key,
      required this.map,
      required this.style,
      required this.fallback,
      required this.onFallback,
      this.timeout = const Duration(seconds: 10)});
  final JdqMap map;
  final Future<String> style;
  final Widget fallback;
  final VoidCallback onFallback;
  final Duration timeout;
  @override
  State<JdqMapCanvas> createState() => _JdqMapCanvasState();
}

class _JdqMapCanvasState extends State<JdqMapCanvas> {
  Timer? _deadline;
  bool _basic = false, _styleReady = false;
  @override
  void initState() {
    super.initState();
    _deadline = Timer(widget.timeout, _fail);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final style = await widget.style;
      if (!mounted || _basic) return;
      await widget.map.setStyle(style);
      if (mounted && !_basic) setState(() => _styleReady = true);
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _basic) return;
    _deadline?.cancel();
    setState(() => _basic = true);
    widget.onFallback();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        if (_basic)
          widget.fallback
        else if (_styleReady)
          widget.map.build(
              onReady: () => _deadline?.cancel(),
              onFailure: () =>
                  WidgetsBinding.instance.addPostFrameCallback((_) => _fail()))
        else
          const Center(child: CircularProgressIndicator()),
        if (_basic)
          const Positioned(
              left: 8,
              bottom: 32,
              child: IgnorePointer(
                  child: Card(
                      child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Basic map'))))),
        if (!_basic)
          const Positioned(
              left: 8,
              bottom: 4,
              child: IgnorePointer(
                  child: ColoredBox(
                      color: Color(0xddffffff),
                      child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Text(
                              '© OpenStreetMap contributors · © OpenMapTiles',
                              style: TextStyle(fontSize: 10)))))),
      ]);
}
