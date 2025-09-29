import 'package:flutter/material.dart';
import 'package:ss_musicplayer/src/features/player/screens/login_screen.dart';

// Color Palette Constants
const Color _accentColor = Color(0xFFBB86FC); // Vibrant Purple/Blue
const Color _darkSurface = Color(0xFF121212); // Deep dark background
const Color _lightGrey = Color(0xFF9E9E9E); // For hints/labels

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  
  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page: Call the onGetStarted callback
      widget.onGetStarted();
    }
  }

  // Helper for a single page in the PageView
  Widget _buildPage({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            color: _accentColor,
            size: 150.0,
          ),
          const SizedBox(height: 40.0),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15.0),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _lightGrey,
              fontSize: 16.0,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build the dot indicators
  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      height: 8.0,
      width: _currentPage == index ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: _currentPage == index ? _accentColor : _lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
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
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const ClampingScrollPhysics(),
                children: <Widget>[
                  _buildPage(
                    title: 'Your Ultimate Music Hub',
                    description: 'Stream millions of songs and create a soundtrack for your life.',
                    icon: Icons.music_note,
                  ),
                  _buildPage(
                    title: 'Effortless Bulk Uploads',
                    description: 'Easily manage your vast collection with bulk music uploading support.',
                    icon: Icons.upload_file,
                  ),
                  _buildPage(
                    title: 'Smart Playlist Creation',
                    description: 'Create single or multiple personalized playlists in seconds to fit any mood.',
                    icon: Icons.playlist_add_check,
                  ),
                ],
              ),
            ),
            // Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, _buildDot),
            ),
            const SizedBox(height: 20),
            // Next/Get Started Button
            Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 40.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    _currentPage < 2 ? 'Next' : 'Get Started',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}