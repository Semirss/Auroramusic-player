import 'package:audio_service/audio_service.dart';
import 'package:ss_musicplayer/src/core/image_service.dart';

class Track {
  final String id;
  final String title;
  final String artistName;
  final String albumId;
  final String storagePath;
  final bool isLiked;
  final DateTime? createdAt;

  Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.albumId,
    required this.storagePath,
    required this.isLiked,
    this.createdAt,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artistName: json['artist'] as String,
      albumId: json['album_id'] as String,
      storagePath: json['mp3_path'] as String,
      isLiked: (json['is_liked'] as bool?) ?? false,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return null;
    if (dateTimeValue is DateTime) return dateTimeValue;
    if (dateTimeValue is String) {
      try {
        return DateTime.parse(dateTimeValue);
      } catch (e) {
        print("Error parsing date string: $dateTimeValue, error: $e");
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artistName,
      'album_id': albumId,
      'mp3_path': storagePath,
      'is_liked': isLiked,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  MediaItem toMediaItem() {
    final coverUrl = ImageService.getCoverUrlWithFallbacks(
      albumId: albumId,
      artistName: artistName,
    );

    return MediaItem(
      id: id,
      title: title,
      artist: artistName,
      album: albumId,
      duration: const Duration(minutes: 3), // Default duration since you don't have duration_ms
      artUri: coverUrl.isNotEmpty ? Uri.parse(coverUrl) : null,
      extras: {'track': this},
    );
  }
}