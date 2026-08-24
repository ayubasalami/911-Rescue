import 'package:flutter_riverpod/flutter_riverpod.dart';

class TriageChatViewModel extends Notifier<bool> {
  @override
  bool build() => false;
}

final triageChatViewModelProvider =
    NotifierProvider<TriageChatViewModel, bool>(TriageChatViewModel.new);
