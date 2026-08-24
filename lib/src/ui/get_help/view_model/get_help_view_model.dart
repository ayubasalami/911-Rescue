import 'package:flutter_riverpod/flutter_riverpod.dart';

class GetHelpViewModel extends Notifier<bool> {
  @override
  bool build() => false;
}

final getHelpViewModelProvider = NotifierProvider<GetHelpViewModel, bool>(GetHelpViewModel.new);
