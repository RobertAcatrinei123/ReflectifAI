import 'dart:developer' as console;
import 'package:reflectifai/service/phrase_detection_service.dart';

/// Example service that demonstrates how to use phrase detection
/// for triggering specific actions in your app
class ActionTriggerService {
  final PhraseDetectionService _phraseDetectionService =
      PhraseDetectionService();

  // Callbacks for different actions
  Function()? onWakeWordDetected;
  Function()? onStopCommand;
  Function(String)? onCustomAction;

  /// Initialize the service with common wake words and commands
  Future<bool> initialize() async {
    // Add common wake words
    _phraseDetectionService.addWatchedPhrase('hey reflectif');
    _phraseDetectionService.addWatchedPhrase('hello reflectif');
    _phraseDetectionService.addWatchedPhrase('wake up');

    // Add action commands
    _phraseDetectionService.addWatchedPhrase('stop listening');
    _phraseDetectionService.addWatchedPhrase('pause detection');
    _phraseDetectionService.addWatchedPhrase('take note');
    _phraseDetectionService.addWatchedPhrase('start recording');
    _phraseDetectionService.addWatchedPhrase('save recording');
    _phraseDetectionService.addWatchedPhrase('open settings');
    _phraseDetectionService.addWatchedPhrase('show menu');

    // Set up the callback to handle detected phrases
    _phraseDetectionService.addPhraseDetectedCallback(_handlePhraseDetection);

    // Initialize the underlying service
    return await _phraseDetectionService.initialize();
  }

  /// Start background detection
  Future<bool> startDetection() async {
    return await _phraseDetectionService.startDetection();
  }

  /// Stop background detection
  Future<void> stopDetection() async {
    await _phraseDetectionService.stopDetection();
  }

  /// Handle detected phrases and trigger appropriate actions
  void _handlePhraseDetection(String detectedPhrase, String fullTranscript) {
    console.log(
      'ActionTriggerService: Detected "$detectedPhrase" in "$fullTranscript"',
    );

    // Handle wake words
    if (_isWakeWord(detectedPhrase)) {
      console.log('Wake word detected: $detectedPhrase');
      onWakeWordDetected?.call();
      return;
    }

    // Handle stop commands
    if (_isStopCommand(detectedPhrase)) {
      console.log('Stop command detected: $detectedPhrase');
      onStopCommand?.call();
      return;
    }

    // Handle specific actions
    final action = _mapPhraseToAction(detectedPhrase);
    if (action != null) {
      console.log('Action triggered: $action for phrase: $detectedPhrase');
      onCustomAction?.call(action);
    }
  }

  /// Check if the phrase is a wake word
  bool _isWakeWord(String phrase) {
    final wakeWords = ['hey reflectif', 'hello reflectif', 'wake up'];
    return wakeWords.any((wakeWord) => phrase.contains(wakeWord));
  }

  /// Check if the phrase is a stop command
  bool _isStopCommand(String phrase) {
    final stopCommands = ['stop listening', 'pause detection'];
    return stopCommands.any((stopCmd) => phrase.contains(stopCmd));
  }

  /// Map detected phrases to specific actions
  String? _mapPhraseToAction(String phrase) {
    final actionMap = {
      'take note': 'take_note',
      'start recording': 'start_recording',
      'save recording': 'save_recording',
      'open settings': 'open_settings',
      'show menu': 'show_menu',
    };

    for (final entry in actionMap.entries) {
      if (phrase.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Add a custom phrase to watch for
  void addCustomPhrase(String phrase) {
    _phraseDetectionService.addWatchedPhrase(phrase);
  }

  /// Remove a phrase from watching
  void removeCustomPhrase(String phrase) {
    _phraseDetectionService.removeWatchedPhrase(phrase);
  }

  /// Check if detection is running
  bool get isRunning => _phraseDetectionService.isRunning;

  /// Get all watched phrases
  Set<String> get watchedPhrases => _phraseDetectionService.watchedPhrases;

  /// Clean up resources
  Future<void> dispose() async {
    await _phraseDetectionService.dispose();
  }
}
