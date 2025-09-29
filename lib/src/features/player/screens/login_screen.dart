import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ss_musicplayer/src/features/player/services/auth_service.dart';

// Color Palette Constants from HomeScreen
const Color _accentColor = Color(0xFFBB86FC); // Vibrant Purple/Blue
const Color _darkSurface = Color(0xFF121212); // Deep dark background
const Color _mediumSurface = Color(0xFF1E1E1E); // Slightly lighter for input fields
const Color _lightGrey = Color(0xFF9E9E9E); // For hints/labels

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  
  // State to track which action is loading
  String _loadingAction = '';

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadingAction = 'google';
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      _showErrorSnackbar('Google sign in failed: ${e.toString()}');
    } finally {
      // Only set loading to false if this specific action finishes last
      if (_loadingAction == 'google') {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadingAction = 'email';
    });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      _showErrorSnackbar('Sign in failed: ${e.toString()}');
    } finally {
      if (_loadingAction == 'email') {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    // Determine the loading status for specific buttons
    final isEmailLoading = _isLoading && _loadingAction == 'email';
    final isGoogleLoading = _isLoading && _loadingAction == 'google';

    return Scaffold(
      // Use the deep dark background
      backgroundColor: _darkSurface,
      body: Container(
        // Add a subtle radial gradient for advanced depth
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
                    Icons.music_video, // Use an icon for branding
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
                    'Log in to stream millions of songs',
                    style: TextStyle(
                      color: _lightGrey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    icon: Icons.email,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  _buildTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    icon: Icons.lock,
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: _lightGrey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isEmailLoading ? null : _signInWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor, // Use the vibrant accent color
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 5,
                      ),
                      child: isEmailLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider(color: _lightGrey)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text("OR", style: TextStyle(color: _lightGrey)),
                      ),
                      Expanded(child: Divider(color: _lightGrey)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: isGoogleLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _lightGrey, width: 1), // Subtle border
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: isGoogleLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                            : const Image(
                              image: AssetImage('assets/images/google_logo.png'),
                              height: 24,
                              key: ValueKey('google_logo'),
                            ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16),
                      ),
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

  // Helper method for styled text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: labelText.toLowerCase().contains('email')
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: _lightGrey),
        prefixIcon: Icon(icon, color: _lightGrey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _mediumSurface, // Use a medium surface color for the background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none, // Hide default border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accentColor, width: 2), // Accent border on focus
        ),
      ),
      style: const TextStyle(color: Colors.white),
      cursorColor: _accentColor,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}