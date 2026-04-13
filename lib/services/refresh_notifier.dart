import 'package:flutter/foundation.dart';

/// Increment this notifier after any write operation to signal
/// all listening screens to reload their data.
final appRefresh = ValueNotifier<int>(0);

void notifyDataChanged() => appRefresh.value++;
