import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as console;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlaybackService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentTempFilePath;

  // Callback functions
  Function()? onPlaybackComplete;
  Function(String)? onPlaybackError;
  Function()? onPlaybackStart;

  /// Initialize the audio playback service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      console.log('Initializing AudioPlaybackService...');

      // Set up event listeners
      _audioPlayer.onPlayerComplete.listen((_) {
        console.log('Audio playback completed');
        _isPlaying = false;
        _cleanupTempFile();
        onPlaybackComplete?.call();
      });

      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        console.log('Audio player state changed: $state');
        _isPlaying = state == PlayerState.playing;

        if (state == PlayerState.playing) {
          onPlaybackStart?.call();
        }
      });

      _audioPlayer.onDurationChanged.listen((Duration duration) {
        console.log('Audio duration: ${duration.inSeconds} seconds');
      });

      _audioPlayer.onPositionChanged.listen((Duration position) {
        // Uncomment for detailed position tracking
        // console.log('Audio position: ${position.inSeconds}s');
      });

      _isInitialized = true;
      console.log('AudioPlaybackService initialized successfully');
      return true;
    } catch (e) {
      console.log('Error initializing AudioPlaybackService: $e');
      return false;
    }
  }

  /// Play audio from a list of bytes
  /// [audioBytes] - The audio data as a list of integers
  /// [fileExtension] - The file extension/format (mp3, wav, m4a, etc.)
  /// Returns true if playback started successfully
  Future<bool> playAudioBytes(
    List<int> audioBytes, {
    String fileExtension = 'mp3',
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        console.log('Failed to initialize audio playback service');
        return false;
      }
    }

    if (audioBytes.isEmpty) {
      console.log('Error: Audio bytes are empty');
      onPlaybackError?.call('Audio bytes are empty');
      return false;
    }

    try {
      console.log('Starting audio playback from ${audioBytes.length} bytes');

      // Stop any current playback
      await stop();

      // Create temporary file
      final tempFile = await _createTempAudioFile(audioBytes, fileExtension);
      if (tempFile == null) {
        console.log('Failed to create temporary audio file');
        onPlaybackError?.call('Failed to create temporary audio file');
        return false;
      }

      _currentTempFilePath = tempFile.path;
      console.log('Created temporary audio file: ${tempFile.path}');

      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(tempFile.path));

      console.log('Audio playback started successfully');
      return true;
    } catch (e) {
      console.log('Error playing audio bytes: $e');
      onPlaybackError?.call(e.toString());
      return false;
    }
  }

  /// Play audio from a file path
  /// [filePath] - Path to the audio file
  /// Returns true if playback started successfully
  Future<bool> playAudioFile(String filePath) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        console.log('Failed to initialize audio playback service');
        return false;
      }
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        console.log('Audio file does not exist: $filePath');
        onPlaybackError?.call('Audio file does not exist');
        return false;
      }

      console.log('Playing audio file: $filePath');

      // Stop any current playback
      await stop();

      // Play the audio file
      await _audioPlayer.play(DeviceFileSource(filePath));

      console.log('Audio file playback started successfully');
      return true;
    } catch (e) {
      console.log('Error playing audio file: $e');
      onPlaybackError?.call(e.toString());
      return false;
    }
  }

  /// Stop audio playback
  Future<void> stop() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        console.log('Audio playback stopped');
      }
      _isPlaying = false;
      _cleanupTempFile();
    } catch (e) {
      console.log('Error stopping audio playback: $e');
    }
  }

  /// Pause audio playback
  Future<void> pause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        console.log('Audio playback paused');
      }
    } catch (e) {
      console.log('Error pausing audio playback: $e');
    }
  }

  /// Resume audio playback
  Future<void> resume() async {
    try {
      await _audioPlayer.resume();
      console.log('Audio playback resumed');
    } catch (e) {
      console.log('Error resuming audio playback: $e');
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(clampedVolume);
      console.log('Audio volume set to: $clampedVolume');
    } catch (e) {
      console.log('Error setting volume: $e');
    }
  }

  /// Get current playback position
  Future<Duration?> getCurrentPosition() async {
    try {
      return await _audioPlayer.getCurrentPosition();
    } catch (e) {
      console.log('Error getting current position: $e');
      return null;
    }
  }

  /// Get audio duration
  Future<Duration?> getDuration() async {
    try {
      return await _audioPlayer.getDuration();
    } catch (e) {
      console.log('Error getting duration: $e');
      return null;
    }
  }

  /// Create a temporary audio file from bytes
  Future<File?> _createTempAudioFile(
    List<int> audioBytes,
    String fileExtension,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'audio_playback_$timestamp.$fileExtension';
      final tempFile = File('${tempDir.path}/$fileName');

      // Write bytes to file
      await tempFile.writeAsBytes(Uint8List.fromList(audioBytes));

      console.log('Created temp audio file: ${tempFile.path}');
      console.log('File size: ${await tempFile.length()} bytes');

      return tempFile;
    } catch (e) {
      console.log('Error creating temporary audio file: $e');
      return null;
    }
  }

  /// Clean up temporary files
  void _cleanupTempFile() {
    if (_currentTempFilePath != null) {
      try {
        final file = File(_currentTempFilePath!);
        if (file.existsSync()) {
          file.deleteSync();
          console.log('Cleaned up temporary file: $_currentTempFilePath');
        }
      } catch (e) {
        console.log('Error cleaning up temporary file: $e');
      } finally {
        _currentTempFilePath = null;
      }
    }
  }

  /// Check if audio is currently playing
  bool get isPlaying => _isPlaying;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of the service and clean up resources
  Future<void> dispose() async {
    try {
      await stop();
      _cleanupTempFile();
      await _audioPlayer.dispose();
      _isInitialized = false;
      console.log('AudioPlaybackService disposed');
    } catch (e) {
      console.log('Error disposing AudioPlaybackService: $e');
    }
  }
}
