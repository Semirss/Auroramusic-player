import 'package:ss_musicplayer/src/core/supabase_client.dart';

class ImageService {
  static final _supabaseService = SupabaseService();

  /// Get album cover URL
  static String getAlbumCoverUrl(String? albumId) {
    if (albumId == null || albumId.isEmpty) {
      return getDefaultCoverUrl();
    }
    
    try {
      return _supabaseService.client.storage
          .from('covers')
          .getPublicUrl('albums/$albumId.jpg');
    } catch (e) {
      print('Error getting album cover URL for $albumId: $e');
      return getDefaultCoverUrl();
    }
  }

  /// Get artist image URL
  static String getArtistImageUrl(String? artistName) {
    if (artistName == null || artistName.isEmpty) {
      return getDefaultArtistUrl();
    }
    
    try {
      final formattedName = _formatArtistName(artistName);
      return _supabaseService.client.storage
          .from('covers')
          .getPublicUrl('artists/$formattedName.jpg');
    } catch (e) {
      print('Error getting artist image URL for $artistName: $e');
      return getDefaultArtistUrl();
    }
  }

  /// Get track cover URL - uses album cover as fallback
  static String getTrackCoverUrl(String? trackCoverPath, {String? albumId}) {
    // First try the specific track cover path
    if (trackCoverPath != null && trackCoverPath.isNotEmpty) {
      try {
        return _supabaseService.client.storage
            .from('covers')
            .getPublicUrl(trackCoverPath);
      } catch (e) {
        print('Error getting track cover URL for $trackCoverPath: $e');
      }
    }
    
    // Fallback to album cover
    if (albumId != null && albumId.isNotEmpty) {
      return getAlbumCoverUrl(albumId);
    }
    
    // Final fallback to default
    return getDefaultCoverUrl();
  }

  /// Get playlist cover URL
  static String getPlaylistCoverUrl(String playlistId) {
    try {
      return _supabaseService.client.storage
          .from('covers')
          .getPublicUrl('playlists/$playlistId.jpg');
    } catch (e) {
      print('Error getting playlist cover URL for $playlistId: $e');
      return getDefaultCoverUrl();
    }
  }

  /// Get user avatar URL
  static String getUserAvatarUrl(String userId) {
    try {
      return _supabaseService.client.storage
          .from('covers')
          .getPublicUrl('avatars/$userId.jpg');
    } catch (e) {
      print('Error getting user avatar URL for $userId: $e');
      return getDefaultAvatarUrl();
    }
  }

  /// Format artist name for file system (lowercase, underscores)
  static String _formatArtistName(String artistName) {
    return artistName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters
        .replaceAll(RegExp(r'[\s-]+'), '_')  // Replace spaces and hyphens with underscores
        .trim();
  }

  /// Default cover image
  static String getDefaultCoverUrl() {
    return _supabaseService.client.storage
        .from('covers')
        .getPublicUrl('defaults/default_cover.jpg');
  }

  /// Default artist image
  static String getDefaultArtistUrl() {
    return _supabaseService.client.storage
        .from('covers')
        .getPublicUrl('defaults/default_artist.jpg');
  }

  /// Default avatar image
  static String getDefaultAvatarUrl() {
    return _supabaseService.client.storage
        .from('covers')
        .getPublicUrl('defaults/default_avatar.jpg');
  }

  /// Get cover URL with multiple fallback options
  static String getCoverUrlWithFallbacks({
    String? specificCoverPath,
    String? albumId,
    String? artistName,
    String? playlistId,
  }) {
    // Priority 1: Specific cover path
    if (specificCoverPath != null && specificCoverPath.isNotEmpty) {
      final url = getTrackCoverUrl(specificCoverPath);
      if (url.isNotEmpty && !url.contains('defaults/')) {
        return url;
      }
    }

    // Priority 2: Album cover
    if (albumId != null && albumId.isNotEmpty) {
      final url = getAlbumCoverUrl(albumId);
      if (url.isNotEmpty && !url.contains('defaults/')) {
        return url;
      }
    }

    // Priority 3: Playlist cover
    if (playlistId != null && playlistId.isNotEmpty) {
      final url = getPlaylistCoverUrl(playlistId);
      if (url.isNotEmpty && !url.contains('defaults/')) {
        return url;
      }
    }

    // Priority 4: Artist image
    if (artistName != null && artistName.isNotEmpty) {
      final url = getArtistImageUrl(artistName);
      if (url.isNotEmpty && !url.contains('defaults/')) {
        return url;
      }
    }

    // Final fallback: Default cover
    return getDefaultCoverUrl();
  }

  /// Get random cover URL for new playlists
  static String getRandomCoverUrl() {
    final random = DateTime.now().millisecondsSinceEpoch % 10;
    return _supabaseService.client.storage
        .from('covers')
        .getPublicUrl('defaults/playlist_$random.jpg');
  }
}