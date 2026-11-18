import 'dart:async';
import 'dart:convert';

import 'package:juanderquest_app/core/realtime/realtime_service.dart';

class FakeRealtimeChannel implements RealtimeChannel {
  FakeRealtimeChannel(this.uri);

  final Uri uri;
  final _controller = StreamController<dynamic>();
  final List<Map<String, dynamic>> sent = [];
  bool closed = false;

  @override
  int? closeCode;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void send(String message) =>
      sent.add(Map<String, dynamic>.from(jsonDecode(message) as Map));

  void emit(Map<String, dynamic> event) => _controller.add(jsonEncode(event));

  /// Server-side close.
  void drop([int? code]) {
    closeCode = code;
    _controller.close();
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) await _controller.close();
  }
}

class FakeConnector {
  final List<FakeRealtimeChannel> channels = [];

  FakeRealtimeChannel get last => channels.last;

  RealtimeChannel call(Uri uri) {
    final channel = FakeRealtimeChannel(uri);
    channels.add(channel);
    return channel;
  }
}
