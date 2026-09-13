/// Thrown by [JsonReader] when the JSON doesn't have the shape a DTO
/// expects. [ApiClient] turns this into an [UnknownFailure] — it never
/// escapes the data layer.
class JsonFormatException implements Exception {
  JsonFormatException(this.message);

  final String message;

  @override
  String toString() => 'JsonFormatException: $message';
}

/// A small typed accessor over a decoded JSON object, so `fromJson` bodies
/// stay short and every parse failure is a clear message instead of a raw
/// cast error.
///
/// ```dart
/// factory FooDto.fromJson(Map<String, dynamic> json) {
///   final r = JsonReader(json);
///   return FooDto(id: r.int_('id'), lat: r.double_('lat'));
/// }
/// ```
class JsonReader {
  JsonReader(this._json, {this._path = ''});

  final Map<String, dynamic> _json;
  final String _path;

  String _pathTo(String key) => _path.isEmpty ? key : '$_path.$key';

  Never _fail(String key, String expected) {
    final actual = _json[key];
    throw JsonFormatException(
      'expected $expected at "${_pathTo(key)}", got ${actual.runtimeType}',
    );
  }

  bool has(String key) => _json[key] != null;

  String string(String key) {
    final value = _json[key];
    return value is String ? value : _fail(key, 'String');
  }

  String? stringOrNull(String key) {
    final value = _json[key];
    return value is String ? value : null;
  }

  int int_(String key) {
    final value = _json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return _fail(key, 'int');
  }

  int? intOrNull(String key) {
    final value = _json[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double double_(String key) {
    final value = _json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return _fail(key, 'double');
  }

  double? doubleOrNull(String key) {
    final value = _json[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool bool_(String key) {
    final value = _json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return _fail(key, 'bool');
  }

  bool boolOr(String key, {required bool fallback}) {
    final value = _json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return fallback;
  }

  DateTime dateTime(String key) {
    final value = _json[key];
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return _fail(key, 'ISO-8601 date string');
  }

  DateTime? dateTimeOrNull(String key) {
    final value = _json[key];
    return value is String ? DateTime.tryParse(value) : null;
  }

  /// A nested object as its own reader.
  JsonReader object(String key) {
    final value = _json[key];
    return value is Map<String, dynamic>
        ? JsonReader(value, path: _pathTo(key))
        : _fail(key, 'object');
  }

  JsonReader? objectOrNull(String key) {
    final value = _json[key];
    return value is Map<String, dynamic>
        ? JsonReader(value, path: _pathTo(key))
        : null;
  }

  /// A list mapped through [item]. Each element must be a JSON object.
  List<T> list<T>(String key, T Function(JsonReader reader) item) {
    final value = _json[key];
    if (value is! List) return _fail(key, 'array');
    return value
        .whereType<Map<String, dynamic>>()
        .map((e) => item(JsonReader(e, path: '${_pathTo(key)}[]')))
        .toList(growable: false);
  }

  /// The raw decoded array at [key], unmapped — for shapes [list] can't
  /// handle because the elements aren't JSON objects, like a GeoJSON
  /// coordinate array (`[lng, lat]`, or nested arrays of those for a
  /// polygon ring).
  List<dynamic> rawList(String key) {
    final value = _json[key];
    if (value is! List) return _fail(key, 'array');
    return value;
  }
}
