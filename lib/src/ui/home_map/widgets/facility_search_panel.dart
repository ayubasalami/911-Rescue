import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics_events.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/facility.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/services/place_search_service.dart';
import '../../core/widgets/facility_category_glyph.dart';
import 'map_legend.dart' show FacilityCategoryLegend;

/// Facility and place search, shown in the home sheet by the map's search
/// button.
class FacilitySearchPanel extends ConsumerStatefulWidget {
  const FacilitySearchPanel({
    super.key,
    required this.scrollController,
    required this.onSelectResult,
    this.focusNode,
  });

  final ScrollController scrollController;
  final ValueChanged<Facility> onSelectResult;
  final FocusNode? focusNode;

  @override
  ConsumerState<FacilitySearchPanel> createState() =>
      _FacilitySearchPanelState();
}

class _FacilitySearchPanelState extends ConsumerState<FacilitySearchPanel> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Null: no search run yet (or the field was cleared). Non-null (even
  /// empty, for "no results"): the last search's outcome.
  List<Facility>? _results;
  bool _loading = false;
  bool _searchFailed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    // Matches the web: no search under 2 characters.
    if (query.trim().length < 2) {
      setState(() {
        _results = null;
        _loading = false;
        _searchFailed = false;
      });
      return;
    }
    // Debounced rather than searching on every keystroke — the field has
    // no per-search rate limit, but firing a request per character is
    // still wasteful chatter for something the user is still typing.
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    setState(() {
      _loading = true;
      _searchFailed = false;
    });
    // Facilities first, then up to 3 places from OpenStreetMap — the same
    // order and sources as the web. Either source failing just drops its
    // half; only both failing with nothing to show is an error.
    final (facilities, places) = await (
      ref.read(facilityRepositoryProvider).search(trimmed),
      ref.read(placeSearchServiceProvider).search(trimmed),
    ).wait;
    if (!mounted) return;
    // Drop a stale response that landed after a newer search started.
    if (_controller.text.trim() != trimmed) return;
    final results = [
      ...?facilities.valueOrNull,
      ...?places.valueOrNull?.map(
        (p) => Facility.place(
          name: p.name,
          latitude: p.latitude,
          longitude: p.longitude,
        ),
      ),
    ];
    setState(() {
      _loading = false;
      _searchFailed = results.isEmpty && (!facilities.isOk || !places.isOk);
      _results = _searchFailed ? null : results;
    });
  }

  void _selectResult(Facility facility) {
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          AnalyticsEvents.searchResultSelected,
          parameters: {'source': 'search_panel'},
        );
    _debounce?.cancel();
    _controller.clear();
    setState(() => _results = null);
    widget.onSelectResult(facility);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            onChanged: _onChanged,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Facilities name or address',
              filled: true,
              fillColor: context.palette.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: context.palette.border),
              ),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          if (_searchFailed) ...[
            const SizedBox(height: 6),
            Text(
              'Could not search right now. Try again.',
              style: TextStyle(color: context.palette.danger, fontSize: 12),
            ),
          ],
          if (_results != null)
            if (_results!.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No results found.',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _results!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final facility = _results![index];
                    return InkWell(
                      onTap: () => _selectResult(facility),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            // The web marks places with 📍 instead of a
                            // facility icon.
                            if (facility.isPlace)
                              Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: context.palette.textSecondary,
                              )
                            else
                              FacilityCategoryGlyph(
                                category: facility.category,
                                color: facility.category.legendColor,
                                size: 18,
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    facility.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    facility.categoryLabel,
                                    style: TextStyle(
                                      color: context.palette.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}
