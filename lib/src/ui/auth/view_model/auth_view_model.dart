import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthViewModel extends Notifier<bool> {
  @override
  bool build() => false;
}

final authViewModelProvider = NotifierProvider<AuthViewModel, bool>(AuthViewModel.new);
