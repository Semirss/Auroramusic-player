import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ss_musicplayer/src/features/player/services/auth_service.dart'; // Assuming same path

// Color Palette Constants
const Color _accentColor = Color(0xFFBB86FC); // Vibrant Purple/Blue
const Color _darkSurface = Color(0xFF121212); // Deep dark background
const Color _lightGrey = Color(0xFF9E9E9E); // For hints/labels

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      // The register functionality is implicitly handled by Firebase's sign-in-or-register behavior
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      _showErrorSnackbar('Google sign up failed: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pop(); // Go back to LoginScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkSurface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [_darkSurface, Colors.black],
            center: Alignment(0, -0.6),
            radius: 1.2,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  const Icon(
                    Icons.music_video,
                    color: _accentColor,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Aurora Music',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up to get started!',
                    style: TextStyle(
                      color: _lightGrey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 80),

                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _lightGrey, width: 1),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Image(
                              image: AssetImage('assets/images/google_logo.png'),
                              height: 24,
                            ),
                      label: const Text(
                        'Sign Up with Google',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Back to Login Button
                  TextButton(
                    onPressed: _navigateToLogin,
                    child: const Text(
                      'Already have an account? Log In',
                      style: TextStyle(color: _accentColor, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}