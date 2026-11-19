import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sends usage events to the backend's KPI dashboard (`POST /api/events`),
/// as the backend's mobile tracking spec describes: an install id, visits
/// ("sessions"), a heartbeat while open, and batches kept on the device
/// until they're accepted, so nothing is lost offline.
///
/// Analytics must never get in the way: every failure is swallowed and
/// retried at the next flush.
class KpiTracker {
  KpiTracker({
    required this._dio,
    required this._prefs,
    required this.platform,
    required this.appVersion,
    this.device = 'mobile',
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? _randomId;

  final Dio _dio;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final String Function() _newId;

  /// `android` or `ios` — also sent as the `X-Client` header.
  final String platform;
  final String appVersion;

  /// `mobile` or `tablet`.
  final String device;

  /// Yes or no only, never who: null leaves it out.
  bool? signedIn;

  static const sessionGap = Duration(minutes: 30);
  static const maxAge = Duration(hours: 72);
  static const maxQueue = 500;
  static const maxBatch = 100;
  static const flushAt = 25;
  static const maxAttempts = 3;

  static const _anonIdKey = 'kpi_anon_id';
  static const _sessionIdKey = 'kpi_session_id';
  static const _lastEventKey = 'kpi_session_last';
  static const _queueKey = 'kpi_queue';

  static final _validName = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

  String _anonId = '';
  String _sessionId = '';
  int _lastEventMs = 0;
  List<Map<String, Object?>> _queue = [];
  bool _flushing = false;
  int _failedAttempts = 0;
  Timer? _flushTimer;
  Timer? _heartbeat;
  AppLifecycleListener? _lifecycle;

  /// Events waiting to be sent, oldest first.
  List<Map<String, Object?>> get queued => List.unmodifiable(_queue);
  String get anonId => _anonId;
  String get sessionId => _sessionId;

  /// Restores the install id, visit and unsent events from the device.
  void load() {
    _anonId = _prefs.getString(_anonIdKey) ?? '';
    if (_anonId.isEmpty) {
      _anonId = _newId();
      unawaited(_prefs.setString(_anonIdKey, _anonId));
    }
    _sessionId = _prefs.getString(_sessionIdKey) ?? '';
    _lastEventMs = _prefs.getInt(_lastEventKey) ?? 0;
    try {
      final saved = jsonDecode(_prefs.getString(_queueKey) ?? '[]') as List;
      _queue = [for (final e in saved) Map<String, Object?>.from(e as Map)];
    } catch (_) {
      _queue = [];
    }
    _dropExpired();
  }

  /// Starts the timers and follows the app in and out of the foreground.
  void start() {
    _flushTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(flush()),
    );
    _lifecycle ??= AppLifecycleListener(
      onResume: onForeground,
      onPause: onBackground,
    );
    onForeground();
  }

  void onForeground() {
    track('app_open');
    _heartbeat ??= Timer.periodic(
      const Duration(seconds: 60),
      (_) => track('heartbeat'),
    );
  }

  /// Flushes straight away, before the OS can suspend the app.
  void onBackground() {
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(flush());
  }

  /// Queues [name]. Names the backend would reject are dropped here.
  void track(String name, [Map<String, Object>? props]) {
    if (!_validName.hasMatch(name)) return;
    final now = _now().millisecondsSinceEpoch;
    _touchSession(now);
    _queue.add({'name': name, 'ts': now, 'props': ?props});
    if (_queue.length > maxQueue) {
      _queue = _queue.sublist(_queue.length - maxQueue);
    }
    _save();
    if (_queue.length >= flushAt) unawaited(flush());
  }

  /// A new visit after [sessionGap] without events — which, with the
  /// heartbeat running while open, means that long in the background.
  void _touchSession(int now) {
    if (_sessionId.isEmpty || now - _lastEventMs >= sessionGap.inMilliseconds) {
      _sessionId = _newId();
      _queue.add({'name': 'session_start', 'ts': now});
    }
    _lastEventMs = now;
    unawaited(_prefs.setString(_sessionIdKey, _sessionId));
    unawaited(_prefs.setInt(_lastEventKey, now));
  }

  /// Sends up to [maxBatch] events. Kept for the next flush on a network or
  /// server error, but dropped after [maxAttempts] failures, and dropped
  /// straight away when the server rejects them as invalid.
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty || _anonId.isEmpty) return;
    _flushing = true;
    _dropExpired();
    final batch = _queue.take(maxBatch).toList();
    try {
      if (batch.isEmpty) return;
      final status = await _send(batch);
      final rejected =
          status != null && status >= 400 && status < 500 && status != 429;
      if (status == 202 || rejected) {
        _failedAttempts = 0;
        _removeSent(batch.length);
      } else if (++_failedAttempts >= maxAttempts) {
        _failedAttempts = 0;
        _removeSent(batch.length);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<int?> _send(List<Map<String, Object?>> batch) async {
    try {
      final response = await _dio.post<Object?>(
        '/api/events',
        data: {
          'anon_id': _anonId,
          'session_id': _sessionId,
          'platform': platform,
          'device': device,
          'app_version': appVersion,
          'signed_in': ?signedIn,
          'events': batch,
        },
        options: Options(
          headers: {'X-Client': platform},
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode;
    } catch (_) {
      return null;
    }
  }

  /// After the account is deleted: a fresh install id, so nothing sent
  /// afterwards can be tied to the old one.
  Future<void> resetIdentity() async {
    _anonId = _newId();
    await _prefs.setString(_anonIdKey, _anonId);
  }

  void dispose() {
    _flushTimer?.cancel();
    _heartbeat?.cancel();
    _lifecycle?.dispose();
  }

  void _removeSent(int count) {
    _queue = _queue.sublist(min(count, _queue.length));
    _save();
  }

  /// The server ignores anything older than [maxAge].
  void _dropExpired() {
    final cutoff = _now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    _queue.removeWhere((e) => (e['ts'] as int? ?? 0) <= cutoff);
  }

  void _save() => unawaited(_prefs.setString(_queueKey, jsonEncode(_queue)));

  /// 32 random hex characters — a UUID without dashes, as the spec asks.
  static String _randomId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
