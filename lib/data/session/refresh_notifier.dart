// data/session/refresh_notifier.dart
import 'package:flutter/material.dart';

class RefreshNotifier {
  // Notifier global untuk memicu refresh data
  static final ValueNotifier<int> refreshCounter = ValueNotifier<int>(0);

  static void triggerRefresh() {
    refreshCounter.value++;
  }
}