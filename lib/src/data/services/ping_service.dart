import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../models/geo_point.dart';
import '../models/ping.dart';
import '../network/api_client.dart';
import '../network/json_reader.dart';

final pingServiceProvider = Provider<PingService>(
  (ref) => PingService(ref.watch(apiClientProvider)),
);

/// Thin client over the 911 Rescue API's emergency ping endpoints — the
/// core flow, and the only one that needs no account: raising a ping
/// returns a `public_id` that's the sole credential for tracking,
/// correcting and cancelling it afterward (the API docs group all three
/// under one "Correct and refine" section right after "Track it", both
/// keyed the same way, so `{id}` there is the same public_id, not the
/// incident's internal integer `id`).
class PingService {
  PingService(this._api);

  final ApiClient _api;

  Future<Result<PingCreated>> raisePing({
    required PingAgency agency,
    required GeoPoint point,
    required double accuracy,
    String? note,
    String? medicalProfile,
  }) {
    return _api.post<PingCreated>(
      '/api/ping',
      body: {
        'agency': agency.apiValue,
        'lat': point.latitude,
        'lng': point.longitude,
        'accuracy': accuracy,
        if (note != null && note.isNotEmpty) 'note': note,
        if (medicalProfile != null && medicalProfile.isNotEmpty)
          'medical_profile': medicalProfile,
      },
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'POST /api/ping: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        return PingCreated(
          publicId: r.string('public_id'),
          respondersAvailable: r.intOrNull('responders_available') ?? 0,
          timeoutMinutes: r.intOrNull('timeout_minutes') ?? 5,
          alreadyActive: r.boolOr('already_active', fallback: false),
        );
      },
    );
  }

  /// Poll roughly every 5 seconds per the API docs.
  Future<Result<PingTrackingInfo>> trackPing(String publicId) {
    return _api.get<PingTrackingInfo>(
      '/api/ping/$publicId',
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'GET /api/ping/$publicId: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        final incident = r.object('incident');
        final responder = r.objectOrNull('responder');
        return PingTrackingInfo(
          incident: PingIncident(
            id: incident.int_('id'),
            status: PingStatus.fromApi(incident.string('status')),
            agency: incident.string('agency'),
            userPoint: GeoPoint(
              latitude: incident.double_('user_lat'),
              longitude: incident.double_('user_lng'),
            ),
            userAddress: incident.stringOrNull('user_address'),
            responderMode: incident.stringOrNull('responder_mode'),
            note: incident.stringOrNull('note'),
            hasVoice: incident.boolOr('has_voice', fallback: false),
          ),
          responder: responder == null
              ? null
              : PingResponder(
                  responderId: responder.string('responder_id'),
                  fullName: responder.string('full_name'),
                  phone: responder.stringOrNull('phone'),
                  stationName: responder.stringOrNull('station_name'),
                  lastPoint:
                      responder.doubleOrNull('last_lat') != null &&
                          responder.doubleOrNull('last_lng') != null
                      ? GeoPoint(
                          latitude: responder.double_('last_lat'),
                          longitude: responder.double_('last_lng'),
                        )
                      : null,
                  lastAccuracy: responder.doubleOrNull('last_accuracy'),
                  lastSeen: responder.dateTimeOrNull('last_seen'),
                ),
        );
      },
    );
  }

  /// A better GPS fix than the one the ping was raised with — the backend
  /// only accepts it if it's actually more accurate than what's stored.
  Future<Result<void>> refineLocation(
    String publicId, {
    required GeoPoint point,
    required double accuracy,
  }) {
    return _api.post<void>(
      '/api/ping/$publicId/location',
      body: {
        'lat': point.latitude,
        'lng': point.longitude,
        'accuracy': accuracy,
      },
      parse: (_) {},
    );
  }

  /// The user's own address correction — "geocoding in Lagos is
  /// unreliable; the person standing there knows better."
  Future<Result<void>> correctAddress(String publicId, String address) {
    return _api.post<void>(
      '/api/ping/$publicId/address',
      body: {'address': address},
      parse: (_) {},
    );
  }

  Future<Result<void>> cancelPing(String publicId) {
    return _api.post<void>('/api/ping/$publicId/cancel', parse: (_) {});
  }

  /// [bytes] rather than a file path — the recorder already produced the
  /// finished file; multipart just needs its bytes and a filename. Max 30
  /// seconds, rate limited to 10/minute per the API docs.
  Future<Result<VoiceUploadResult>> uploadVoice(
    String publicId, {
    required List<int> bytes,
    required String filename,
    int? seconds,
  }) {
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(bytes, filename: filename),
      'seconds': ?seconds,
    });
    return _api.postMultipart<VoiceUploadResult>(
      '/api/ping/$publicId/voice',
      formData: formData,
      parse: (body) {
        if (body is! Map<String, dynamic>) {
          throw JsonFormatException(
            'POST /api/ping/$publicId/voice: expected an object, got ${body.runtimeType}',
          );
        }
        final r = JsonReader(body);
        return VoiceUploadResult(
          transcript: r.stringOrNull('transcript'),
          transcribed: r.boolOr('transcribed', fallback: false),
        );
      },
    );
  }
}
