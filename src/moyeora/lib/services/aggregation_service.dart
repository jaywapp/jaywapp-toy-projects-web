import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../config/firebase_config.dart';
import 'functions_caller.dart';

class AggregationService {
  AggregationService._();

  static final Set<String> _inFlight = <String>{};
  static final Map<String, DateTime> _lastRequestedAt = <String, DateTime>{};
  static const Duration _minimumInterval = Duration(minutes: 2);

  static Future<void> requestRecompute({
    required String groupId,
    required String periodKey,
  }) async {
    final key = '$groupId:$periodKey';
    final now = DateTime.now();
    final lastRequested = _lastRequestedAt[key];
    if (lastRequested != null &&
        now.difference(lastRequested) < _minimumInterval) {
      return;
    }
    if (_inFlight.contains(key)) {
      return;
    }

    _inFlight.add(key);
    _lastRequestedAt[key] = now;
    try {
      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('recomputeGroupPeriodStats').call(<String, dynamic>{
          'groupId': groupId,
          'periodKey': periodKey,
        }),
      );
      if (kDebugMode) {
        debugPrint(
          '[AGG] recompute requested group=$groupId period=$periodKey',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('[AGG] recompute failed ${e.code}: ${e.message}');
      }
    } finally {
      _inFlight.remove(key);
    }
  }
}
