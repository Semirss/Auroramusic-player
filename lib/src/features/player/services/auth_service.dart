import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService(this._auth, this._googleSignIn);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email and Password Authentication
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print("User signed in: ${userCredential.user?.email}");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Email sign in error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      print("User created: ${userCredential.user?.email}");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Email sign up error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      print("Password reset email sent to: $email");
    } on FirebaseAuthException catch (e) {
      print("Password reset error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Google Sign-In
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Check if we're on web and handle accordingly
      if (kIsWeb) {
        // Web implementation
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        print("Google sign in successful (web): ${userCredential.user?.email}");
        return userCredential;
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw FirebaseAuthException(
            code: 'cancelled',
            message: 'Sign in cancelled by user',
          );
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        print("Google sign in successful (mobile): ${userCredential.user?.email}");
        return userCredential;
      }
    } on FirebaseAuthException catch (e) {
      print("Google sign in error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Unexpected error during Google sign in: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      print("User signed out successfully");
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Update user profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
      print("Profile updated successfully");
    } on FirebaseAuthException catch (e) {
      print("Profile update error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.updateEmail(newEmail.trim());
      print("Email updated successfully");
    } on FirebaseAuthException catch (e) {
      print("Email update error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      print("Password updated successfully");
    } on FirebaseAuthException catch (e) {
      print("Password update error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      print("Account deleted successfully");
    } on FirebaseAuthException catch (e) {
      print("Account deletion error: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Get user ID token
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      print("Error getting ID token: $e");
      return null;
    }
  }

  // Reload user data
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print("Error reloading user: $e");
    }
  }
}

// --- Providers ---

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
    // For web, the clientId should be configured in index.html meta tag
    // For mobile, you can optionally configure clientId here
    // clientId: 'your-client-id-for-mobile.apps.googleusercontent.com',
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
  );
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

final isLoggedInProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.isLoggedIn;
});
