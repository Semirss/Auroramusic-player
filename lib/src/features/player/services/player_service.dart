import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ss_musicplayer/src/core/supabase_client.dart';
import 'package:ss_musicplayer/src/features/player/models/track.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
final playerServiceProvider = Provider<PlayerService>((ref) {
  final service = PlayerService();
  return service;
});

final tracksProvider = StreamProvider<List<Track>>((ref) {
  final playerService = ref.watch(playerServiceProvider);
  return playerService.getTracks();
});

final currentTrackProvider = StateProvider<Track?>((ref) => null);
final isPlayingProvider = StateProvider<bool>((ref) => false);
final currentPositionProvider = StreamProvider.autoDispose<int>((ref) {
  final playerService = ref.watch(playerServiceProvider);
  return playerService.positionStream.map((duration) => duration.inMilliseconds);
});

// Add these missing providers
enum RepeatMode { off, one, all }
final repeatModeProvider = StateProvider<RepeatMode>((ref) => RepeatMode.off);
final shuffleModeProvider = StateProvider<bool>((ref) => false);

class PlayerService extends BaseAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  final supabase = SupabaseService().client;
  final List<Track> _currentTracks = [];
  int _currentIndex = -1;

  PlayerService() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _initializeAudio();

    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      print("🎵 Player state: ${state.processingState}, playing: ${_player.playing}");
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      print("⏱️ Position: $position");
    });

    // Listen to current index changes - FIXED: This is crucial for tracking queue position
    _player.currentIndexStream.listen((index) {
      print("📊 Current index: $index, Total tracks: ${_currentTracks.length}");
      if (index != null && index < _currentTracks.length) {
        _currentIndex = index;
        final track = _currentTracks[index];
        print("🎶 Now playing: ${track.title} (index: $index)");
        
        // Update media item for audio service
        mediaItem.add(track.toMediaItem());
        
        // Print queue info for debugging
        print("📋 Queue status - HasPrevious: $hasPrevious, HasNext: $hasNext");
        print("📋 Queue indices: 0 to ${_currentTracks.length - 1}, Current: $_currentIndex");
      } else if (index == null) {
        _currentIndex = -1;
        print("📊 No current index - queue might be empty");
      }
    });

    // Listen to completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        print("✅ Track completed");
      }
    });
  }

  Future<void> _initializeAudio() async {
    try {
      await _player.setAudioSource(_playlist);
      print("✅ Audio player initialized successfully");
    } catch (e) {
      print("❌ Error initializing audio source: $e");
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    try {
      final track = mediaItem.extras?['track'] as Track?;
      if (track == null) {
        throw Exception('Track not found in media item extras');
      }

      final publicUrl = _getSupabaseUrl(track.storagePath);
      if (publicUrl == null) {
        throw Exception('Failed to generate URL for ${track.title}');
      }

      print("🎵 Streaming from: $publicUrl");

      final audioSource = AudioSource.uri(
        Uri.parse(publicUrl),
        tag: mediaItem,
      );

      await _playlist.add(audioSource);
      _currentTracks.add(track);
      
      // Update queue
      queue.add(_currentTracks.map((t) => t.toMediaItem()).toList());
      
      print("✅ Added track to playlist: ${track.title}");
      print("📋 Total tracks in queue: ${_currentTracks.length}");

    } catch (e) {
      print("❌ Error adding queue item: $e");
      rethrow;
    }
  }

  // NEW: Play track at specific index - FIXED: Better index handling
  Future<void> playTrackAtIndex(int index) async {
    try {
      if (index >= 0 && index < _currentTracks.length) {
        print("🎯 Attempting to play track at index: $index");
        
        // First ensure we're at the beginning of the track
        await _player.seek(Duration.zero, index: index);
        
        // Small delay to ensure seek completes
        await Future.delayed(const Duration(milliseconds: 100));
        
        await play();
        _currentIndex = index;
        
        // Update current media item
        final track = _currentTracks[index];
        mediaItem.add(track.toMediaItem());
        
        print("🎯 Now playing track at index: $index - ${track.title}");
        print("📋 Queue status - HasPrevious: $hasPrevious, HasNext: $hasNext");
      } else {
        print("❌ Invalid index: $index, queue length: ${_currentTracks.length}");
      }
    } catch (e) {
      print("❌ Error playing track at index $index: $e");
      rethrow;
    }
  }

  String? _getSupabaseUrl(String storagePath) {
    try {
      // Handle both full paths and just filenames
      String fileName = storagePath;
      if (storagePath.contains('/')) {
        fileName = storagePath.split('/').last;
      }
      
      final publicUrl = supabase.storage.from('audio_files').getPublicUrl(fileName);
      print("🔗 Generated URL for $fileName: $publicUrl");
      return publicUrl;
    } catch (e) {
      print("❌ Failed to get Supabase URL for $storagePath: $e");
      return null;
    }
  }

  // Add multiple tracks to queue - FIXED: Better queue initialization
  Future<void> addTracksToQueue(List<Track> tracks) async {
    try {
      print("📥 Adding ${tracks.length} tracks to queue");
      await clearQueue();
      
      for (int i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        final mediaItem = track.toMediaItem();
        final publicUrl = _getSupabaseUrl(track.storagePath);
        
        if (publicUrl != null) {
          final audioSource = AudioSource.uri(
            Uri.parse(publicUrl),
            tag: mediaItem,
          );
          
          await _playlist.add(audioSource);
          _currentTracks.add(track);
          print("➕ Added track $i: ${track.title}");
        }
      }
      
      _currentIndex = 0;
      
      // Update queue and media item
      queue.add(_currentTracks.map((t) => t.toMediaItem()).toList());
      
      if (_currentTracks.isNotEmpty) {
        mediaItem.add(_currentTracks.first.toMediaItem());
      }
      
      print("✅ Added ${tracks.length} tracks to queue");
      print("📋 Final queue length: ${_currentTracks.length}");
      print("🎯 Current index set to: $_currentIndex");
      
    } catch (e) {
      print("❌ Error adding tracks to queue: $e");
      rethrow;
    }
  }

  Stream<List<Track>> getTracks() {
    try {
      return supabase
          .from('tracks')
          .stream(primaryKey: ['id'])
          .map((list) {
            list.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
            final tracks = list.map((json) => Track.fromJson(json)).toList();
            print("📥 Loaded ${tracks.length} tracks from Supabase");
            return tracks;
          })
          .handleError((error) {
            print("❌ Error in getTracks: $error");
            return [];
          });
    } catch (e) {
      print("❌ Error setting up tracks stream: $e");
      return Stream.value([]);
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
      print("▶️ Play command executed");
    } catch (e) {
      print("❌ Error playing: $e");
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      print("⏸️ Pause command executed");
    } catch (e) {
      print("❌ Error pausing: $e");
      rethrow;
    }
  }

  // FIXED: Simple play/pause toggle
  Future<void> playPause() async {
    try {
      if (_player.playing) {
        await pause();
      } else {
        await play();
      }
    } catch (e) {
      print("❌ Error in playPause: $e");
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      print("🔍 Seek to $position");
    } catch (e) {
      print("❌ Error seeking: $e");
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      print("⏹️ Stop command executed");
    } catch (e) {
      print("❌ Error stopping: $e");
      rethrow;
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      print("⏭️ Attempting skip to next - HasNext: $hasNext, CurrentIndex: $_currentIndex");
      if (hasNext) {
        await _player.seekToNext();
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay
        await play();
        print("⏭️ Skip to next completed");
        
        // The currentIndexStream listener will handle the track update
      } else {
        print("ℹ️ No next track available");
      }
    } catch (e) {
      print("❌ Error skipping to next: $e");
      rethrow;
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      print("⏮️ Attempting skip to previous - HasPrevious: $hasPrevious, CurrentIndex: $_currentIndex");
      if (hasPrevious) {
        await _player.seekToPrevious();
        await Future.delayed(const Duration(milliseconds: 50)); // Small delay
        await play();
        print("⏮️ Skip to previous completed");
        
        // The currentIndexStream listener will handle the track update
      } else {
        print("ℹ️ No previous track available");
      }
    } catch (e) {
      print("❌ Error skipping to previous: $e");
      rethrow;
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    try {
      if (index >= 0 && index < _currentTracks.length) {
        await _playlist.removeAt(index);
        _currentTracks.removeAt(index);
        
        // Update queue
        queue.add(_currentTracks.map((t) => t.toMediaItem()).toList());
        
        print("🗑️ Removed track at index $index");
      }
    } catch (e) {
      print("❌ Error removing queue item: $e");
      rethrow;
    }
  }

  Future<void> clearQueue() async {
    try {
      await _playlist.clear();
      _currentTracks.clear();
      _currentIndex = -1;
      
      // Clear queue and media item
      queue.value = [];
      mediaItem.add(null);
      
      print("🧹 Queue cleared");
    } catch (e) {
      print("❌ Error clearing queue: $e");
      rethrow;
    }
  }

  Track? getCurrentTrack() {
    try {
      if (_currentIndex >= 0 && _currentIndex < _currentTracks.length) {
        return _currentTracks[_currentIndex];
      }
      return null;
    } catch (e) {
      print("❌ Error getting current track: $e");
      return null;
    }
  }

  List<Track> getQueueTracks() {
    return List.from(_currentTracks); // Return a copy to prevent external modification
  }

  // FIXED: Getter properties with better debugging
  bool get isPlaying => _player.playing;
  
  bool get hasNext {
    final hasNext = _player.hasNext;
    print("🔍 hasNext check: $hasNext (currentIndex: $_currentIndex, total: ${_currentTracks.length})");
    return hasNext;
  }
  
  bool get hasPrevious {
    final hasPrevious = _player.hasPrevious;
    print("🔍 hasPrevious check: $hasPrevious (currentIndex: $_currentIndex, total: ${_currentTracks.length})");
    return hasPrevious;
  }

  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      print("🔊 Volume set to ${(volume * 100).round()}%");
    } catch (e) {
      print("❌ Error setting volume: $e");
    }
  }

  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed.clamp(0.5, 2.0));
      print("⚡ Speed set to ${speed}x");
    } catch (e) {
      print("❌ Error setting speed: $e");
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  Future<void> cleanup() async {
    print("🔌 Cleaning up PlayerService...");
    await _player.dispose();
  }
}