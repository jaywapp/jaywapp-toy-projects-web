import 'package:flutter/foundation.dart';

class PerfSpan {
  PerfSpan(this.name);

  final String name;
  Stopwatch? _watch;

  PerfSpan start() {
    if (kDebugMode) {
      _watch = Stopwatch()..start();
    }
    return this;
  }

  void end([String? note]) {
    final watch = _watch;
    if (!kDebugMode || watch == null) return;
    watch.stop();
    final suffix = (note == null || note.isEmpty) ? '' : ' ($note)';
    debugPrint('[PERF] $name: ${watch.elapsedMilliseconds}ms$suffix');
  }
}
