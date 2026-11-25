import 'package:flutter/foundation.dart';

import '../../../core/security/token_store.dart';

@immutable
final class User {
  const User({required this.id, required this.email, required this.name});

  /// Throws [FormatException] on contract violations instead of crashing
  /// later with a null error deep in the UI.
  factory User.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('User must be an object');
    final id = json['id'];
    final email = json['email'];
    final name = json['name'];
    if (id is! String || email is! String || name is! String) {
      throw const FormatException('User has missing or invalid fields');
    }
    return User(id: id, email: email, name: name);
  }

  final String id;
  final String email;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.email == email &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, email, name);
}

/// Result of a successful sign-in.
final class Session {
  const Session({required this.user, required this.tokens});

  final User user;
  final AuthTokens tokens;
}
