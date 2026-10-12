import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// True while sign-up is still claiming the username. The app stays on the
  /// auth screen until it finishes, so a failed claim can show its error there.
  static final registering = ValueNotifier<bool>(false);

  /// One shared stream (also reports profile changes such as the username).
  /// Created once so rebuilding the app doesn't resubscribe to it.
  static final Stream<User?> userStream = FirebaseAuth.instance.userChanges();

  /// 3-20 letters, numbers or underscores.
  static final usernamePattern = RegExp(r'^[A-Za-z0-9_]{3,20}$');

  /// A valid starting username from an email, e.g. "Sam.Lee+x@gmail.com" -> "samleex".
  static String suggestUsername(String? email) {
    var name = (email ?? '').split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (name.length > 20) name = name.substring(0, 20);
    while (name.length < 3) {
      name += 'user'; // too short to be valid on its own
    }
    return name;
  }

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  // ---- Google ----

  static bool _googleReady = false;

  static Future<void> _initGoogle() async {
    if (_googleReady) return;
    // On Android the web client id is read from google-services.json automatically.
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  /// Signs in (or signs up) with a Google account through Firebase Auth.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    await _initGoogle();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw FirebaseAuthException(code: 'google-no-token');
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  /// True when the user simply closed the Google account picker.
  static bool isCancelled(Object e) =>
      (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) ||
      (e is FirebaseAuthException && (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request'));

  // ---- Usernames ----

  /// Usernames are stored lowercase as document ids, so "Sam" and "sam" are the same name.
  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _db.collection('usernames').doc(username.toLowerCase()).get();
    return !doc.exists;
  }

  /// Live view of the signed-in user's profile document (it exists once a username is chosen).
  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      _db.collection('users').doc(uid).snapshots(includeMetadataChanges: true);

  /// One atomic batch: claim the unique name and create the profile.
  /// The security rules reject the claim if the name already exists.
  Future<void> claimUsername(User user, String username) async {
    final lower = username.toLowerCase();
    try {
      final batch = _db.batch()
        ..set(_db.collection('usernames').doc(lower), {'uid': user.uid, 'username': username})
        ..set(_db.collection('users').doc(user.uid), {
          'username': username,
          'usernameLower': lower,
          'createdAt': FieldValue.serverTimestamp(),
        });
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const UsernameTakenException();
      rethrow;
    }
    await user.updateDisplayName(username);
  }

  Future<void> register(String email, String password, String username) async {
    registering.value = true;
    try {
      if (!await isUsernameAvailable(username)) throw const UsernameTakenException();
      final user = (await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password)).user!;
      try {
        await claimUsername(user, username);
      } catch (e) {
        await user.delete(); // never leave an account that has no username
        rethrow;
      }
    } finally {
      registering.value = false;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _initGoogle();
        await GoogleSignIn.instance.signOut(); // so the account picker shows next time
      } catch (_) {}
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  /// Re-authenticates with the current password, then sets the new one.
  /// Only works for accounts that have a password (not Google-only accounts).
  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: user.email!, password: current);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(next);
  }

  /// Maps errors to friendly messages.
  static String message(Object e) {
    if (e is UsernameTakenException) return 'That username is already taken.';
    if (e is GoogleSignInException) {
      return switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError =>
          "Google sign-in isn't set up for this build. Please use email and password instead.",
        _ => 'Google sign-in failed. Please try again.',
      };
    }
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'account-exists-with-different-credential':
          return 'An account already exists for that email with a different sign-in method.';
        case 'requires-recent-login':
          return 'Please log in again and retry.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'google-no-token':
          return 'Google did not return a sign-in token. Please try again.';
      }
      return e.message ?? 'Authentication failed.';
    }
    if (e is FirebaseException && e.code == 'unavailable') return 'Network error. Check your connection.';
    return 'Something went wrong. Please try again.';
  }
}
