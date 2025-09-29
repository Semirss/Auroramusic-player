import 'package:ss_musicplayer/src/core/theme/app_theme.dart';
import 'package:ss_musicplayer/src/features/player/screens/login_screen.dart';
import 'package:ss_musicplayer/src/features/player/services/auth_service.dart';
import 'package:ss_musicplayer/src/features/home/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:audio_service/audio_service.dart';
import 'package:ss_musicplayer/src/core/supabase_client.dart';
import 'package:audio_session/audio_session.dart';

// Import your player service (make sure the path is correct)
import 'package:ss_musicplayer/src/features/player/services/player_service.dart';

// Late final global variable for the AudioHandler
late AudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print("🚀 Starting Aurora Music App...");
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
  }
  
  // Initialize Supabase
  try {
    await SupabaseService().initialize();
    print("✅ Supabase initialized successfully");
  } catch (e) {
    print("❌ Supabase initialization failed: $e");
  }
  
  // Configure Audio Session for better audio behavior
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
    print("✅ Audio session configured successfully");
  } catch (e) {
    print("❌ Audio session configuration failed: $e");
  }
  
  // Initialize AudioService
  try {
    _audioHandler = await AudioService.init(
      builder: () => PlayerService(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.aurora_music.channel.audio',
        androidNotificationChannelName: 'Aurora Music',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        preloadArtwork: true,
      ),
    );
    print("✅ AudioService initialized successfully");
  } catch (e) {
    print("❌ AudioService initialization failed: $e");
    // Create a fallback audio handler
    try {
      _audioHandler = await AudioService.init(
        builder: () => PlayerService(),
      );
      print("✅ Fallback AudioService initialized");
    } catch (e2) {
      print("❌ Fallback AudioService also failed: $e2");
    }
  }

  runApp(
    const ProviderScope(
      child: AuroraMusicApp(),
    ),
  );
}

class AuroraMusicApp extends ConsumerWidget {
  const AuroraMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the authentication state
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'Aurora Music',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: authState.when(
        data: (user) {
          if (user != null) {
            print("👤 User logged in: ${user.email}");
            return const HomeScreen();
          }
          print("👤 No user logged in, showing login screen");
          return const LoginScreen();
        },
        loading: () {
          print("⏳ Loading authentication state...");
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading Aurora Music...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        },
        error: (err, stack) {
          print("❌ Authentication error: $err");
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Authentication Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      '$err',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      // Restart the app or try again
                      runApp(
                        const ProviderScope(
                          child: AuroraMusicApp(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}