import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics_events.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/access_analysis.dart';
import '../../../data/models/facility.dart';
import '../../../data/repositories/facility_repository.dart';
import '../../../data/services/analytics_service.dart';
import '../../../data/models/app_user.dart';
import '../../../data/services/place_search_service.dart';
import '../../core/view_model/auth_view_model.dart';
import '../../core/view_model/theme_mode_view_model.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirm_logout_dialog.dart';
import '../../core/widgets/facility_category_glyph.dart';
import '../view_model/home_map_view_model.dart';
import 'data_sources_dialog.dart';
import 'how_to_use_dialog.dart';
import 'map_legend.dart' show FacilityCategoryLegend;
import 'transport_mode_button.dart';

TextStyle _sectionHeaderStyle(BuildContext context) => TextStyle(
  color: context.palette.textSecondary,
  fontWeight: FontWeight.bold,
  fontSize: 12,
  letterSpacing: 0.5,
);

Future<void> _openLink(BuildContext context, String url) async {
  final launched = await launchUrl(Uri.parse(url));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
  }
}

/// The web platform's left sidebar (search, map layers, Accessibility
/// Analyzer defaults, account), reused as a slide-in drawer on mobile rather
/// than a plain links menu — opened from the map's hamburger button.
///
/// "How to Use This Map" and "Data Sources & Credits" are UI-only for now
/// (no backing data/logic exists yet); search, the facility-category
/// filter, the Emergency Facilities, Live Traffic and Lagos Boundary
/// layer toggles, the Accessibility Analyzer defaults, Clear Map, and
/// every footer link are wired to real state/actions.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({
    super.key,
    required this.onUseCurrentLocation,
    required this.onClearMap,
    required this.onSelectSearchResult,
    required this.onOpenDashboard,
    this.searchFocusNode,
  });

  /// Reuses the same recenter-on-user flow as the map's own "My Location"
  /// side button — that flow needs the screen's MapAnnotationController, so
  /// it's passed in rather than duplicated here.
  final VoidCallback onUseCurrentLocation;

  /// Reuses the same clear-everything-and-recenter flow as the map's
  /// trash-icon side button, for the same reason.
  final VoidCallback onClearMap;

  /// Flies to and selects a tapped search result — same reason as
  /// [onUseCurrentLocation]: needs the screen's MapAnnotationController.
  final ValueChanged<Facility> onSelectSearchResult;

  /// Opens My Dashboard — the screen handles what it asks for on close
  /// (show a facility, or navigate to one).
  final VoidCallback onOpenDashboard;

  /// Owned by the screen so its side-button search icon can open the
  /// drawer and focus this field in one tap.
  final FocusNode? searchFocusNode;

  static const _thresholdOptionsMinutes = [15, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeMapViewModelProvider).value;
    final notifier = ref.read(homeMapViewModelProvider.notifier);

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              onToggleTheme: () =>
                  ref.read(themeModeProvider.notifier).toggle(),
              onClose: () => Scaffold.of(context).closeDrawer(),
            ),
            const Divider(height: 1),
            _AccountSection(onOpenDashboard: onOpenDashboard),
            const Divider(height: 1),
            _SearchSection(
              onUseCurrentLocation: () {
                Scaffold.of(context).closeDrawer();
                onUseCurrentLocation();
              },
              onSelectResult: (facility) {
                Scaffold.of(context).closeDrawer();
                onSelectSearchResult(facility);
              },
              focusNode: searchFocusNode,
            ),
            const Divider(height: 1),
            _MapLayersSection(
              selectedFilter: state?.selectedFilter,
              onFilterChanged: notifier.selectFilter,
              showEmergencyFacilities: state?.showEmergencyFacilities ?? true,
              onToggleEmergencyFacilities:
                  notifier.toggleEmergencyFacilitiesLayer,
              showLiveTraffic: state?.showLiveTraffic ?? false,
              onToggleLiveTraffic: notifier.toggleLiveTrafficLayer,
              showLagosBoundary: state?.showLagosBoundary ?? true,
              onToggleLagosBoundary: notifier.toggleLagosBoundaryLayer,
            ),
            const Divider(height: 1),
            _AnalyzerDefaultsSection(
              selectedMode:
                  state?.selectedTransportMode ?? TransportMode.driving,
              onModeChanged: notifier.setSelectedMode,
              thresholdMinutes:
                  state?.analysisThresholdMinutes ??
                  kAccessAnalysisThresholdMinutes,
              onThresholdChanged: notifier.setAnalysisThreshold,
              onClearMap: () {
                Scaffold.of(context).closeDrawer();
                onClearMap();
              },
            ),
            _HelpLinksSection(
              onHowToUse: () => showHowToUseDialog(context),
              onDataSources: () => showDataSourcesDialog(context),
            ),
            const Divider(height: 1),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onToggleTheme, required this.onClose});

  final VoidCallback onToggleTheme;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        children: [
          Image.asset('assets/images/logo_black.png', width: 40, height: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(
                        text: '911 ',
                        style: TextStyle(color: context.palette.primary),
                      ),
                      TextSpan(
                        text: 'Rescue',
                        style: TextStyle(color: context.palette.success),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Emergency Finder',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            // The web's sun/moon: the sun switches to light, the moon to dark.
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
            ),
            onPressed: onToggleTheme,
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            style: IconButton.styleFrom(
              side: BorderSide(color: context.palette.primary),
              shape: const CircleBorder(),
              foregroundColor: context.palette.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
            tooltip: 'Close menu',
          ),
        ],
      ),
    );
  }
}

class _SearchSection extends ConsumerStatefulWidget {
  const _SearchSection({
    required this.onUseCurrentLocation,
    required this.onSelectResult,
    this.focusNode,
  });

  final VoidCallback onUseCurrentLocation;
  final ValueChanged<Facility> onSelectResult;
  final FocusNode? focusNode;

  @override
  ConsumerState<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends ConsumerState<_SearchSection> {
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
          parameters: {'source': 'drawer'},
        );
    _debounce?.cancel();
    _controller.clear();
    setState(() => _results = null);
    widget.onSelectResult(facility);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SEARCH FACILITY', style: _sectionHeaderStyle(context)),
          const SizedBox(height: 8),
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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
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
              ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Use Current Location',
              onPressed: widget.onUseCurrentLocation,
              filled: false,
              icon: Icons.my_location,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLayersSection extends StatelessWidget {
  const _MapLayersSection({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.showEmergencyFacilities,
    required this.onToggleEmergencyFacilities,
    required this.showLiveTraffic,
    required this.onToggleLiveTraffic,
    required this.showLagosBoundary,
    required this.onToggleLagosBoundary,
  });

  final FacilityCategory? selectedFilter;
  final ValueChanged<FacilityCategory?> onFilterChanged;
  final bool showEmergencyFacilities;
  final VoidCallback onToggleEmergencyFacilities;
  final bool showLiveTraffic;
  final VoidCallback onToggleLiveTraffic;
  final bool showLagosBoundary;
  final VoidCallback onToggleLagosBoundary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAP LAYERS', style: _sectionHeaderStyle(context)),
          const SizedBox(height: 8),
          Text(
            'Filter by Type:',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<FacilityCategory?>(
            initialValue: selectedFilter,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.palette.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Facilities'),
              ),
              for (final category in FacilityCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.displayLabel),
                ),
            ],
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 12),
          _LayerRow(
            label: 'Lagos Boundary',
            value: showLagosBoundary,
            onChanged: (_) => onToggleLagosBoundary(),
          ),
          _LayerRow(
            label: 'Emergency Facilities',
            value: showEmergencyFacilities,
            onChanged: (_) => onToggleEmergencyFacilities(),
          ),
          _LayerRow(
            label: 'Live Traffic',
            value: showLiveTraffic,
            onChanged: (_) => onToggleLiveTraffic(),
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.palette.backgroundCanvas,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          value: value,
          onChanged: onChanged,
          controlAffinity: ListTileControlAffinity.trailing,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(label),
        ),
      ),
    );
  }
}

class _AnalyzerDefaultsSection extends StatelessWidget {
  const _AnalyzerDefaultsSection({
    required this.selectedMode,
    required this.onModeChanged,
    required this.thresholdMinutes,
    required this.onThresholdChanged,
    required this.onClearMap,
  });

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onModeChanged;
  final int thresholdMinutes;
  final ValueChanged<int> onThresholdChanged;
  final VoidCallback onClearMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACCESSIBILITY ANALYZER', style: _sectionHeaderStyle(context)),
          const SizedBox(height: 8),
          Text(
            'Commute Mode:',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<TransportMode>(
            initialValue: selectedMode,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.palette.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final mode in TransportMode.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text('${mode.emoji} ${mode.dropdownLabel}'),
                ),
            ],
            onChanged: (mode) {
              if (mode != null) onModeChanged(mode);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Max Time Threshold:',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            initialValue: thresholdMinutes,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.palette.backgroundCanvas,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              for (final minutes in HomeDrawer._thresholdOptionsMinutes)
                DropdownMenuItem(
                  value: minutes,
                  child: Text('$minutes Minutes'),
                ),
            ],
            onChanged: (minutes) {
              if (minutes != null) onThresholdChanged(minutes);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Clear Map',
              onPressed: onClearMap,
              variant: AppButtonVariant.danger,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpLinksSection extends StatelessWidget {
  const _HelpLinksSection({
    required this.onHowToUse,
    required this.onDataSources,
  });

  final VoidCallback onHowToUse;
  final VoidCallback onDataSources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'How to Use This Map',
              onPressed: onHowToUse,
              variant: AppButtonVariant.neutral,
              icon: Icons.help_outline,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Data Sources & Credits',
              onPressed: onDataSources,
              variant: AppButtonVariant.neutral,
              icon: Icons.info_outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// The web sidebar's account block: "Sign in with Google" when signed
/// out; avatar, name, email and Logout when signed in.
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection({required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  var _signingIn = false;

  Future<void> _signIn() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingIn = true);
    final message = await ref.read(authViewModelProvider.notifier).signIn();
    if (mounted) setState(() => _signingIn = false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final user = auth.value;
    return Padding(
      // The web's `.sb-section`.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: user != null
          ? _Profile(
              user: user,
              onOpenDashboard: widget.onOpenDashboard,
              onLogout: () async {
                if (await confirmLogout(context)) {
                  await ref.read(authViewModelProvider.notifier).signOut();
                }
              },
            )
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: (_signingIn || auth.isLoading) ? null : _signIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.palette.textPrimary,
                  side: BorderSide(color: context.palette.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_signingIn || auth.isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Image.asset(
                        'assets/images/google_logo.png',
                        width: 18,
                        height: 18,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _signingIn ? 'Signing in…' : 'Sign in with Google',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.user,
    required this.onOpenDashboard,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onOpenDashboard;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final name = user.name?.trim();
    final initial = (name?.isNotEmpty ?? false ? name! : user.email)
        .substring(0, 1)
        .toUpperCase();
    final picture = user.picture;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // The web's `.user-avatar`: 32px, with a 1px accent ring.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.palette.primary),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: context.palette.inputBg,
                foregroundImage: picture == null ? null : NetworkImage(picture),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: context.palette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name != null && name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 12),
        Row(
          children: [
            // The web's `.btn-dashboard`: fills the row, blue-tinted with
            // an accent border, 12px bold.
            Expanded(
              child: OutlinedButton(
                onPressed: onOpenDashboard,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0x1A0077FF),
                  foregroundColor: context.palette.primary,
                  side: BorderSide(color: context.palette.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('📊 My Dashboard'),
              ),
            ),
            const SizedBox(width: 10),
            // `.btn-logout`: plain pink text, 11px bold.
            TextButton(
              onPressed: onLogout,
              style: TextButton.styleFrom(
                foregroundColor: context.palette.danger,
                padding: const EdgeInsets.all(5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      _openLink(context, 'https://bwanalytics.com.ng/'),
                  child: Text(
                    'Made by BW Analytics',
                    style: TextStyle(
                      color: context.palette.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openLink(
                  context,
                  'https://www.linkedin.com/company/bwanalytics/',
                ),
                child: Image.asset(
                  'assets/images/linkedin_icon.png',
                  width: 22,
                  height: 22,
                  color: context.palette.textSecondary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _openLink(context, 'https://wa.me/2348154225124'),
                child: Image.asset(
                  'assets/images/whatsapp_icon.png',
                  width: 22,
                  height: 22,
                  color: context.palette.textSecondary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _openLink(context, 'mailto:ogdi@bwanalytics.com'),
            child: Text(
              'ogdi@bwanalytics.com',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openLink(context, 'tel:+2348154225124'),
            child: Text(
              '+234 815 422 5124',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
