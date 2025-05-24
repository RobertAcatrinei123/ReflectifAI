import 'dart:async';
import 'dart:developer' as console;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class LocalSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';

  // Callback for when speech is recognized
  Function(String)? onSpeechResult;

  /// Initialize the local speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      console.log('Initializing local speech recognition service...');

      final available = await _speech.initialize(
        onStatus: (status) {
          console.log('Speech recognition status: $status');
        },
        onError: (error) {
          console.log('Speech recognition error: $error');
        },
      );

      if (available) {
        _isInitialized = true;
        console.log('Local speech recognition initialized successfully');

        // Log available locales for debugging
        final locales = await _speech.locales();
        console.log(
          'Available locales: ${locales.map((l) => l.localeId).join(', ')}',
        );

        return true;
      } else {
        console.log('Speech recognition not available on this device');
        return false;
      }
    } catch (e) {
      console.log('Error initializing local speech recognition: $e');
      return false;
    }
  }

  /// Start continuous listening for speech
  Future<bool> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) {
      console.log('Already listening with local speech recognition');
      return true;
    }

    try {
      console.log('Starting local speech recognition...');

      final success = await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          console.log('Local speech recognized: "${_lastRecognizedWords}"');

          if (result.finalResult && onSpeechResult != null) {
            onSpeechResult!(_lastRecognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30), // Listen for longer periods
        pauseFor: const Duration(seconds: 3), // Pause detection
        partialResults: true, // Get partial results
        localeId: 'en_US', // Set locale explicitly
        cancelOnError: false, // Don't cancel on errors
        listenMode: stt.ListenMode.confirmation, // Confirmation mode
      );

      if (success) {
        _isListening = true;
        console.log('Local speech recognition started successfully');
        return true;
      } else {
        console.log('Failed to start local speech recognition');
        return false;
      }
    } catch (e) {
      console.log('Error starting local speech recognition: $e');
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      console.log('Local speech recognition stopped');
    } catch (e) {
      console.log('Error stopping local speech recognition: $e');
    }
  }

  /// Check if the service is currently listening
  bool get isListening => _isListening;

  /// Get the last recognized words
  String get lastRecognizedWords => _lastRecognizedWords;

  /// Check if speech recognition is available
  Future<bool> isAvailable() async {
    return await _speech.initialize();
  }

  /// Dispose of the service
  void dispose() {
    if (_isListening) {
      _speech.stop();
    }
    _isListening = false;
    _isInitialized = false;
  }
}
