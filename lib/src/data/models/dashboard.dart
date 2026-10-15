import 'dart:io' show HttpDate;

import '../network/json_reader.dart';
import 'saved_facility.dart';

/// `/api/my_dashboard` — the signed-in account's profile and activity.
class Dashboard {
  const Dashboard({
    required this.profile,
    required this.history,
    required this.topFacilities,
    required this.saved,
  });

  factory Dashboard.fromJson(JsonReader r) => Dashboard(
    profile: DashboardProfile.fromJson(r.object('profile')),
    history: r.list('history', DashboardActivity.fromJson),
    topFacilities: r.list('top_facilities', DashboardTopFacility.fromJson),
    saved: r.list('saved', SavedFacility.fromServer),
  );

  final DashboardProfile profile;

  /// The last 20 interactions, newest first.
  final List<DashboardActivity> history;
  final List<DashboardTopFacility> topFacilities;
  final List<SavedFacility> saved;

  Dashboard withoutSaved(String name) => Dashboard(
    profile: profile,
    history: history,
    topFacilities: topFacilities,
    saved: [
      for (final item in saved)
        if (item.name != name) item,
    ],
  );
}

class DashboardProfile {
  const DashboardProfile({
    required this.email,
    this.name,
    this.plan,
    this.createdAt,
  });

  factory DashboardProfile.fromJson(JsonReader r) => DashboardProfile(
    email: r.string('email'),
    name: r.stringOrNull('name'),
    plan: r.stringOrNull('plan'),
    createdAt: parseServerDate(r.stringOrNull('created_at')),
  );

  final String email;
  final String? name;

  /// e.g. `free`.
  final String? plan;
  final DateTime? createdAt;
}

class DashboardActivity {
  const DashboardActivity({
    required this.facilityName,
    required this.interactionType,
    this.facilityCategory,
    this.mode,
    this.createdAt,
  });

  factory DashboardActivity.fromJson(JsonReader r) => DashboardActivity(
    facilityName: r.string('facility_name'),
    interactionType: r.stringOrNull('interaction_type') ?? '',
    facilityCategory: r.stringOrNull('facility_category'),
    mode: r.stringOrNull('mode'),
    createdAt: parseServerDate(r.stringOrNull('created_at')),
  );

  final String facilityName;

  /// `navigated`, `viewed`, `analyzed` or `arrived`.
  final String interactionType;
  final String? facilityCategory;
  final String? mode;
  final DateTime? createdAt;
}

class DashboardTopFacility {
  const DashboardTopFacility({
    required this.facilityName,
    required this.visits,
    this.facilityCategory,
  });

  factory DashboardTopFacility.fromJson(JsonReader r) => DashboardTopFacility(
    facilityName: r.string('facility_name'),
    visits: r.intOrNull('visits') ?? 0,
    facilityCategory: r.stringOrNull('facility_category'),
  );

  final String facilityName;
  final int visits;
  final String? facilityCategory;
}

/// The API mixes formats: the profile's `created_at` is an HTTP date
/// (`Thu, 15 Oct 2026 09:05:39 GMT`), the activity and saved rows' are ISO
/// (`2026-10-15T09:27:55.822929+00:00`). Never throws — an unreadable date
/// is just left out.
DateTime? parseServerDate(String? value) {
  if (value == null) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;
  try {
    return HttpDate.parse(value);
  } catch (_) {
    return null;
  }
}
