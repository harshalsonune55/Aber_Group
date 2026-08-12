import 'package:flutter/foundation.dart';

/// The signed-in staff member.
///
/// Deliberately not the same type as the Estate Ops seed data: this one comes
/// from the session, so it is what the app knows about *whoever is holding the
/// phone*, and it survives the seed content being replaced by real repositories.
@immutable
class AuthUser {
  const AuthUser({
    required this.name,
    required this.email,
    required this.role,
    required this.branch,
    required this.employeeId,
  });

  final String name;
  final String email;
  final String role;
  final String branch;
  final String employeeId;

  /// Up to two letters, so "Sara Khan" reads as SK and a single-word name
  /// still gets something rather than an empty circle.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final only = parts.first;
      return only.substring(0, only.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'role': role,
    'branch': branch,
    'employee_id': employeeId,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'Staff',
    branch: json['branch'] as String? ?? 'Business Bay',
    employeeId: json['employee_id'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.name == name &&
      other.email == email &&
      other.role == role &&
      other.branch == branch &&
      other.employeeId == employeeId;

  @override
  int get hashCode => Object.hash(name, email, role, branch, employeeId);
}

/// Where the app is in the sign-in lifecycle.
///
/// [unknown] is a real state, not a placeholder: on a cold start the session
/// lives in secure storage and reading it is asynchronous, so for a frame or
/// two the app genuinely does not know yet. Routing on it — rather than
/// assuming signed-out — is what stops a returning user seeing the sign-in
/// screen flash before their own data loads.
enum AuthStatus { unknown, signedOut, signedIn }
