import '../network/json_reader.dart';

/// The signed-in 911 Rescue account — the `user` object from
/// `/auth/mobile/google` and `/api/user_status`.
class AppUser {
  const AppUser({required this.email, this.name, this.picture});

  factory AppUser.fromJson(JsonReader r) => AppUser(
    email: r.string('email'),
    name: r.stringOrNull('name'),
    picture: r.stringOrNull('picture'),
  );

  final String email;
  final String? name;
  final String? picture;
}
