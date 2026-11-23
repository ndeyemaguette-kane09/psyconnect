import 'dart:async';

import 'package:flutter/widgets.dart';

import '../storage/offline_cache.dart';

mixin AutoRefresh<T extends StatefulWidget> on State<T> {
  static const _interval = Duration(seconds: 60);
  static const _offlineInterval = Duration(seconds: 15);

  Timer? _timer;
  late final _ResumeObserver _observer = _ResumeObserver(_refreshIfVisible);
  DateTime _lastRefresh = DateTime.now();
  bool _refreshing = false;

  Future<void> autoRefresh();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_observer);
    _timer = Timer.periodic(_offlineInterval, (_) {
      final due = DateTime.now().difference(_lastRefresh) >= _interval;
      if (due || OfflineCache.isOffline.value) _refreshIfVisible();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  Future<void> _refreshIfVisible() async {
    if (!mounted || _refreshing) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _refreshing = true;
    _lastRefresh = DateTime.now();
    try {
      await autoRefresh();
    } catch (_) {
    } finally {
      _refreshing = false;
    }
  }
}

class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);

  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
