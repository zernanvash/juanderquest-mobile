import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(
          Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  await load('Silkscreen', ['assets/fonts/Silkscreen-Regular.ttf']);
  await load('Monocraft',
      ['assets/fonts/Monocraft.ttf', 'assets/fonts/Monocraft-Bold.ttf']);
  await testMain();
}
