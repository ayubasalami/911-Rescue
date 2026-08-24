import 'package:flutter_riverpod/flutter_riverpod.dart';

class FacilityDetailViewModel extends Notifier<bool> {
  @override
  bool build() => false;
}

final facilityDetailViewModelProvider =
    NotifierProvider<FacilityDetailViewModel, bool>(FacilityDetailViewModel.new);
