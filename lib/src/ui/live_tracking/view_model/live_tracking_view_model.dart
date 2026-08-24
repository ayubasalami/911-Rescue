import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiveTrackingViewModel extends Notifier<bool> {
  @override
  bool build() => false;
}

final liveTrackingViewModelProvider =
    NotifierProvider<LiveTrackingViewModel, bool>(LiveTrackingViewModel.new);
