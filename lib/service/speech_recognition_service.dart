import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isManuallyStopping = false; // New flag
  String _currentLocaleId = 'en_US'; // To store localeId for restarts

  // For wake phrase
  List<String> _currentWakePhrases =
      []; 
  VoidCallback? _onWakePhraseDetected;

  // For general speech to text
  Function(String text)? _onSpeechResult;

  String _lastRecognizedWords = '';

  String get lastRecognizedWords => _lastRecognizedWords;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: _statusListener,
        onError: _errorListener,
        debugLogging: true, 
      );
    } catch (e) {
      debugPrint("Speech recognition initialization failed: $e");
      _isInitialized = false;
    }
    return _isInitialized;
  }

  void _statusListener(String status) {
    debugPrint("Speech status: $status");
    bool previouslyListening = _isListening;

    if (status == SpeechToText.listeningStatus) {
      _isListening = true;
    } else {
      _isListening = false;
    }

    if (previouslyListening &&
        !_isListening && // Stopped listening
        _onWakePhraseDetected != null && // Was in wake phrase mode
        _isInitialized &&
        !_isManuallyStopping) { // And not manually stopped
      debugPrint("Wake phrase listening segment ended, restarting cycle...");
      _beginListeningCycle();
    }
  }

  void _errorListener(SpeechRecognitionError error) {
    debugPrint(
      "Speech error: ${error.errorMsg} - permanent: ${error.permanent}",
    );
    if (_isListening && error.permanent) {
        _isListening = false; // Ensure listening stops on permanent error
    }

    if (!error.permanent &&
        _onWakePhraseDetected != null && // Was in wake phrase mode
        _isInitialized &&
        !_isManuallyStopping) { // And not manually stopped
      debugPrint(
          "Non-permanent error in wake phrase listening, attempting to restart cycle after delay...");
      Future.delayed(const Duration(seconds: 1), () {
        if (_onWakePhraseDetected != null &&
            !_isListening && 
            _isInitialized &&
            !_isManuallyStopping) {
          _beginListeningCycle();
        }
      });
    } else if (error.permanent) {
        _isListening = false; 
    }
  }

  void setOnWakePhraseDetected(VoidCallback callback) {
    _onWakePhraseDetected = callback;
  }

  void startListeningForWakePhrase({
    required List<String> wakePhrases,
    String localeId = 'en_US',
  }) {
    if (!_isInitialized) {
      debugPrint("Cannot start wake phrase: Not initialized.");
      return;
    }
    if (_isListening && _onSpeechResult != null) {
      debugPrint("Cannot start wake phrase: General STT is active. Stop it first.");
      return;
    }
    if (_isListening && _onWakePhraseDetected != null && !_isManuallyStopping) {
        debugPrint("Wake phrase listening is already active and continuous.");
        return;
    }

    _isManuallyStopping = false; // Reset flag for a new continuous session
    _currentLocaleId = localeId; // Store for potential restarts

    _currentWakePhrases =
        wakePhrases.map((phrase) => phrase.toLowerCase()).toList();
    _onSpeechResult = null; 

    if (_onWakePhraseDetected == null) {
        debugPrint("WARN: _onWakePhraseDetected callback is not set. Use setOnWakePhraseDetected().");
        // Decide if you want to prevent starting or just warn
    }
    
    debugPrint("Starting continuous wake phrase listening cycle...");
    _beginListeningCycle();
  }

  void _beginListeningCycle() {
    if (!_isInitialized || _isListening || _isManuallyStopping || _onWakePhraseDetected == null || _currentWakePhrases.isEmpty) {
      debugPrint(
          "Skipping _beginListeningCycle: Initialized=$_isInitialized, Listening=$_isListening, ManuallyStopping=$_isManuallyStopping, WakeCallbackNull=${_onWakePhraseDetected == null}, NoPhrases=${_currentWakePhrases.isEmpty}");
      return;
    }
    _speechToText.listen(
      onResult: _wakePhraseResultListener,
      localeId: _currentLocaleId, // Use stored localeId
      listenFor: const Duration(seconds: 60), // Shorter segment for continuous listening
      pauseFor: const Duration(seconds: 5), // Silence before segment ends
      partialResults: true, 
      cancelOnError: true, // We handle non-permanent error restarts
      listenMode: ListenMode.confirmation,
    );
    // _isListening will be set to true by _statusListener if successful
  }

  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    var previousRow = List<int>.generate(s2.length + 1, (i) => i);
    for (var i = 0; i < s1.length; i++) {
      var currentRow = List<int>.filled(s2.length + 1, 0);
      currentRow[0] = i + 1;
      for (var j = 0; j < s2.length; j++) {
        var cost = (s1[i] == s2[j]) ? 0 : 1;
        currentRow[j + 1] = <int>[
          previousRow[j + 1] + 1, 
          currentRow[j] + 1, 
          previousRow[j] + cost, 
        ].reduce((min, e) => e < min ? e : min);
      }
      previousRow = currentRow;
    }
    int levenshteinDistance = previousRow[s2.length];
    int maxLength = s1.length > s2.length ? s1.length : s2.length;
    if (maxLength == 0) return 1.0; 
    return (maxLength - levenshteinDistance) / maxLength;
  }

  void _wakePhraseResultListener(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;
    debugPrint("Wake phrase listener: Heard: '${result.recognizedWords}'");
    final recognizedText = result.recognizedWords.toLowerCase();
    if (recognizedText.isEmpty) return;
    for (String phrase in _currentWakePhrases) {
      if (phrase.isEmpty) continue;
      double similarity = _calculateSimilarity(recognizedText, phrase);
      debugPrint(
        "Comparing \"$recognizedText\" with \"$phrase\" - Similarity: ${(similarity * 100).toStringAsFixed(2)}%",
      );
      if (similarity >= 0.80) {
        debugPrint(
          "Wake phrase detected (similarity >= 80%): $phrase (Heard: '$recognizedText')",
        );
        _onWakePhraseDetected?.call();
        // For truly continuous listening, we don't stop here.
        // The _statusListener will handle restarting the cycle if it stops.
        // If you want it to stop after detection, you would call stopListeningForWakePhrase() here.
        return; 
      }
    }
  }

  Future<void> stopListeningForWakePhrase() async {
    debugPrint("Attempting to stop wake phrase listening manually...");
    _isManuallyStopping = true;
    if (_onWakePhraseDetected != null) { 
      if (_speechToText.isListening) {
        await _speechToText.stop(); 
      }
      _isListening = false; 
      // _onWakePhraseDetected = null; // Keep this to know it *was* in wake phrase mode
      // _currentWakePhrases = []; // Keep phrases if you might restart with same phrases
      debugPrint("Manually stopped listening for wake phrase. It will not auto-restart.");
    } else {
      debugPrint("Wake phrase listening was not active or already stopped.");
    }
  }

  void startSpeechToText({
    required Function(String text) onResult,
    String localeId = 'en_US',
  }) {
    if (!_isInitialized) return;
    if (_isListening && _onWakePhraseDetected != null) {
        debugPrint("Wake phrase listening is active. Stopping it before starting STT.");
        // Intentionally stop the continuous wake phrase listening
        _isManuallyStopping = true; 
        if (_speechToText.isListening) {
            _speechToText.stop();
        }
    } else if (_isListening) {
        debugPrint("Another listening session is active. Cannot start STT.");
        return;
    }

    _onSpeechResult = onResult;
    _currentWakePhrases = []; 
    _onWakePhraseDetected = null; // Ensure it's not in wake phrase mode
    _isManuallyStopping = false; // STT is not a continuous cycle in this design
    _currentLocaleId = localeId;

    _speechToText.listen(
      onResult: _speechToTextResultListener,
      localeId: _currentLocaleId,
      listenFor: const Duration(seconds: 30), 
      pauseFor: const Duration(seconds: 3), 
      partialResults: false, 
      cancelOnError: true,
    );
    _isListening = true;
  }

  void _speechToTextResultListener(SpeechRecognitionResult result) {
    _lastRecognizedWords = result.recognizedWords;
    if (result.finalResult) {
      debugPrint("Speech-to-text final result: ${result.recognizedWords}");
      _onSpeechResult?.call(result.recognizedWords);
      _isListening = false; 
    } else {
      debugPrint("Speech-to-text partial result: ${result.recognizedWords}");
    }
  }

  void stopListening() {
    debugPrint("Attempting to stop ALL listening manually (general stop)...");
    _isManuallyStopping = true;
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _isListening = false;
    // Reset callbacks to indicate no specific mode is active
    // _onWakePhraseDetected = null; 
    // _onSpeechResult = null;
    // _currentWakePhrases = [];
    debugPrint("All speech listening manually stopped. No auto-restarts.");
  }

  void cancelListening() {
    debugPrint("Attempting to CANCEL ALL listening manually...");
    _isManuallyStopping = true;
    if (_speechToText.isListening) {
      _speechToText.cancel();
    }
    _isListening = false;
    // _onWakePhraseDetected = null;
    // _onSpeechResult = null;
    // _currentWakePhrases = [];
    debugPrint("All speech listening manually cancelled. No auto-restarts.");
  }

  void dispose() {
    debugPrint("Disposing SpeechRecognitionService...");
    _isManuallyStopping = true; // Ensure no attempts to restart during disposal
    if (_speechToText.isListening) {
        _speechToText.cancel();
    }
    _isInitialized = false;
    _onWakePhraseDetected = null;
    _onSpeechResult = null;
    debugPrint("SpeechRecognitionService disposed.");
  }
}
