import 'dart:async';

import 'package:flutter/foundation.dart';

class FirestoreMetrics {
  FirestoreMetrics._();

  static final FirestoreMetrics instance = FirestoreMetrics._();

  int _reads = 0;
  int _writes = 0;
  int _listens = 0;
  Timer? _periodic;

  int get reads => _reads;
  int get writes => _writes;
  int get listens => _listens;

  void addReads([int count = 1]) {
    if (!kDebugMode) return;
    _reads += count;
  }

  void addWrites([int count = 1]) {
    if (!kDebugMode) return;
    _writes += count;
  }

  void addListens([int count = 1]) {
    if (!kDebugMode) return;
    _listens += count;
  }

  void reset() {
    if (!kDebugMode) return;
    _reads = 0;
    _writes = 0;
    _listens = 0;
  }

  void dump([String scope = 'all']) {
    if (!kDebugMode) return;
    debugPrint('[FS][$scope] reads=$_reads writes=$_writes listens=$_listens');
  }

  void startPeriodicDump({Duration interval = const Duration(seconds: 20)}) {
    if (!kDebugMode || _periodic != null) return;
    _periodic = Timer.periodic(interval, (_) => dump('periodic'));
  }

  void stopPeriodicDump() {
    _periodic?.cancel();
    _periodic = null;
  }
}
