import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:ss_musicplayer/src/core/supabase_client.dart';
import 'package:ss_musicplayer/src/features/player/services/auth_service.dart';
import 'package:ss_musicplayer/src/features/player/services/player_service.dart';
import 'package:ss_musicplayer/src/features/player/models/track.dart';
import 'package:ss_musicplayer/src/core/image_service.dart';
import 'package:ss_musicplayer/theme/dark_mode.dart';
import 'package:ss_musicplayer/theme/light_mode.dart';
import 'package:share_plus/share_plus.dart';

class LibraryScreen extends StatelessWidget {
  final String title;
  final Widget? content;
  const LibraryScreen({super.key, required this.title, this.content});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: content ?? Center(child: Text('$title Content Here', style: const TextStyle(fontSize: 18))),
    );
  }
}

// FINAL CLIENT ACCESS
final SupabaseClient supabase = SupabaseService().client;

// COLOR & THEME CONSTANTS
const Color _accentColor = Color(0xFFBB86FC);
const Color _darkSurface = Color(0xFF121212);
const Color _mediumSurface = Color(0xFF1E1E1E);

// Theme Provider
class ThemeProvider extends ChangeNotifier {
  ThemeData _themeData = darkMode; // Changed from lightMode to darkMode
  ThemeProvider(this._themeData);
  ThemeData get themeData => _themeData;
  bool get isDarkMode => _themeData == darkMode;
  set themeData(ThemeData themeData) {
    _themeData = themeData;
    notifyListeners();
  }
  void toggleTheme() {
    themeData = _themeData == lightMode ? darkMode : lightMode;
  }
}

final themeProvider = ChangeNotifierProvider<ThemeProvider>((ref) {
  return ThemeProvider(darkMode); // Changed from lightMode to darkMode
});
// SETTINGS/PREFERENCES PROVIDER
class SettingsNotifier extends StateNotifier<Map<String, dynamic>> {
  SettingsNotifier()
      : super({
          'shuffleMode': false,
          'highQualityStreaming': false,
          'gaplessPlayback': true,
        });

  void toggleSetting(String key) {
    state = {...state, key: !state[key]};
  }

  void setShuffle(bool value) {
    state = {...state, 'shuffleMode': value};
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Map<String, dynamic>>((ref) {
  return SettingsNotifier();
});

// DATA MODELS
class MockPlaylist {
  final String id;
  final String title;
  final String imageUrl;
  MockPlaylist(this.id, this.title, this.imageUrl);
  factory MockPlaylist.fromJson(Map<String, dynamic> json) {
    return MockPlaylist(
      json['id'] as String,
      json['title'] as String,
      json['image_url'] as String,
    );
  }
}
class TrackDetails {
  final String id;
  final String title;
  final String artist;
  final String mp3Path;
  final String albumId; // Add this field
  final bool isLiked;
  final int durationMs;

  TrackDetails({
    required this.id,
    required this.title,
    required this.artist,
    required this.mp3Path,
    required this.albumId, // Add this parameter
    required this.isLiked,
    this.durationMs = 180000,
  });

  factory TrackDetails.fromJson(Map<String, dynamic> json) {
    return TrackDetails(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      mp3Path: json['mp3_path'] as String,
      albumId: json['album_id'] as String, // Add this mapping
      isLiked: (json['is_liked'] as bool?) ?? false,
      durationMs: (json['duration_ms'] as int?) ?? 180000,
    );
  }
}

// RIVERPOD PROVIDERS
final homeContentProvider = FutureProvider<Map<String, List<MockPlaylist>>>((ref) async {
  try {
    final response = await supabase.from('playlists').select().order('category', ascending: true);

    if (response is List) {
      final quickAccess = response
          .where((item) => item['category'] == 'quick_access')
          .map((json) => MockPlaylist.fromJson(json))
          .take(6)
          .toList();
      final heavyRotation = response
          .where((item) => item['category'] == 'heavy_rotation')
          .map((json) => MockPlaylist.fromJson(json))
          .toList();
      final userPlaylists = response
          .where((item) => item['category'] == 'user_playlist')
          .map((json) => MockPlaylist.fromJson(json))
          .toList();

      return {'quickAccess': quickAccess, 'heavyRotation': heavyRotation, 'userPlaylists': userPlaylists};
    }
    throw Exception('Supabase fetch did not return a list.');
  } on PostgrestException catch (e) {
    throw Exception('Database Error: ${e.message}');
  } catch (e) {
    throw Exception('Failed to fetch home content: $e');
  }
});

final playlistTracksProvider = FutureProvider.family<List<TrackDetails>, String>((ref, playlistId) async {
  try {
    final response = await supabase
        .from('tracks')
        .select()
        .eq('album_id', playlistId)
        .order('title', ascending: true);

    if (response is List) {
      return response.map((json) => TrackDetails.fromJson(json)).toList();
    }
    return [];
  } on PostgrestException catch (e) {
    debugPrint("Error fetching tracks for $playlistId: ${e.message}");
    return [];
  }
});

final favoriteTracksProvider = FutureProvider<List<TrackDetails>>((ref) async {
  try {
    final response = await supabase
        .from('tracks')
        .select()
        .eq('is_liked', true)
        .order('created_at', ascending: false);

    if (response is List) {
      return response.map((json) => TrackDetails.fromJson(json)).toList();
    }
    return [];
  } on PostgrestException catch (e) {
    debugPrint("Error fetching liked songs: ${e.message}");
    return [];
  }
});

final playlistsProvider = FutureProvider<List<MockPlaylist>>((ref) async {
  try {
    final response = await supabase.from('playlists').select();
    if (response is List) {
      return response.map((json) => MockPlaylist.fromJson(json)).toList();
    }
    return [];
  } catch (e) {
    debugPrint("Error fetching playlists: $e");
    return [];
  }
});

final searchResultsProvider = FutureProvider.family<List<TrackDetails>, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return [];
  }
  try {
    // Make search less strict by splitting query into words
    final searchTerms = query.toLowerCase().split(' ').where((term) => term.isNotEmpty).toList();
    if (searchTerms.isEmpty) {
      return [];
    }

    // Build a filter that checks if title or artist contains all search terms
    final filters = searchTerms.map((term) => "or(title.ilike.%$term%,artist.ilike.%$term%)").join(',');

    final response = await supabase
        .from('tracks')
        .select()
        .or(filters)
        .limit(20);

    // A more robust way to handle potential JSArray on web vs List on mobile.
    // We cast to List<dynamic> and then manually build the final list.
    final List<dynamic> responseData = response;
    final List<TrackDetails> tracks = responseData
        .map((item) => TrackDetails.fromJson(item as Map<String, dynamic>))
        .toList();

    return tracks;
  } catch (e) {
    debugPrint("Error searching tracks: $e");
    return [];
  }
});

// Global Key for Drawer management
final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

// HOME SCREEN IMPLEMENTATION
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openPlaylistDetails(MockPlaylist playlist, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }
void _playTrackDetails(TrackDetails track, WidgetRef ref, BuildContext context) async {
  try {
    // Extract just the filename from the path
    final fileName = track.mp3Path.split('/').last;
    
    // Generate the public URL
    final String fullMp3Url = supabase.storage.from('audio_files').getPublicUrl(fileName);

    print("🎵 Playing from URL: $fullMp3Url");

    // Create Track with correct parameters
    final Track playableTrack = Track(
      id: track.id,
      title: track.title,
      artistName: track.artist,
      albumId: track.albumId, // Now this will work
      storagePath: fileName,
      isLiked: track.isLiked,
      // createdAt is optional in Track model, so we can omit it
    );

    await _playTrack(playableTrack, context, ref);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now playing: ${track.title} by ${track.artist}'),
          backgroundColor: _accentColor,
        ),
      );
    }
  } catch (e) {
    print("❌ Error playing track: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing track: ${e.toString()}'), 
          backgroundColor: Colors.red
        ),
      );
    }
  }
}
  Future<void> _playTrack(Track track, BuildContext context, WidgetRef ref) async {
    try {
      final playerService = ref.read(playerServiceProvider);
       playerService.clearQueue();
       playerService.addQueueItem(track.toMediaItem());
       playerService.play();
      ref.read(currentTrackProvider.notifier).state = track;
      ref.read(isPlayingProvider.notifier).state = true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing track: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _togglePlayPause(WidgetRef ref) async {
    final currentTrack = ref.read(currentTrackProvider);
    if (currentTrack == null) return;
    try {
      final playerService = ref.read(playerServiceProvider);
      final isPlaying = ref.read(isPlayingProvider);
      if (isPlaying) {
       playerService.pause();
      } else {
         playerService.play();
      }
      ref.read(isPlayingProvider.notifier).state = !isPlaying;
    } catch (e) {
      debugPrint("Error toggling play/pause: $e");
    }
  }

  void _skipToNext(WidgetRef ref, BuildContext context) async {
    try {
      final playerService = ref.read(playerServiceProvider);
      if (playerService.hasNext) {
        await playerService.skipToNext();
        await Future.delayed(const Duration(milliseconds: 100)); // Allow state to update
        final newTrack = playerService.getCurrentTrack();
        if (newTrack != null) {
          ref.read(currentTrackProvider.notifier).state = newTrack;
          ref.read(isPlayingProvider.notifier).state = true;
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End of queue'), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      debugPrint("Error skipping to next: $e");
    }
  }

  void _skipToPrevious(WidgetRef ref, BuildContext context) async {
    try {
      final playerService = ref.read(playerServiceProvider);
      if (playerService.hasPrevious) {
        await playerService.skipToPrevious();
        await Future.delayed(const Duration(milliseconds: 100)); // Allow state to update
        final newTrack = playerService.getCurrentTrack();
        if (newTrack != null) {
          ref.read(currentTrackProvider.notifier).state = newTrack;
          ref.read(isPlayingProvider.notifier).state = true;
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Start of queue'), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      debugPrint("Error skipping to previous: $e");
    }
  }

  String _getRandomPlaylistImage(String playlistId) {
    // Use playlist ID to generate consistent but random image
    final random = Random(playlistId.hashCode);
    final imageId = random.nextInt(1000);
    return 'https://picsum.photos/200/200?random=$imageId';
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final theme = ref.watch(themeProvider);
    final isDarkMode = theme.isDarkMode;

    final homeContentAsync = ref.watch(homeContentProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? _darkSurface : lightMode.scaffoldBackgroundColor,
      drawer: _buildDrawer(context, ref, isDarkMode),
      body: homeContentAsync.when(
        data: (data) {
          final quickAccess = data['quickAccess']!;
          final heavyRotation = data['heavyRotation']!;
          final userPlaylists = data['userPlaylists']!;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, ref, user, isDarkMode),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildQuickAccessGrid(context, isDarkMode, quickAccess, ref),
                  const SizedBox(height: 32),
                  _buildHorizontalSection(context, isDarkMode, title: "Heavy Rotation", playlists: heavyRotation, ref: ref),
                  const SizedBox(height: 32),
                  _buildHorizontalSection(context, isDarkMode, title: "Your Playlists", playlists: userPlaylists, ref: ref),
                  SizedBox(height: currentTrack != null ? 100.0 : 40.0),
                ]),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: isDarkMode ? _accentColor : _accentColor)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'Error fetching playlists: ${err.toString()}',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      bottomNavigationBar: currentTrack != null
          ? _buildPlayerBar(currentTrack, isPlaying, ref, context, isDarkMode)
          : null,
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, WidgetRef ref, dynamic user, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : const Color.fromARGB(255, 0, 0, 0);

    return SliverAppBar(
      backgroundColor: isDarkMode ? _darkSurface : _accentColor,
      elevation: 0,
      pinned: true,
      floating: true,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: textColor),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Text(
          
          'Aurora Music',
          style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      actions: [
        IconButton( // Changed to Premium Button
          icon: Icon(Icons.workspace_premium_outlined, color: textColor),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: isDarkMode ? _darkSurface : Colors.white,
                  title: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: _accentColor),
                      const SizedBox(width: 10),
                      Text(
                        'Go Premium',
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Text(
                          'Unlock exclusive features with Aurora Premium!',
                          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 20),
                        _buildPremiumPackage(context, isDarkMode, 'Monthly', '\$4.99/month', 'Ad-free listening, offline downloads, and high-quality audio.'),
                        const SizedBox(height: 10),
                        _buildPremiumPackage(context, isDarkMode, 'Yearly', '\$49.99/year', 'Save 15%! All premium features for a full year.'),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: Text('Close', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    ElevatedButton(
                      child: const Text('Learn More'),
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                );
              },
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: textColor),
          onPressed: () {
            ref.invalidate(homeContentProvider);
            ref.invalidate(playlistsProvider);
            ref.invalidate(favoriteTracksProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refreshing...'), duration: Duration(seconds: 1)),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.logout, color: isDarkMode ? _accentColor : Colors.white  ),
          onPressed: () => ref.read(authServiceProvider).signOut(),
        ),
      ],
    );
  }

  Widget _buildPremiumPackage(BuildContext context, bool isDarkMode, String title, String price, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(price, style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, bool isDarkMode, List<MockPlaylist> quickAccess, WidgetRef ref) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? _mediumSurface : Colors.grey[300];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: quickAccess.length,
        itemBuilder: (context, index) {
          final playlist = quickAccess[index];
          return Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: isDarkMode ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
            ),
            child: InkWell(
              onTap: () => _openPlaylistDetails(playlist, context),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                    child: Image.network(
                      playlist.imageUrl,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => Container(
                        width: 54,
                        height: 54,
                        color: Colors.grey[700],
                        child: const Icon(Icons.broken_image, size: 20, color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      playlist.title,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalSection(BuildContext context, bool isDarkMode, {required String title, required List<MockPlaylist> playlists, required WidgetRef ref}) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.grey : Colors.grey[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: playlists.length,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 130,
                  child: InkWell(
                    onTap: () => _openPlaylistDetails(playlist, context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            playlist.imageUrl,
                            width: 130,
                            height: 130,
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => Container(
                              width: 130,
                              height: 130,
                              color: Colors.grey[700],
                              child: const Icon(Icons.broken_image, size: 40, color: Colors.redAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playlist.title,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Playlist by Aurora",
                          style: TextStyle(color: subTextColor, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, bool isDarkMode) {
    final themeProviderInstance = ref.watch(themeProvider);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final dividerColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    void navigate(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
final favoriteContent = Consumer(
  builder: (context, ref, child) {
    final favoritesAsync = ref.watch(favoriteTracksProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.grey : Colors.black54;

    return favoritesAsync.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: textColor.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No liked songs yet',
                  style: TextStyle(color: textColor, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the heart icon on any song to add it here',
                  style: TextStyle(color: subTextColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return ListTile(
              leading: const Icon(Icons.music_note, color: _accentColor),
              title: Text(track.title, style: TextStyle(color: textColor)),
              subtitle: Text(track.artist, style: TextStyle(color: subTextColor)),
              trailing: IconButton(
                icon: Icon(
                  track.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: track.isLiked ? Colors.redAccent : subTextColor,
                ),
                onPressed: () async {
                  try {
                    // Toggle like status in database
                    await supabase
                        .from('tracks')
                        .update({'is_liked': !track.isLiked})
                        .eq('id', track.id);
                    
                    // Refresh the favorites list
                    ref.invalidate(favoriteTracksProvider);
                    
                    // Show feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !track.isLiked 
                            ? 'Added to Liked Songs' 
                            : 'Removed from Liked Songs',
                        ),
                        backgroundColor: !track.isLiked ? _accentColor : Colors.grey,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating like: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              onTap: () => _playTrackDetails(track, ref, context),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
               const Text(
                'Error loading favorites',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(color: subTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(favoriteTracksProvider),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

    final settingsContent = Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsProvider);
        final settingsNotifier = ref.read(settingsProvider.notifier);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Playback Preferences', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            SwitchListTile(
              title: Text('Shuffle Mode', style: TextStyle(color: textColor)),
              subtitle: Text('Play songs in a random order.', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
              value: settings['shuffleMode'],
              onChanged: (_) => settingsNotifier.toggleSetting('shuffleMode'),
              activeColor: _accentColor,
            ),
            SwitchListTile(
              title: Text('High Quality Streaming', style: TextStyle(color: textColor)),
              subtitle: Text('Uses more data but sounds better.', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
              value: settings['highQualityStreaming'],
              onChanged: (_) => settingsNotifier.toggleSetting('highQualityStreaming'),
              activeColor: _accentColor,
            ),
            SwitchListTile(
              title: Text('Gapless Playback', style: TextStyle(color: textColor)),
              subtitle: Text('Removes silence between tracks.', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
              value: settings['gaplessPlayback'],
              onChanged: (_) => settingsNotifier.toggleSetting('gaplessPlayback'),
              activeColor: _accentColor,
            ),
          ],
        );
      },
    );

    return Drawer(
      backgroundColor: isDarkMode ? _darkSurface : lightMode.scaffoldBackgroundColor,
      child: Column(
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                children: [
                  Icon(Icons.music_video, size: 30, color: _accentColor),
                  SizedBox(width: 8),
                  Text('Aurora', style: TextStyle(color: isDarkMode? Colors.white: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _DrawerTile(
                  icon: Icons.home,
                  title: 'Home',
                  isSelected: true,
                  isDarkMode: isDarkMode,
                  onTap: () => Navigator.pop(context),
                ),
                
                _DrawerTile(
                  icon: Icons.search,
                  title: 'Search',
                  isDarkMode: isDarkMode,
                  onTap: () => navigate(const GlobalSearchScreen()),
                ),
                Divider(color: dividerColor, height: 32, thickness: 0.5, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'YOUR LIBRARY',
                    style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                _DrawerTile(
                  icon: Icons.favorite,
                  title: 'Liked Songs',
                  isDarkMode: isDarkMode,
                  onTap: () => navigate(LibraryScreen(title: 'Liked Songs', content: favoriteContent)),
                  iconColor: Colors.redAccent,
                ),
               
                Divider(color: dividerColor, height: 32, thickness: 0.5, indent: 16, endIndent: 16),
                _DrawerTile(
                  icon: Icons.settings,
                  title: 'Settings',
                  isDarkMode: isDarkMode,
                  onTap: () => navigate(LibraryScreen(title: 'Settings & Preferences', content: settingsContent)),
                ),
                _DrawerTile(
                  icon: Icons.add_circle,
                  title: 'Add Song',
                  isDarkMode: isDarkMode,
                  onTap: () => navigate(const AddSongScreen()),
                ),
                // Add this to your drawer list in HomeScreen's _buildDrawer method
                _DrawerTile(
                    icon: Icons.library_add,
                    title: 'Bulk Upload',
                    isDarkMode: isDarkMode,
                    onTap: () => navigate(const MusicDumpScreen()),
                    ),
              SwitchListTile(
  title: Text('Dark Mode', style: TextStyle(color: textColor)),
  secondary: Icon(
    isDarkMode ? Icons.dark_mode : Icons.light_mode,
    color: isDarkMode ? _accentColor : Colors.orange,
  ),
  value: isDarkMode, // This will now be true by default
  onChanged: (value) => themeProviderInstance.toggleTheme(),
  activeColor: _accentColor,
  tileColor: isDarkMode ? _mediumSurface.withOpacity(0.3) : Colors.grey[200],
  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0, top: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  final titleController = TextEditingController();
                  final title = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title:  Text(
                        'Create New Playlist',
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      ),
                      content: TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Playlist title'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (titleController.text.isNotEmpty) {
                              Navigator.pop(context, titleController.text);
                            }
                          },
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  );
                  if (title != null && title.isNotEmpty) {
                    try {
                      final response = await supabase.from('playlists').insert({
                        'id': const Uuid().v4(),
                        'title': title,
                        'image_url': 'https://picsum.photos/200/200?random=${DateTime.now().millisecondsSinceEpoch}',
                        'category': 'user_playlist',
                        'created_at': DateTime.now().toIso8601String(),
                      }).select();
                      if (response.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Playlist created successfully!')),
                        );
                        ref.refresh(homeContentProvider);
                        ref.refresh(playlistsProvider);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating playlist: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.add_box_rounded, color: _accentColor),
                label: Text('CREATE PLAYLIST', style: TextStyle(color: isDarkMode?Colors.white: Colors.black, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: isDarkMode ? _mediumSurface.withOpacity(0.5) : Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerBar(Track currentTrack, bool isPlaying, WidgetRef ref, BuildContext context, bool isDarkMode) {
    final barColor = isDarkMode ? _mediumSurface : Colors.grey[200];
    final textColor = isDarkMode ? Colors.white : const Color.fromARGB(255, 0, 0, 0);
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final playerService = ref.read(playerServiceProvider);

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.8 : 0.3), spreadRadius: 2, blurRadius: 10)
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const FullScreenPlayer()));
        },
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: FutureBuilder(
                  future: supabase.from('playlists').select('image_url').eq('id', currentTrack.albumId).maybeSingle(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildImageLoading(50, isDarkMode);
                    }
                    if (snapshot.hasError) {
                      return _buildImageError(50, isDarkMode);
                    }
                    final imageUrl = snapshot.data?['image_url'] ?? _getRandomPlaylistImage(currentTrack.albumId);
                    return Image.network(
                      imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => _buildImageError(50, isDarkMode),
                      loadingBuilder: (context, child, progress) {
                        return progress == null ? child : _buildImageLoading(50, isDarkMode);
                      },
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTrack.title,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentTrack.artistName,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, color: playerService.hasPrevious ? textColor : textColor.withOpacity(0.3)),
                  onPressed: playerService.hasPrevious ? () => _skipToPrevious(ref, context) : null,
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: _accentColor,
                    size: 40,
                  ),
                  onPressed: () => _togglePlayPause(ref),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, color: playerService.hasNext ? textColor : textColor.withOpacity(0.3)),
                  onPressed: playerService.hasNext ? () => _skipToNext(ref, context) : null,
                  padding: const EdgeInsets.only(right: 8.0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError(double size, bool isDarkMode) {
    return Container(
      width: size,
      height: size,
      color: isDarkMode ? _mediumSurface : Colors.grey[300],
      child: Icon(Icons.broken_image, size: size * 0.4, color: Colors.redAccent),
    );
  }

  Widget _buildImageLoading(double size, bool isDarkMode) {
    return Container(
      width: size,
      height: size,
      color: isDarkMode ? _mediumSurface : Colors.grey[300],
      child: Center(child: SizedBox(width: size * 0.4, height: size * 0.4, child: const CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

// Custom Drawer Tile
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDarkMode;
  final Color? iconColor;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    required this.isDarkMode,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final iconDefaultColor = isDarkMode ? Colors.white70 : Colors.black54;
    final selectedColor = isDarkMode ? _mediumSurface : Colors.grey[300];

    return ListTile(
      leading: Icon(icon, color: iconColor ?? (isSelected ? _accentColor : iconDefaultColor)),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? _accentColor : textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: selectedColor,
      onTap: onTap,
    );
  }
}

// PLAYLIST DETAIL SCREEN - ADVANCED VERSION
class PlaylistDetailScreen extends ConsumerWidget {
  final MockPlaylist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  void _playTrackDetails(TrackDetails track, WidgetRef ref, BuildContext context) {
    final homeScreen = HomeScreen();
    homeScreen._playTrackDetails(track, ref, context);
  }

  Future<void> _toggleLikeStatus(TrackDetails track, WidgetRef ref) async {
    try {
      await supabase
          .from('tracks')
          .update({'is_liked': !track.isLiked})
          .eq('id', track.id);
      
      // Refresh the playlist tracks
      ref.invalidate(playlistTracksProvider(playlist.id));
      ref.invalidate(favoriteTracksProvider);
    } catch (e) {
      print("Error toggling like status: $e");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(playlistTracksProvider(playlist.id));
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? _darkSurface : lightMode.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(playlist.title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? _darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.play_circle_fill, color: _accentColor),
            onPressed: tracksAsync.value != null && tracksAsync.value!.isNotEmpty
                ? () => _playTrackDetails(tracksAsync.value!.first, ref, context)
                : null,
          ),
          IconButton(
            icon: Icon(Icons.shuffle, color: textColor.withOpacity(0.7)),
            onPressed: tracksAsync.value != null && tracksAsync.value!.isNotEmpty
                ? () {
                    final randomTrack = tracksAsync.value![Random().nextInt(tracksAsync.value!.length)];
                    _playTrackDetails(randomTrack, ref, context);
                  }
                : null,
          ),
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return _buildEmptyState(context, isDarkMode, textColor);
          }
          return Column(
            children: [
              // Playlist Header
              _buildPlaylistHeader(context, tracks, isDarkMode, textColor, ref),
              
              // Tracks List
              Expanded(
                child: _buildTracksList(tracks, isDarkMode, textColor, ref, context, currentTrack, isPlaying),
              ),
            ],
          );
        },
        loading: () => _buildLoadingState(isDarkMode),
        error: (e, s) => _buildErrorState(e),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDarkMode, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 80, color: textColor.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'No songs in this playlist',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Add some songs to get started',
            style: TextStyle(color: textColor.withOpacity(0.6)),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Songs'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSongScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: isDarkMode ? _accentColor : _accentColor),
          const SizedBox(height: 16),
          Text(
            'Loading tracks...',
            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load tracks',
              style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistHeader(BuildContext context, List<TrackDetails> tracks, bool isDarkMode, Color textColor, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode
              ? [Colors.purple[900]!, _darkSurface]
              : [Colors.purple[100]!, Colors.white],
        ),
      ),
      child: Column(
        children: [
          // Playlist Image
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                playlist.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => Container(
                  color: isDarkMode ? _mediumSurface : Colors.grey[300],
                  child: Icon(Icons.music_note, size: 60, color: textColor.withOpacity(0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Playlist Info
          Text(
            playlist.title,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${tracks.length} ${tracks.length == 1 ? 'song' : 'songs'}',
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play Button
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text('PLAY', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: tracks.isNotEmpty ? () => _playTrackDetails(tracks.first, ref, context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
              ),
              const SizedBox(width: 16),
              
              // Shuffle Button
              OutlinedButton.icon(
                icon: const Icon(Icons.shuffle),
                label: const Text('SHUFFLE'),
                onPressed: tracks.isNotEmpty ? () {
                  final randomTrack = tracks[Random().nextInt(tracks.length)];
                  _playTrackDetails(randomTrack, ref, context);
                } : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  side: BorderSide(color: textColor.withOpacity(0.3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTracksList(List<TrackDetails> tracks, bool isDarkMode, Color textColor, WidgetRef ref, BuildContext context, Track? currentTrack, bool isPlaying) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tracks.length,
      separatorBuilder: (context, index) => Divider(
        color: isDarkMode ? Colors.white12 : Colors.black12,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrentTrack = currentTrack?.id == track.id;
        
        return Container(
          decoration: BoxDecoration(
            color: isCurrentTrack 
                ? (isDarkMode ? _accentColor.withOpacity(0.2) : _accentColor.withOpacity(0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    playlist.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => Container(
                      width: 50,
                      height: 50,
                      color: isDarkMode ? _mediumSurface : Colors.grey[300],
                      child: Icon(Icons.music_note, color: textColor.withOpacity(0.5)),
                    ),
                  ),
                ),
                if (isCurrentTrack)
                  Container(
                    width: 50,
                    height: 50,
                    color: Colors.black.withOpacity(0.5),
                    child: Icon(
                      isPlaying ? Icons.equalizer : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
            title: Text(
              track.title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.artist,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Like Button
                IconButton(
                  icon: Icon(
                    track.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: track.isLiked ? Colors.redAccent : textColor.withOpacity(0.6),
                    size: 22,
                  ),
                  onPressed: () => _toggleLikeStatus(track, ref),
                  splashRadius: 20,
                ),
                // Duration
                Text(
                  _formatDuration(track.durationMs),
                  style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () {
              _playTrackDetails(track, ref, context);
              // Navigate to full screen player
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FullScreenPlayer()));
            },
          ),
        );
      },
    );
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
// ADVANCED FULL SCREEN PLAYER - FIXED VERSION
class FullScreenPlayer extends ConsumerWidget {
  const FullScreenPlayer({super.key});

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // FIXED: Get random image URL for playlists
  String _getRandomPlaylistImage(String playlistId) {
    // Use playlist ID to generate consistent but random image
    final random = Random(playlistId.hashCode);
    final imageId = random.nextInt(1000);
    return 'https://picsum.photos/200/200?random=$imageId';
  }

  // FIXED: Improved play/pause toggle
  void _togglePlayPause(WidgetRef ref) async {
    try {
      final playerService = ref.read(playerServiceProvider);
      final currentIsPlaying = ref.read(isPlayingProvider);

      if (currentIsPlaying) {
        await playerService.pause();
        ref.read(isPlayingProvider.notifier).state = false;
      } else {
        await playerService.play();
        ref.read(isPlayingProvider.notifier).state = true;
      }
    } catch (e) {
      debugPrint("Error toggling play/pause: $e");
    }
  }

  // FIXED: Skip to next with proper async handling
  void _skipToNext(WidgetRef ref, BuildContext context) async {
    try {
      final playerService = ref.read(playerServiceProvider);
      
      // Check if we have a next track
      if (playerService.hasNext) {
        await playerService.skipToNext();
        
        // Wait a bit for the player to update
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Get the new current track
        final newTrack = playerService.getCurrentTrack();
        if (newTrack != null) {
          ref.read(currentTrackProvider.notifier).state = newTrack;
          ref.read(isPlayingProvider.notifier).state = true;
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No next track available')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error skipping to next: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error skipping to next: $e')),
        );
      }
    }
  }

  // FIXED: Skip to previous with proper async handling
  void _skipToPrevious(WidgetRef ref, BuildContext context) async {
    try {
      final playerService = ref.read(playerServiceProvider);
      
      // Check if we have a previous track
      if (playerService.hasPrevious) {
        await playerService.skipToPrevious();
        
        // Wait a bit for the player to update
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Get the new current track
        final newTrack = playerService.getCurrentTrack();
        if (newTrack != null) {
          ref.read(currentTrackProvider.notifier).state = newTrack;
          ref.read(isPlayingProvider.notifier).state = true;
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previous track available')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error skipping to previous: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error skipping to previous: $e')),
        );
      }
    }
  }

  void _toggleShuffle(WidgetRef ref, BuildContext context) async {
    try {
      final currentShuffle = ref.read(shuffleModeProvider);
      final newShuffleState = !currentShuffle;
      
      ref.read(shuffleModeProvider.notifier).state = newShuffleState;

      final message = newShuffleState ? 'Shuffle enabled' : 'Shuffle disabled';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }

      // If shuffle is enabled and we have a current playlist, reshuffle the queue
      if (newShuffleState) {
        final currentTrack = ref.read(currentTrackProvider);
        final currentPlaylistId = currentTrack?.albumId;
        
        if (currentPlaylistId != null) {
          final tracks = await ref.read(playlistTracksProvider(currentPlaylistId).future);
          if (tracks.isNotEmpty) {
            final shuffledTracks = List<TrackDetails>.from(tracks)..shuffle();
            
            final trackObjects = shuffledTracks.map((track) => Track(
              id: track.id,
              title: track.title,
              artistName: track.artist,
              albumId: track.albumId,
              storagePath: track.mp3Path.split('/').last,
              isLiked: track.isLiked,
            )).toList();
            
            final playerService = ref.read(playerServiceProvider);
            await playerService.clearQueue();
            await playerService.addTracksToQueue(trackObjects);
            
            // Find and play the current track in the shuffled list
            final currentIndex = shuffledTracks.indexWhere((t) => t.id == currentTrack?.id);
            if (currentIndex != -1) {
              await playerService.playTrackAtIndex(currentIndex);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error toggling shuffle: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling shuffle: $e')),
        );
      }
    }
  }

  void _toggleRepeat(WidgetRef ref, BuildContext context) {
    final currentRepeatMode = ref.read(repeatModeProvider);
    RepeatMode nextMode;
    
    switch (currentRepeatMode) {
      case RepeatMode.off:
        nextMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        nextMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        nextMode = RepeatMode.off;
        break;
    }
    
    ref.read(repeatModeProvider.notifier).state = nextMode;
    
    final modeText = nextMode == RepeatMode.off ? 'Repeat Off' : 
                    nextMode == RepeatMode.one ? 'Repeat One' : 'Repeat All';
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(modeText)));
    }
  }

  // FIXED: Play track from details with proper queue setup
  Future<void> _playTrackFromDetails(TrackDetails track, WidgetRef ref, BuildContext context) async {
    try {
      // Convert TrackDetails to Track
      final playableTrack = Track(
        id: track.id,
        title: track.title,
        artistName: track.artist,
        albumId: track.albumId,
        storagePath: track.mp3Path.split('/').last,
        isLiked: track.isLiked,
      );

      final playerService = ref.read(playerServiceProvider);
      
      // Get the entire playlist to set up the queue
      final currentPlaylistId = track.albumId;
      final playlistTracks = await ref.read(playlistTracksProvider(currentPlaylistId).future);
      
      // Convert all tracks to Track objects
      final trackObjects = playlistTracks.map((t) => Track(
        id: t.id,
        title: t.title,
        artistName: t.artist,
        albumId: t.albumId,
        storagePath: t.mp3Path.split('/').last,
        isLiked: t.isLiked,
      )).toList();

      // Clear and set up the queue with all tracks
      await playerService.clearQueue();
      await playerService.addTracksToQueue(trackObjects);
      
      // Find the index of the current track in the playlist
      final currentIndex = playlistTracks.indexWhere((t) => t.id == track.id);
      if (currentIndex != -1) {
        await playerService.playTrackAtIndex(currentIndex);
      }
      
      // Update state
      ref.read(currentTrackProvider.notifier).state = playableTrack;
      ref.read(isPlayingProvider.notifier).state = true;

    } catch (e) {
      debugPrint("❌ Error playing track: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing track: ${e.toString()}'), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  Color _getRepeatButtonColor(RepeatMode mode, bool isDarkMode, Color textColor) {
    switch (mode) {
      case RepeatMode.off:
        return textColor.withOpacity(0.7);
      case RepeatMode.one:
        return _accentColor;
      case RepeatMode.all:
        return _accentColor;
    }
  }

  IconData _getRepeatButtonIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat;
    }
  }

  // Get actual duration from player service
  int _getTrackDuration(WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);
    final duration = playerService.duration;
    return duration?.inMilliseconds ?? 180000; // 3 minutes default
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final repeatMode = ref.watch(repeatModeProvider);
    final shuffleMode = ref.watch(shuffleModeProvider);
    
    // Use position provider safely
    final positionAsync = ref.watch(currentPositionProvider);
    final positionMs = positionAsync.value ?? 0;
    
    // Get duration from player service
    final trackDurationMs = _getTrackDuration(ref);
    
    final textColor = isDarkMode ? Colors.white : Colors.black;

    // Get player service instance
    final playerService = ref.read(playerServiceProvider);

    if (currentTrack == null) {
      return Scaffold(
        backgroundColor: isDarkMode ? _darkSurface : lightMode.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 80, color: textColor.withOpacity(0.3)),
              const SizedBox(height: 20),
              Text(
                'No track playing',
                style: TextStyle(color: textColor, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? _darkSurface : lightMode.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 30),
                    onPressed: () => Navigator.pop(context),
                    color: textColor,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'PLAYING FROM PLAYLIST',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                        FutureBuilder(
                          future: supabase.from('playlists').select().eq('id', currentTrack.albumId).single(),
                          builder: (context, snapshot) {
                            final playlistName = snapshot.data?['title'] ?? 'Playlist';
                            return Text(
                              playlistName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                    color: textColor,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Album Art - FIXED: Using random images
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FutureBuilder(
                        future: supabase.from('playlists').select().eq('id', currentTrack.albumId).single(),
                        builder: (context, snapshot) {
                          final playlist = snapshot.data;
                          final imageUrl = playlist?['image_url'] ?? _getRandomPlaylistImage(currentTrack.albumId);
                          
                          return Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => Container(
                              color: isDarkMode ? _mediumSurface : Colors.grey[300]!,
                              child: Icon(Icons.music_note, size: 80, color: textColor.withOpacity(0.5)),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: isDarkMode ? _mediumSurface : Colors.grey[300]!,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Track Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      children: [
                        Text(
                          currentTrack.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentTrack.artistName,
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            activeTrackColor: _accentColor,
                            inactiveTrackColor: textColor.withOpacity(0.3),
                            thumbColor: _accentColor,
                          ),
                          child: Slider(
                            min: 0,
                            max: trackDurationMs.toDouble().clamp(1.0, double.infinity),
                            value: positionMs.toDouble().clamp(0.0, trackDurationMs.toDouble()),
                            onChanged: (value) {
                              playerService.seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(positionMs),
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(trackDurationMs),
                                style: TextStyle(
                                  color: textColor.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Controls - FIXED: Direct access to hasPrevious/hasNext
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Shuffle
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            size: 28,
                            color: shuffleMode ? _accentColor : textColor.withOpacity(0.7),
                          ),
                          onPressed: () => _toggleShuffle(ref, context),
                        ),

                        // Previous - FIXED: Direct access to hasPrevious
                        IconButton(
                          icon: Icon(
                            Icons.skip_previous, 
                            size: 36, 
                            color: playerService.hasPrevious ? textColor : textColor.withOpacity(0.3),
                          ),
                          onPressed: playerService.hasPrevious ? () => _skipToPrevious(ref, context) : null,
                        ),

                        // Play/Pause
                        Container(
                          decoration: BoxDecoration(
                            color: _accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 36,
                              color: Colors.white,
                            ),
                            onPressed: () => _togglePlayPause(ref),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),

                        // Next - FIXED: Direct access to hasNext
                        IconButton(
                          icon: Icon(
                            Icons.skip_next, 
                            size: 36, 
                            color: playerService.hasNext ? textColor : textColor.withOpacity(0.3),
                          ),
                          onPressed: playerService.hasNext ? () => _skipToNext(ref, context) : null,
                        ),

                        // Repeat
                        IconButton(
                          icon: Icon(
                            _getRepeatButtonIcon(repeatMode),
                            size: 28,
                            color: _getRepeatButtonColor(repeatMode, isDarkMode, textColor),
                          ),
                          onPressed: () => _toggleRepeat(ref, context),
                        ),
                      ],
                    ),
                  ),

                  // Additional Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Like
                        IconButton(
                          icon: Icon(
                            currentTrack.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: currentTrack.isLiked ? _accentColor : textColor.withOpacity(0.7),
                          ),
                          onPressed: () async {
                            final newLiked = !currentTrack.isLiked;
                            // Update local state
                            final updatedTrack = Track(
                              id: currentTrack.id,
                              title: currentTrack.title,
                              artistName: currentTrack.artistName,
                              albumId: currentTrack.albumId,
                              storagePath: currentTrack.storagePath,
                              isLiked: newLiked,
                            );
                            ref.read(currentTrackProvider.notifier).state = updatedTrack;
                            
                            // Update DB
                            try {
                              await supabase.from('tracks').update({'is_liked': newLiked}).eq('id', currentTrack.id);
                            } catch (e) {
                              debugPrint('Error updating like: $e');
                              // Revert on error
                              final revertedTrack = Track(
                                id: currentTrack.id,
                                title: currentTrack.title,
                                artistName: currentTrack.artistName,
                                albumId: currentTrack.albumId,
                                storagePath: currentTrack.storagePath,
                                isLiked: !newLiked,
                              );
                              ref.read(currentTrackProvider.notifier).state = revertedTrack;
                            }
                          },
                        ),
                        
                        // Share
                        IconButton(
                          icon: Icon(Icons.share, color: textColor.withOpacity(0.7)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share functionality coming soon!')),
                            );
                          },
                        ),
                        
                        // Queue/Playlist
                        IconButton(
                          icon: Icon(Icons.queue_music, color: textColor.withOpacity(0.7)),
                          onPressed: () {
                            final playlistId = currentTrack.albumId;
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) => Container(
                                height: MediaQuery.of(context).size.height * 0.7,
                                child: Consumer(
                                  builder: (ctx, ref, child) {
                                    final tracksAsync = ref.watch(playlistTracksProvider(playlistId));
                                    return tracksAsync.when(
                                      data: (tracks) => ListView.builder(
                                        itemCount: tracks.length,
                                        itemBuilder: (c, i) {
                                          final track = tracks[i];
                                          return ListTile(
                                            title: Text(track.title),
                                            subtitle: Text(track.artist),
                                            selected: track.id == currentTrack.id,
                                            onTap: () {
                                              _playTrackFromDetails(track, ref, context);
                                              Navigator.pop(ctx);
                                            },
                                          );
                                        },
                                      ),
                                      loading: () => const Center(child: CircularProgressIndicator()),
                                      error: (e, s) => Center(child: Text('Error loading queue: $e')),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Devices
                        IconButton(
                          icon: Icon(Icons.devices_other, color: textColor.withOpacity(0.7)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device selection not available yet')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// GLOBAL SEARCH SCREEN
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  _GlobalSearchScreenState createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  void _playTrack(TrackDetails track) {
    final homeScreen = const HomeScreen();
    homeScreen._playTrackDetails(track, ref, context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const FullScreenPlayer()));
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final searchResults = ref.watch(searchResultsProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search for songs or artists...',
            hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
            border: InputBorder.none,
          ),
          style: TextStyle(color: textColor, fontSize: 18),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _searchController.clear(),
            ),
        ],
      ),
      body: searchResults.when(
        data: (tracks) {
          if (_searchQuery.isEmpty) {
            return _buildEmptySearchState(textColor);
          }
          if (tracks.isEmpty) {
            return _buildNoResultsState(textColor);
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return ListTile(
                leading: const Icon(Icons.music_note, color: _accentColor),
                title: Text(track.title, style: TextStyle(color: textColor)),
                subtitle: Text(track.artist, style: TextStyle(color: textColor.withOpacity(0.7))),
                onTap: () => _playTrack(track),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _accentColor)),
        error: (e, s) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: textColor.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'Find Your Favorite Music',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Search for songs, artists, and more.',
            style: TextStyle(color: textColor.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: textColor.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'No Results Found',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Try a different search term.',
            style: TextStyle(color: textColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}
// ADD SONG SCREEN - FIXED FOR YOUR TABLE STRUCTURE
class AddSongScreen extends ConsumerStatefulWidget {
  const AddSongScreen({super.key});

  @override
  _AddSongScreenState createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  String? _selectedPlaylistId;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _uploadSong() async {
    if (_titleController.text.isEmpty || _artistController.text.isEmpty || _selectedPlaylistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a playlist')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = '${const Uuid().v4()}_${file.name.replaceAll(' ', '_')}';
        
        print("📁 Selected file: ${file.name}");
        print("📁 File size: ${file.size} bytes");

        Uint8List? fileBytes;

        if (kIsWeb) {
          fileBytes = file.bytes;
          if (fileBytes == null) {
            throw Exception('No file bytes available');
          }
          print("🌐 Web platform - using file bytes");
        } else {
          if (file.path == null) {
            throw Exception('No file path available');
          }
          final fileToUpload = File(file.path!);
          fileBytes = await fileToUpload.readAsBytes();
        }

        print("⬆️ Uploading to Supabase storage...");

        // Upload without authentication
        final uploadResponse = await supabase.storage
            .from('audio_files')
            .uploadBinary(
              fileName, 
              fileBytes!,
              fileOptions: const FileOptions(
                contentType: 'audio/mpeg',
                upsert: false,
              ),
            );

        print("✅ File uploaded successfully");

        // Match your exact table structure - no duration_ms column
        final trackData = {
          'id': const Uuid().v4(),
          'title': _titleController.text.trim(),
          'artist': _artistController.text.trim(),
          'mp3_path': fileName, // Just the filename, not 'audio_files/filename'
          'album_id': _selectedPlaylistId,
          'is_liked': false,
          'created_at': DateTime.now().toIso8601String(),
          // Note: 'idx' is auto-generated by Supabase, don't include it
        };

        print("💾 Inserting track data: $trackData");

        final insertResponse = await supabase.from('tracks').insert(trackData);

        print("✅ Track inserted successfully");

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Song uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh providers
          ref.invalidate(playlistTracksProvider(_selectedPlaylistId!));
          ref.invalidate(homeContentProvider);
          
          Navigator.pop(context);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
      }
    } catch (e) {
      print("❌ Error uploading song: $e");
      
      String errorMessage = 'Error uploading song: $e';
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Song', style: TextStyle(color: textColor)),
        backgroundColor: isDarkMode ? _darkSurface : lightMode.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: playlistsAsync.when(
          data: (playlists) {
            if (playlists.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.playlist_add, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No playlists available',
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a playlist first',
                      style: TextStyle(color: textColor.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Song',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Song Title *',
                    labelStyle: TextStyle(color: textColor),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.grey : Colors.black54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _accentColor),
                    ),
                  ),
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _artistController,
                  decoration: InputDecoration(
                    labelText: 'Artist *',
                    labelStyle: TextStyle(color: textColor),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.grey : Colors.black54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _accentColor),
                    ),
                  ),
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Playlist *',
                    labelStyle: TextStyle(color: textColor),
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.grey : Colors.black54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _accentColor),
                    ),
                  ),
                  value: _selectedPlaylistId,
                  items: playlists
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.title, style: TextStyle(color: textColor)),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedPlaylistId = value),
                  dropdownColor: isDarkMode ? _mediumSurface : Colors.white,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadSong,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload),
                              SizedBox(width: 8),
                              Text('Pick and Upload Song', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading playlists: $e',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



// ENHANCED MUSIC DUMP SCREEN FOR BULK UPLOAD

// Define the DistributionMode enum outside the class
enum DistributionMode {
  random('Random Distribution'),
  selected('Selected Playlists'),
  single('Single Playlist');

  const DistributionMode(this.displayName);
  final String displayName;
}

class MusicDumpScreen extends ConsumerStatefulWidget {
  const MusicDumpScreen({super.key});

  @override
  _MusicDumpScreenState createState() => _MusicDumpScreenState();
}

class _MusicDumpScreenState extends ConsumerState<MusicDumpScreen> {
  bool _isUploading = false;
  int _uploadedCount = 0;
  int _totalCount = 0;
  List<String> _uploadLog = [];
  List<MockPlaylist> _availablePlaylists = [];
  List<String> _selectedPlaylistIds = [];
  DistributionMode _distributionMode = DistributionMode.random;
  bool _copyToMultiple = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final response = await supabase.from('playlists').select();
      if (response is List && response.isNotEmpty) {
        setState(() {
          _availablePlaylists = response.map((json) => MockPlaylist.fromJson(json)).toList();
        });
      }
      print("📚 Loaded ${_availablePlaylists.length} playlists");
    } catch (e) {
      debugPrint("Error loading playlists: $e");
    }
  }

  // Sanitize filename for Supabase storage
  String _sanitizeFileName(String originalName) {
    // Remove file extension first
    String nameWithoutExt = originalName.replaceAll(RegExp(r'\.(mp3|wav|m4a|flac|aac)$'), '');
    
    // Replace problematic characters with underscores
    String sanitized = nameWithoutExt
        .replaceAll(RegExp(r'[\[\](){},"!@#$%^&*+=|:;<>?/\\\s]'), '_')
        .replaceAll(RegExp(r'_+'), '_') // Replace multiple underscores with single
        .replaceAll(RegExp(r'^_|_$'), ''); // Remove leading/trailing underscores
    
    // Add .mp3 extension back
    return '$sanitized.mp3';
  }

  // Extract artist and title from filename
  Map<String, String> _parseFileName(String fileName) {
    // Remove file extension and sanitize first
    String nameWithoutExt = fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|flac|aac)$'), '');
    
    // Remove common YouTube/audio tags in brackets/parentheses
    nameWithoutExt = nameWithoutExt
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove [Official Audio], [THAISUB], etc.
        .replaceAll(RegExp(r'\(.*?\)'), '') // Remove (480p), (720p), etc.
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();
    
    // Common patterns for parsing artist - title
    final patterns = [
      RegExp(r'^(.*?)\s*[-\–]\s*(.*?)$'), // "Artist - Title" or "Artist – Title"
      RegExp(r'^(.*?)\s*_\s*(.*?)$'), // "Artist_Title"
      RegExp(r'^(.*?)\s*\|\s*(.*?)$'), // "Artist | Title"
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(nameWithoutExt);
      if (match != null) {
        String artist = match.group(1)!.trim();
        String title = match.group(2)!.trim();
        
        // Additional cleanup
        artist = artist.replaceAll(RegExp(r'[\[\]()]'), '').trim();
        title = title.replaceAll(RegExp(r'[\[\]()]'), '').trim();
        
        // If artist or title is empty after cleanup, use fallbacks
        if (artist.isEmpty) artist = 'Unknown Artist';
        if (title.isEmpty) title = 'Unknown Track';
        
        return {'artist': artist, 'title': title};
      }
    }

    // If no pattern matches, use filename as title and "Unknown Artist"
    final cleanName = nameWithoutExt.replaceAll(RegExp(r'[\[\]()]'), '').trim();
    return {
      'artist': 'Unknown Artist',
      'title': cleanName.isEmpty ? 'Unknown Track' : cleanName
    };
  }

  // Get random playlist ID
  String _getRandomPlaylistId() {
    if (_availablePlaylists.isEmpty) {
      throw Exception('No playlists available');
    }
    final random = Random();
    return _availablePlaylists[random.nextInt(_availablePlaylists.length)].id;
  }

  // Get multiple random playlist IDs (1-3 playlists per track)
  List<String> _getRandomPlaylistIds() {
    if (_availablePlaylists.isEmpty) {
      throw Exception('No playlists available');
    }
    final random = Random();
    final count = random.nextInt(3) + 1; // 1 to 3 playlists
    final shuffled = List.of(_availablePlaylists)..shuffle();
    return shuffled.take(count).map((playlist) => playlist.id).toList();
  }

  // Get playlist IDs based on distribution mode
  List<String> _getPlaylistIdsForTrack() {
    switch (_distributionMode) {
      case DistributionMode.random:
        return _copyToMultiple ? _getRandomPlaylistIds() : [_getRandomPlaylistId()];
      case DistributionMode.selected:
        if (_selectedPlaylistIds.isEmpty) {
          throw Exception('No playlists selected');
        }
        return _copyToMultiple ? _selectedPlaylistIds : [_selectedPlaylistIds[Random().nextInt(_selectedPlaylistIds.length)]];
      case DistributionMode.single:
        if (_selectedPlaylistIds.isEmpty) {
          throw Exception('No playlist selected');
        }
        return [_selectedPlaylistIds.first];
    }
  }

  Future<void> _uploadSingleTrack(PlatformFile file, List<String> playlistIds) async {
    try {
      final parsedInfo = _parseFileName(file.name);
      final artist = parsedInfo['artist']!;
      final title = parsedInfo['title']!;
      
      // Sanitize the filename for Supabase storage
      final String sanitizedFileName = _sanitizeFileName(file.name);
      final fileName = '${const Uuid().v4()}_$sanitizedFileName';
      
      print("🎵 Processing: $artist - $title");
      print("📁 Uploading file: $fileName");
      print("🎯 Target playlists: $playlistIds");

      Uint8List? fileBytes;

      if (kIsWeb) {
        fileBytes = file.bytes;
        if (fileBytes == null) {
          throw Exception('No file bytes available for ${file.name}');
        }
      } else {
        if (file.path == null) {
          throw Exception('No file path available for ${file.name}');
        }
        final fileToUpload = File(file.path!);
        fileBytes = await fileToUpload.readAsBytes();
      }

      // Upload to storage
      print("⬆️ Uploading to Supabase storage...");
      await supabase.storage
          .from('audio_files')
          .uploadBinary(
            fileName,
            fileBytes!,
            fileOptions: const FileOptions(
              contentType: 'audio/mpeg',
              upsert: false,
            ),
          );

      print("✅ File uploaded successfully");

      // Create track entries for each playlist
      for (final playlistId in playlistIds) {
        final trackId = const Uuid().v4();
        final trackData = {
          'id': trackId,
          'title': title,
          'artist': artist,
          'mp3_path': fileName,
          'album_id': playlistId,
          'is_liked': false,
          'created_at': DateTime.now().toIso8601String(),
        };

        print("💾 Inserting track: ${trackData['title']} into playlist: $playlistId");
        
        final insertResponse = await supabase.from('tracks').insert(trackData);
        print("✅ Track inserted with ID: $trackId");

        // Verify the track was actually inserted
        final verifyResponse = await supabase
            .from('tracks')
            .select()
            .eq('id', trackId)
            .single();
        
        if (verifyResponse != null) {
          print("🔍 Verification: Track found in database");
        } else {
          print("❌ Verification: Track NOT found in database");
        }
      }

      setState(() {
        _uploadedCount++;
        final playlistNames = playlistIds.map((id) {
          final playlist = _availablePlaylists.firstWhere((p) => p.id == id, orElse: () => MockPlaylist(id, 'Unknown', ''));
          return playlist.title;
        }).toList();
        _uploadLog.add('✅ $artist - $title → ${playlistNames.join(", ")}');
      });

    } catch (e) {
      print("❌ Error uploading track: $e");
      setState(() {
        _uploadLog.add('❌ ${file.name}: $e');
      });
      rethrow;
    }
  }

  Future<void> _startBulkUpload() async {
    if (_availablePlaylists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlists available. Create a playlist first.')),
      );
      return;
    }

    if ((_distributionMode == DistributionMode.selected || _distributionMode == DistributionMode.single) && 
        _selectedPlaylistIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one playlist')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _totalCount = result.files.length;
      _uploadLog.clear();
    });

    try {
      for (final file in result.files) {
        try {
          final playlistIds = _getPlaylistIdsForTrack();
          await _uploadSingleTrack(file, playlistIds);
          
          // Small delay to prevent overwhelming the server
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          debugPrint("Error uploading ${file.name}: $e");
          // Continue with next file even if one fails
        }
      }

      // Force refresh all providers with more aggressive invalidation
      print("🔄 Refreshing providers...");
      ref.invalidate(homeContentProvider);
      ref.invalidate(favoriteTracksProvider);
      ref.invalidate(playlistsProvider);
      
      // Invalidate all playlist track providers
      for (final playlist in _availablePlaylists) {
        ref.invalidate(playlistTracksProvider(playlist.id));
      }

      // Force a rebuild of the home screen
      Future.delayed(const Duration(seconds: 1), () {
        ref.invalidate(homeContentProvider);
        ref.invalidate(playlistsProvider);
      });

      if (mounted) {
        _showUploadSummary();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload completed with some errors. $_uploadedCount/$_totalCount files processed'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showUploadSummary() {
    final uploadedPlaylists = <String, int>{};
    
    for (final log in _uploadLog) {
      if (log.contains('→')) {
        final parts = log.split('→');
        if (parts.length > 1) {
          final playlistNames = parts[1].trim().split(', ');
          for (final name in playlistNames) {
            uploadedPlaylists[name] = (uploadedPlaylists[name] ?? 0) + 1;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Complete!'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Successfully uploaded $_uploadedCount/$_totalCount files'),
              const SizedBox(height: 16),
              if (uploadedPlaylists.isNotEmpty) ...[
                const Text(
                  'Songs distributed to:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...uploadedPlaylists.entries.map((entry) => 
                  Text('• ${entry.key}: ${entry.value} songs')
                ).toList(),
              ],
              const SizedBox(height: 16),
              Text(
                'Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              _buildNavigationOption('Check Console', Icons.bug_report, 'Look for debug logs in console'),
              _buildNavigationOption('Refresh App', Icons.refresh, 'Pull down to refresh playlists'),
              _buildNavigationOption('Verify Database', Icons.storage, 'Check Supabase table directly'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to home screen and force refresh
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Go Home & Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationOption(String title, IconData icon, String description) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Music Upload'),
        backgroundColor: isDarkMode ? _darkSurface : lightMode.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info - Fixed height section
            Card(
              color: isDarkMode ? _mediumSurface : Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_upload, size: 40, color: _accentColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bulk Music Upload',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Upload multiple songs at once',
                                style: TextStyle(color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Features:',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem('🎵 Auto-detect artist & title from filename', subtitleColor),
                    _buildFeatureItem('📚 Multiple distribution modes', subtitleColor),
                    _buildFeatureItem('⚡ Batch processing', subtitleColor),
                    _buildFeatureItem('📊 Progress tracking & summary', subtitleColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Scrollable content section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distribution Settings
                    Text(
                      'Distribution Settings',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Distribution Mode
                    DropdownButtonFormField<DistributionMode>(
                      value: _distributionMode,
                      decoration: InputDecoration(
                        labelText: 'Distribution Mode',
                        labelStyle: TextStyle(color: textColor),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: isDarkMode ? _mediumSurface.withOpacity(0.5) : Colors.grey[100],
                      ),
                      items: DistributionMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode.displayName, style: TextStyle(color: textColor)),
                        );
                      }).toList(),
                      onChanged: _isUploading ? null : (value) {
                        setState(() {
                          _distributionMode = value!;
                          if (_distributionMode == DistributionMode.single && _selectedPlaylistIds.length > 1) {
                            _selectedPlaylistIds = [_selectedPlaylistIds.first];
                          }
                        });
                      },
                      dropdownColor: isDarkMode ? _mediumSurface : Colors.white,
                    ),

                    const SizedBox(height: 12),

                    // Copy to Multiple Option
                    if (_distributionMode != DistributionMode.single)
                      SwitchListTile(
                        title: Text(
                          'Copy to Multiple Playlists',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        subtitle: Text(
                          _distributionMode == DistributionMode.random 
                              ? 'Each song will be added to 1-3 random playlists'
                              : 'Each song will be added to all selected playlists',
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                        ),
                        value: _copyToMultiple,
                        onChanged: _isUploading ? null : (value) {
                          setState(() {
                            _copyToMultiple = value!;
                          });
                        },
                        activeColor: _accentColor,
                        contentPadding: EdgeInsets.zero,
                      ),

                    const SizedBox(height: 16),

                    // Playlist Selection
                    if (_distributionMode != DistributionMode.random) ...[
                      Text(
                        'Select Playlists:',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPlaylistSelection(),
                      const SizedBox(height: 8),
                    ],

                    // Playlist Info
                    Text(
                      'Available Playlists: ${_availablePlaylists.length}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPlaylistChips(),

                    const SizedBox(height: 20),

                    // Upload Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _startBulkUpload,
                        icon: _isUploading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload),
                        label: _isUploading
                            ? Text('Uploading... ($_uploadedCount/$_totalCount)')
                            : const Text('Select Multiple Music Files'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Progress and Log
                    if (_isUploading || _uploadLog.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'Upload Log:',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (_uploadLog.isNotEmpty)
                            TextButton(
                              onPressed: _isUploading ? null : () => setState(() => _uploadLog.clear()),
                              child: const Text('Clear Log'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200, // Fixed height for log container
                        decoration: BoxDecoration(
                          color: isDarkMode ? _mediumSurface : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
                        ),
                        child: _uploadLog.isEmpty
                            ? Center(
                                child: Text(
                                  'No uploads yet',
                                  style: TextStyle(color: subtitleColor),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _uploadLog.length,
                                itemBuilder: (context, index) {
                                  final log = _uploadLog[index];
                                  final isError = log.startsWith('❌');
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: index < _uploadLog.length - 1
                                          ? Border(
                                              bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.black12),
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isError ? Icons.error_outline : Icons.check_circle,
                                          color: isError ? Colors.orange : Colors.green,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            log,
                                            style: TextStyle(
                                              color: isError ? Colors.orange : textColor,
                                              fontSize: 12,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ] else ...[
                      // Empty state illustration
                      Container(
                        height: 150,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_note, size: 60, color: textColor.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No uploads yet',
                              style: TextStyle(color: subtitleColor, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select multiple music files to start bulk upload',
                              style: TextStyle(color: subtitleColor, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSelection() {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: isDarkMode ? Colors.white24 : Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _availablePlaylists.length,
        itemBuilder: (context, index) {
          final playlist = _availablePlaylists[index];
          final isSelected = _selectedPlaylistIds.contains(playlist.id);
          
          return CheckboxListTile(
            title: Text(playlist.title, style: TextStyle(color: textColor, fontSize: 14)),
            value: isSelected,
            onChanged: _isUploading ? null : (value) {
              setState(() {
                if (value!) {
                  if (_distributionMode == DistributionMode.single) {
                    _selectedPlaylistIds = [playlist.id];
                  } else {
                    _selectedPlaylistIds.add(playlist.id);
                  }
                } else {
                  _selectedPlaylistIds.remove(playlist.id);
                }
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            activeColor: _accentColor,
          );
        },
      ),
    );
  }

  Widget _buildPlaylistChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _availablePlaylists.take(6).map((playlist) {
        final isSelected = _selectedPlaylistIds.contains(playlist.id);
        return Chip(
          label: Text(
            playlist.title,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : null,
            ),
          ),
          backgroundColor: isSelected 
              ? _accentColor 
              : _accentColor.withOpacity(0.2),
          onDeleted: _distributionMode == DistributionMode.random || _isUploading ? null : () {
            setState(() {
              _selectedPlaylistIds.remove(playlist.id);
            });
          },
          deleteIcon: const Icon(Icons.close, size: 16),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text('• ', style: TextStyle(color: color)),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 14))),
        ],
      ),
    );
  }
}