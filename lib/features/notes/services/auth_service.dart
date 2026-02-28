import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lightweight Firebase anonymous authentication wrapper.
/// - Automatically attempts anonymous sign-in when constructed.
/// - Exposes [signInAnonymously] and [currentUser].
class AuthService {
  AuthService._internal();

  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    // If already signed in, return existing user to avoid creating multiple
    // anonymous accounts from repeated sign-in calls.
    if (_auth.currentUser != null) {
      if (kDebugMode)
        debugPrint(
          'AuthService: returning existing uid: ${_auth.currentUser!.uid}',
        );
      return _auth.currentUser;
    }
    try {
      final cred = await _auth.signInAnonymously();
      if (cred.user != null) {
        if (kDebugMode)
          debugPrint('AuthService: created new uid: ${cred.user!.uid}');
        return cred.user;
      }
      if (kDebugMode)
        debugPrint('AuthService.signInAnonymously: signIn returned null user');
      return null;
    } on FirebaseAuthException catch (e, st) {
      if (kDebugMode)
        debugPrint(
          'AuthService.signInAnonymously FirebaseAuthException: ${e.code} ${e.message}\n$st',
        );
      return null;
    } catch (e, st) {
      if (kDebugMode)
        debugPrint('AuthService.signInAnonymously error: $e\n$st');
      return null;
    }
  }

  // Removed automatic sign-in helper; callers should call signInAnonymously()
  // when they want to ensure a user exists.
}

// Convenience top-level accessor.
AuthService get authService => AuthService.instance;
