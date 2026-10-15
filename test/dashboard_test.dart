import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/data/models/dashboard.dart';
import 'package:rescue_911/src/data/network/json_reader.dart';

Dashboard _parse(String body) =>
    Dashboard.fromJson(JsonReader(jsonDecode(body) as Map<String, dynamic>));

void main() {
  test('parses an empty dashboard as the API sends it', () {
    final dashboard = _parse('''
      {"history":[],"profile":{"created_at":"Thu, 15 Oct 2026 09:05:39 GMT",
      "email":"a@b.com","google_sub":"1","name":"Ayuba Salami",
      "picture":"https://x","plan":"free"},"saved":[],"top_facilities":[]}
    ''');
    expect(dashboard.profile.name, 'Ayuba Salami');
    expect(dashboard.profile.plan, 'free');
    expect(dashboard.profile.createdAt, DateTime.utc(2026, 10, 15, 9, 5, 39));
    expect(dashboard.history, isEmpty);
  });

  test('parses activity, most visited and saved rows', () {
    final dashboard = _parse('''
      {"profile":{"email":"a@b.com"},
       "history":[{"facility_name":"LASUTH","facility_category":"General Hospital",
         "interaction_type":"navigated","created_at":"2026-10-15T09:27:55.822929+00:00"}],
       "top_facilities":[{"facility_name":"LASUTH","visits":3}],
       "saved":[{"facility_name":"LASUTH","facility_lat":6.59,"facility_lng":3.34}]}
    ''');
    expect(dashboard.history.single.interactionType, 'navigated');
    expect(
      dashboard.history.single.createdAt,
      DateTime.utc(2026, 10, 15, 9, 27, 55, 822, 929),
    );
    expect(dashboard.topFacilities.single.visits, 3);
    expect(dashboard.saved.single.latitude, 6.59);
    expect(dashboard.saved.single.synced, isTrue);
  });
}
