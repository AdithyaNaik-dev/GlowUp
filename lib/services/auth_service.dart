import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'data_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String get displayName =>
      currentUser?.displayName ?? currentUser?.email?.split('@').first ?? '';
  String get email => currentUser?.email ?? '';

  // ── Email / Password ──

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await DataService().syncToFirestore();
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await DataService().syncToFirestore();
    return cred;
  }

  // ── Google Sign-In ──

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    await DataService().syncToFirestore();
    return cred;
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Delete Account ──

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in.');

    // Step 1: Re-authenticate first (required by Firebase for destructive ops)
    await _reauthenticate(user);

    // Step 2: Delete Firestore document for this email
    final email = (user.email ?? '').toLowerCase().trim();
    if (email.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    // Step 3: Delete Firebase Auth account
    await user.delete();

    // Step 4: Sign out of Google
    await _googleSignIn.signOut();
  }

  Future<void> _reauthenticate(User user) async {
    final isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');

    if (isGoogle) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Re-authentication cancelled.');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
    // Email/password users: Firebase only requires recent login,
    // if the session is fresh enough it will just work.
    // If not, user.delete() will throw requires-recent-login.
  }

  // ── Friendly error messages ──

  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Try a different sign-in method.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
