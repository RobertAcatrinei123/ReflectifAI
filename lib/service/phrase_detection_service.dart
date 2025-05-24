import 'dart:async';
import 'dart:developer' as console;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:reflectifai/service/elevenlabs.dart';

typedef PhraseDetectedCallback =
    void Function(String detectedPhrase, String fullTranscript);
typedef AudioProcessingCallback = void Function(String audioPath, int fileSize);
typedef TranscriptionCallback =
    void Function(String transcript, bool isSuccess);

class PhraseDetectionService {
  final AudioRecorder _recorder = AudioRecorder();
  final ElevenlabsService _transcriptionService = ElevenlabsService();

  // Configuration
  static const Duration _recordingDuration = Duration(seconds: 2);
  static const Duration _pauseBetweenRecordings = Duration(milliseconds: 250);

  // State management
  bool _isRunning = false;
  bool _isInitialized = false;
  String? _tempAudioPath;
  Timer? _recordingTimer;

  // Phrase detection settings
  final Set<String> _watchedPhrases = <String>{};
  final List<PhraseDetectedCallback> _callbacks = [];
  final List<AudioProcessingCallback> _audioProcessingCallbacks = [];
  final List<TranscriptionCallback> _transcriptionCallbacks = [];

  // Similarity threshold for phrase matching (0.0 to 1.0)
  double _similarityThreshold = 0.8;

  // Debug mode for testing
  bool _debugMode = true; // Enable debug mode by default for testing

  /// Initialize the service and request necessary permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        console.log('Microphone permission not granted');
        return false;
      }

      // Request storage permission for temporary files
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.request();
        if (storageStatus != PermissionStatus.granted) {
          console.log('Storage permission not granted, continuing anyway');
        }
      }

      // Check if recorder has permission
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        console.log('Audio recorder does not have permission');
        return false;
      }

      // Set up temporary audio file path
      final tempDir = await getTemporaryDirectory();
      _tempAudioPath = '${tempDir.path}/phrase_detection_audio.m4a';

      _isInitialized = true;
      console.log('Phrase detection service initialized successfully');
      return true;
    } catch (e) {
      console.log('Error initializing phrase detection service: $e');
      return false;
    }
  }

  /// Add a phrase to watch for
  void addWatchedPhrase(String phrase) {
    _watchedPhrases.add(phrase.toLowerCase().trim());
    console.log('Added watched phrase: "$phrase"');
  }

  /// Remove a phrase from the watch list
  void removeWatchedPhrase(String phrase) {
    _watchedPhrases.remove(phrase.toLowerCase().trim());
    console.log('Removed watched phrase: "$phrase"');
  }

  /// Set the similarity threshold for phrase matching
  void setSimilarityThreshold(double threshold) {
    _similarityThreshold = threshold.clamp(0.0, 1.0);
  }

  /// Add a callback function to be called when a phrase is detected
  void addPhraseDetectedCallback(PhraseDetectedCallback callback) {
    _callbacks.add(callback);
  }

  /// Remove a callback function
  void removePhraseDetectedCallback(PhraseDetectedCallback callback) {
    _callbacks.remove(callback);
  }

  /// Add a callback function to be called when audio is processed
  void addAudioProcessingCallback(AudioProcessingCallback callback) {
    _audioProcessingCallbacks.add(callback);
  }

  /// Add a callback function to be called when transcription completes
  void addTranscriptionCallback(TranscriptionCallback callback) {
    _transcriptionCallbacks.add(callback);
  }

  /// Start the background phrase detection
  Future<bool> startDetection() async {
    if (_isRunning) {
      console.log('Phrase detection already running');
      return true;
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        console.log('Failed to initialize phrase detection service');
        return false;
      }
    }

    if (_watchedPhrases.isEmpty) {
      console.log(
        'No phrases to watch for. Add phrases before starting detection.',
      );
      return false;
    }

    _isRunning = true;
    console.log('Starting background phrase detection');

    // Start the continuous recording loop
    _startRecordingLoop();

    return true;
  }

  /// Stop the background phrase detection
  Future<void> stopDetection() async {
    if (!_isRunning) return;

    _isRunning = false;
    _recordingTimer?.cancel();

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      console.log('Error stopping recorder: $e');
    }

    console.log('Stopped background phrase detection');
  }

  /// Main recording loop that runs continuously in the background
  void _startRecordingLoop() {
    if (!_isRunning) {
      console.log('Recording loop stopped - service not running');
      return;
    }

    console.log('Starting recording loop iteration');

    _recordSingleChunk()
        .then((_) {
          if (_isRunning) {
            console.log(
              'Recording chunk completed, scheduling next in ${_pauseBetweenRecordings.inMilliseconds}ms',
            );
            // Schedule next recording after a brief pause
            _recordingTimer = Timer(
              _pauseBetweenRecordings,
              _startRecordingLoop,
            );
          } else {
            console.log('Recording loop stopped - service no longer running');
          }
        })
        .catchError((error) {
          console.log('Error in recording loop: $error');
          if (_isRunning) {
            console.log('Continuing loop after error with 2 second delay');
            // Continue the loop even after errors, with a longer delay
            _recordingTimer = Timer(
              const Duration(seconds: 2),
              _startRecordingLoop,
            );
          } else {
            console.log(
              'Recording loop stopped after error - service no longer running',
            );
          }
        });
  }

  /// Record a single audio chunk and process it
  Future<void> _recordSingleChunk() async {
    if (_tempAudioPath == null) return;

    // Create unique file path for each recording to avoid conflicts
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueAudioPath = _tempAudioPath!.replaceAll(
      '.m4a',
      '_$timestamp.m4a',
    );

    try {
      console.log('Starting recording chunk: $uniqueAudioPath');

      // Start recording with unique file path
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000, // Lower sample rate for faster processing
          bitRate: 64000, // Lower bit rate for faster processing
          numChannels: 1, // Mono recording
        ),
        path: uniqueAudioPath,
      );

      // Record for the specified duration
      await Future.delayed(_recordingDuration);

      // Stop recording
      final recordedPath = await _recorder.stop();
      console.log('Recording stopped, path: $recordedPath');

      if (recordedPath != null && File(recordedPath).existsSync()) {
        // Get file size for debugging
        final fileSize = await File(recordedPath).length();

        // Notify audio processing callbacks
        for (final callback in _audioProcessingCallbacks) {
          try {
            callback(recordedPath, fileSize);
          } catch (e) {
            console.log('Error in audio processing callback: $e');
          }
        }

        // Process the recorded audio
        await _processAudioChunk(recordedPath);

        // Clean up the temporary file after processing
        try {
          await File(recordedPath).delete();
        } catch (e) {
          console.log('Warning: Could not delete temp file $recordedPath: $e');
        }
      } else {
        console.log(
          'Warning: No recording file produced or file does not exist',
        );
      }
    } catch (e) {
      console.log('Error recording audio chunk: $e');

      // Try to clean up any partial file
      try {
        if (File(uniqueAudioPath).existsSync()) {
          await File(uniqueAudioPath).delete();
        }
      } catch (cleanupError) {
        console.log('Warning: Could not clean up partial file: $cleanupError');
      }
    }
  }

  /// Process an audio chunk for phrase detection
  Future<void> _processAudioChunk(String audioPath) async {
    try {
      console.log('Processing audio chunk: $audioPath');

      // Transcribe the audio - use appropriate method based on debug mode
      final transcript =
          _debugMode
              ? await _transcriptionService.transcribeAudioWithMockFallback(
                audioPath,
              )
              : await _transcriptionService.transcribeAudio(audioPath);

      // Notify transcription callbacks
      bool isSuccess = transcript != null && transcript.isNotEmpty;
      for (final callback in _transcriptionCallbacks) {
        try {
          callback(transcript ?? '', isSuccess);
        } catch (e) {
          console.log('Error in transcription callback: $e');
        }
      }

      if (transcript != null && transcript.isNotEmpty) {
        console.log('Transcribed: "$transcript"');

        // Check for watched phrases
        final detectedPhrase = _findMatchingPhrase(transcript);
        if (detectedPhrase != null) {
          console.log(
            'Detected phrase: "$detectedPhrase" in transcript: "$transcript"',
          );
          _notifyPhraseDetected(detectedPhrase, transcript);
        } else {
          console.log('No matching phrases found in transcript');
        }
      } else {
        console.log('No transcript received or transcript is empty');
      }

      console.log('Audio chunk processing completed');
    } catch (e) {
      console.log('Error processing audio chunk: $e');
    }
  }

  /// Find a matching phrase in the transcript
  String? _findMatchingPhrase(String transcript) {
    final lowercaseTranscript = transcript.toLowerCase();

    for (final phrase in _watchedPhrases) {
      if (_isPhraseSimilar(phrase, lowercaseTranscript)) {
        return phrase;
      }
    }

    return null;
  }

  /// Check if a phrase is similar enough to the transcript
  bool _isPhraseSimilar(String phrase, String transcript) {
    // Simple contains check for exact matches
    if (transcript.contains(phrase)) {
      return true;
    }

    // For more sophisticated matching, you could implement:
    // - Fuzzy string matching
    // - Word-by-word similarity
    // - Phonetic matching

    // Simple word-based similarity check
    final phraseWords = phrase.split(' ');
    final transcriptWords = transcript.split(' ');

    int matchingWords = 0;
    for (final phraseWord in phraseWords) {
      for (final transcriptWord in transcriptWords) {
        if (_calculateSimilarity(phraseWord, transcriptWord) >=
            _similarityThreshold) {
          matchingWords++;
          break;
        }
      }
    }

    // Consider it a match if most words are similar
    final similarity = matchingWords / phraseWords.length;
    return similarity >= _similarityThreshold;
  }

  /// Calculate similarity between two words using Levenshtein distance
  double _calculateSimilarity(String word1, String word2) {
    if (word1 == word2) return 1.0;
    if (word1.isEmpty || word2.isEmpty) return 0.0;

    final maxLength = word1.length > word2.length ? word1.length : word2.length;
    final distance = _levenshteinDistance(word1, word2);

    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Notify all callbacks when a phrase is detected
  void _notifyPhraseDetected(String detectedPhrase, String fullTranscript) {
    for (final callback in _callbacks) {
      try {
        callback(detectedPhrase, fullTranscript);
      } catch (e) {
        console.log('Error in phrase detection callback: $e');
      }
    }
  }

  /// Set debug mode (uses mock transcription when API fails)
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    console.log('Debug mode ${enabled ? "enabled" : "disabled"}');
  }

  /// Check if debug mode is enabled
  bool get isDebugMode => _debugMode;

  /// Check if the service is currently running
  bool get isRunning => _isRunning;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the list of currently watched phrases
  Set<String> get watchedPhrases => Set.from(_watchedPhrases);

  /// Test microphone permissions for debugging
  Future<bool> testMicrophonePermissions() async {
    try {
      final micStatus = await Permission.microphone.status;
      console.log('Microphone permission status: $micStatus');

      if (micStatus != PermissionStatus.granted) {
        final requestResult = await Permission.microphone.request();
        console.log('Microphone permission request result: $requestResult');
        return requestResult == PermissionStatus.granted;
      }

      final hasRecorderPermission = await _recorder.hasPermission();
      console.log('Recorder permission: $hasRecorderPermission');

      return hasRecorderPermission;
    } catch (e) {
      console.log('Error testing microphone permissions: $e');
      return false;
    }
  }

  /// Test recording a short audio sample for debugging
  Future<bool> testRecording() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final tempDir = await getTemporaryDirectory();
      final testPath = '${tempDir.path}/test_recording.m4a';

      console.log('Starting test recording...');

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: testPath,
      );

      await Future.delayed(const Duration(seconds: 1));

      final recordedPath = await _recorder.stop();

      if (recordedPath != null && File(recordedPath).existsSync()) {
        final fileSize = await File(recordedPath).length();
        console.log('Test recording successful: $fileSize bytes');

        // Clean up test file
        await File(recordedPath).delete();
        return true;
      } else {
        console.log('Test recording failed: no file produced');
        return false;
      }
    } catch (e) {
      console.log('Test recording error: $e');
      return false;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopDetection();
    _callbacks.clear();
    _watchedPhrases.clear();
  }
}
