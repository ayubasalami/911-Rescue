import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardViewModel extends Notifier<bool> {
  @override
  bool build() => false;
}

final dashboardViewModelProvider =
    NotifierProvider<DashboardViewModel, bool>(DashboardViewModel.new);
