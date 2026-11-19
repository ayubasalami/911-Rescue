import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../data/models/ping.dart';
import '../../../data/models/responder.dart';
import '../../../data/services/responder_service.dart';
import 'responder_auth_view_model.dart';

/// The history's tiles double as filters, as on the web.
enum HistoryFilter { all, resolved, fastest }

class ResponderHistoryState {
  const ResponderHistoryState({
    this.history,
    this.loading = false,
    this.expanded = false,
    this.filter = HistoryFilter.all,
  });

  final ResponderHistory? history;
  final bool loading;
  final bool expanded;
  final HistoryFilter filter;

  /// The entries the chosen tile shows: all, resolved only, or those that
  /// were accepted, quickest first.
  List<ResponderPing> get visible {
    final entries = history?.entries ?? const <ResponderPing>[];
    return switch (filter) {
      HistoryFilter.all => entries,
      HistoryFilter.resolved =>
        entries.where((e) => e.status == PingStatus.resolved).toList(),
      HistoryFilter.fastest =>
        entries.where((e) => e.acceptDelay != null).toList()
          ..sort((a, b) => a.acceptDelay!.compareTo(b.acceptDelay!)),
    };
  }

  ResponderHistoryState copyWith({
    ResponderHistory? history,
    bool? loading,
    bool? expanded,
    HistoryFilter? filter,
  }) => ResponderHistoryState(
    history: history ?? this.history,
    loading: loading ?? this.loading,
    expanded: expanded ?? this.expanded,
    filter: filter ?? this.filter,
  );
}

final responderHistoryViewModelProvider =
    NotifierProvider<ResponderHistoryViewModel, ResponderHistoryState>(
      ResponderHistoryViewModel.new,
    );

/// "My ping history": loaded with the console for its total, and again each
/// time it's opened, as the web does.
class ResponderHistoryViewModel extends Notifier<ResponderHistoryState> {
  @override
  ResponderHistoryState build() {
    final responder = ref.watch(
      responderAuthViewModelProvider.select((auth) => auth.value?.responderId),
    );
    if (responder != null) Future.microtask(load);
    return const ResponderHistoryState();
  }

  Future<void> load() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true);
    final result = await ref.read(responderServiceProvider).history();
    if (!ref.mounted) return;
    switch (result) {
      case Ok(:final value):
        state = state.copyWith(history: value, loading: false);
      case Err(:final failure):
        state = state.copyWith(loading: false);
        ref
            .read(responderAuthViewModelProvider.notifier)
            .handleFailure(failure);
    }
  }

  void toggle() {
    final expanded = !state.expanded;
    state = state.copyWith(expanded: expanded);
    if (expanded) load();
  }

  void filterBy(HistoryFilter filter) => state = state.copyWith(filter: filter);
}
