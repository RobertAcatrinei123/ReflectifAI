import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:reflectifai/service/audio_recording_service.dart';
import 'package:reflectifai/service/phrase_detection_service.dart';
import 'package:reflectifai/service/elevenlabs.dart';
import 'package:reflectifai/service/audio_playback_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PhraseDetectionService _phraseDetectionService =
      PhraseDetectionService();
  final ElevenlabsService _elevenlabsService = ElevenlabsService();
  final AudioRecordingService _audioRecordingService = AudioRecordingService();
  final AudioPlaybackService _audioPlaybackService = AudioPlaybackService();
  String text = 'initializing...';

  @override
  void initState() {
    super.initState();
    _initializePhraseDetection();
    _startDetection();
    _audioRecordingService.init();
    _initializeAudioPlayback();
  }

  Future<void> _initializeAudioPlayback() async {
    // Initialize audio playback service
    await _audioPlaybackService.initialize();

    // Set up callbacks
    _audioPlaybackService.onPlaybackComplete = () {
      console.log('🔊 Audio playback completed');
    };

    _audioPlaybackService.onPlaybackError = (error) {
      console.log('❌ Audio playback error: $error');
    };

    _audioPlaybackService.onPlaybackStart = () {
      console.log('🔊 Audio playback started');
    };
  }

  Future<void> _initializePhraseDetection() async {
    // Add some example phrases to watch for
    _phraseDetectionService.addWatchedPhrase('hello');
    _phraseDetectionService.addWatchedPhrase('hey');
    _phraseDetectionService.addWatchedPhrase('hello reflectify');
    _phraseDetectionService.addWatchedPhrase('hey reflectify');
    _phraseDetectionService.addWatchedPhrase('hello reflectifai');
    _phraseDetectionService.addWatchedPhrase('hey reflectifai');
    //_phraseDetectionService.addWatchedPhrase('reflectif');
    //_phraseDetectionService.addWatchedPhrase('stop listening');

    // Set similarity threshold (0.8 means 80% similarity required)
    _phraseDetectionService.setSimilarityThreshold(0.7);

    // Add debugging callback for audio processing
    _phraseDetectionService.addAudioProcessingCallback(
      (audioPath, fileSize) {},
    );

    // Add debugging callback for transcription results
    _phraseDetectionService.addTranscriptionCallback((transcript, isSuccess) {
      if (isSuccess && transcript.isNotEmpty) {
        print('📝 TRANSCRIPTION SUCCESS: "$transcript"');
      } else if (!isSuccess) {
        print('❌ TRANSCRIPTION FAILED');
      } else {
        print('🔇 TRANSCRIPTION EMPTY (no speech detected)');
      }
      print('---');
    });

    // Add callback for when phrases are detected
    _phraseDetectionService.addPhraseDetectedCallback((
      detectedPhrase,
      fullTranscript,
    ) {
      console.log(
        '📣 PHRASE DETECTED: "$detectedPhrase" in full transcript: "$fullTranscript"',
      );
      setState(() {
        text = 'wake phrase detected!';
      });
      startListening();
    });
  }

  void startListening() async {
    console.log(
      '🎯 Wake phrase detected - starting extended listening session',
    );

    // DON'T stop detection yet - just extend the current session
    setState(() {
      text = 'listening...';
    });

    // Start a longer recording session using the existing phrase detection service
    // We'll modify it to record for longer when triggered
    await _startExtendedListening();
  }

  Future<void> _startExtendedListening() async {
    console.log('🎤 Starting extended listening session (10 seconds)...');

    // Temporarily stop the continuous phrase detection
    await _stopDetection();

    // Wait a moment for the audio system to be fully released
    await Future.delayed(Duration(milliseconds: 500));

    try {
      // Use the existing audio recording service with a longer timeout
      var bytes = await _audioRecordingService.startRecording(
        timeoutDuration: Duration(seconds: 10), // 10 seconds instead of 20
        silenceDetectionDuration: Duration(
          seconds: 2,
        ), // Stop after 2 seconds of silence
      );

      String? words;
      if (bytes != null) {
        console.log(
          '🎤 EXTENDED RECORDING COMPLETED, SIZE: ${bytes.length} bytes',
        );
        words = await _elevenlabsService.transcribeAudioBytes(bytes);
      } else {
        console.log('❌ EXTENDED RECORDING FAILED OR TIMED OUT');
      }

      if (words != null && words.isNotEmpty) {
        setState(() {
          text = 'processing...';
        });
        console.log('📝 EXTENDED TRANSCRIPTION RESULT: "$words"');

        setState(() {
          text = 'received: "$words"';
        });

        // Convert the received text to speech and play it back
        await _generateAndPlayResponse(words);

        // Wait a moment to show the result
        await Future.delayed(Duration(seconds: 2));
      } else {
        console.log('🔇 NO WORDS DETECTED IN EXTENDED TRANSCRIPTION');
      }
    } catch (e) {
      console.log('❌ Error in extended listening: $e');
    }

    // Reset the UI and restart phrase detection
    setState(() {
      text = 'listening for wake phrase...';
    });

    // Wait another moment before restarting phrase detection
    await Future.delayed(Duration(milliseconds: 500));
    await _startDetection();
  }

  Future<void> _startDetection() async {
    final success = await _phraseDetectionService.startDetection();
    if (success) {
      setState(() {
        text = 'listening for wake phrase...';
      });
      console.log('✅ Phrase detection started successfully');
    } else {
      setState(() {
        text = 'error: check permissions';
      });
      _showErrorDialog(
        'Failed to start phrase detection. Please check permissions.',
      );
    }
  }

  Future<void> _stopDetection() async {
    await _phraseDetectionService.stopDetection();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _phraseDetectionService.dispose();
    super.dispose();
  }

  /// Generate a text-to-speech response and play it back
  Future<void> _generateAndPlayResponse(String userInput) async {
    try {
      console.log('🎤 Generating TTS response for: "$userInput"');

      setState(() {
        text = 'generating response...';
      });

      // Create a simple response based on user input
      String responseText = await _createResponse(userInput);
      console.log('💬 Response text: "$responseText"');

      setState(() {
        text = 'converting to speech...';
      });

      // Convert response to speech
      final audioBytes = await _elevenlabsService.textToSpeech(
        text: responseText,
      );

      if (audioBytes != null) {
        console.log('✅ TTS conversion successful');

        setState(() {
          text = 'playing response...';
        });

        // Play the audio response
        final playbackSuccess = await _audioPlaybackService.playAudioBytes(
          audioBytes,
          fileExtension: 'mp3',
        );

        if (playbackSuccess) {
          console.log('🔊 Audio response playback started');
        } else {
          console.log('❌ Failed to start audio playback');
          setState(() {
            text = 'playback failed';
          });
        }
      } else {
        console.log('❌ TTS conversion failed');
        setState(() {
          text = 'tts failed';
        });
      }
    } catch (e) {
      console.log('❌ Error generating response: $e');
      setState(() {
        text = 'response error';
      });
    }
  }

  /// Create a simple response based on user input
  Future<String> _createResponse(String userInput) async {
    final input = userInput.toLowerCase().trim();

    // Simple responses based on keywords
    if (input.contains('hello') || input.contains('hi')) {
      return 'Hello! How can I help you today?';
    } else if (input.contains('how are you')) {
      return 'I am doing well, thank you for asking!';
    } else if (input.contains('what') && input.contains('time')) {
      final now = DateTime.now();
      return 'The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    } else if (input.contains('weather')) {
      return 'I cannot check the weather right now, but I hope it is nice where you are!';
    } else if (input.contains('thank')) {
      return 'You are welcome!';
    } else if (input.contains('goodbye') || input.contains('bye')) {
      return 'Goodbye! Have a great day!';
    } else if (input.contains('joke')) {
      return 'Why do programmers prefer dark mode? Because light attracts bugs!';
    } else {
      return 'I heard you say: $userInput. That is interesting!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
