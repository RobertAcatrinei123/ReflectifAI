import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:reflectifai/screens/idle.dart';
import 'package:reflectifai/screens/listen.dart';
import 'package:reflectifai/screens/newspeaking.dart';
import 'package:reflectifai/screens/speaking.dart';
import 'package:reflectifai/screens/transition.dart';
import 'package:reflectifai/service/audio_recording_service.dart';
import 'package:reflectifai/service/gemini_service.dart';
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
  final GeminiService _geminiService = GeminiService();
  List<Map<String, String>> chat = [];
  List<Map<String, String>> instructions = [];
  String text = 'initializing...';
  String state = "IDLE";

  @override
  void initState() {
    super.initState();
    _initializePhraseDetection();
    _startDetection();
    _audioRecordingService.init();
    _initializeAudioPlayback();
    getInstructions();
  }

  Future<void> getInstructions() async {
    instructions.add({
      "text":
          "You are role-playing as Reflectify, a warm and respectful AI companion designed to support an older adult named Vlad.\n\nYour role is to engage in daily conversations, help maintain routines, and offer emotional presence. Your voice and memory are familiar to Vlad.\n\nTone:\n- Speak calmly and kindly.\n- Use short, clear sentences.\n- Avoid jargon and technical terms.\n\nPersona:\n- You are Reflectify, a trusted assistant and companion.\n- You keep track of Vlad's habits, preferences, and recurring tasks.\n- You offer helpful reminders, conversation, and support.\nRules:\n1. Respond in English only.\n2. Never mention AI, prompts, or system roles.\n3. Use Vlad's name often and speak with familiarity.\n4. Be patient, emotionally aware, and supportive.\n5. Do not give legal, financial, or medical advice — suggest contacting family or professionals.\n6. If no interaction from Vlad for 6+ hours between 08:00-22:00, send a soft-voiced check-in.\n8. When prompted or when relevant, retrieve and refer to knowledge from the “knowledge tree.”\n",
    });
    instructions.add({
      "text":
          "You will get a user sheet with information about Vlad, his habits, preferences, and routines. Use this information to personalize your responses and interactions.",
    });
    instructions.add({
      "text":
          '{"user":{"name": "Vlad","age": 69,"location": "Cluj, Romania","living_situation": "Lives alone in an apartment","emotional_notes": ["Often feels lonely in the evenings","Dislikes being rushed","Prefers calm, simple conversations"]},"daily_routine": [{ "time": "08:00", "activity": "Takes morning medication, makes tea, reads sports headlines" },{ "time": "10:30", "activity": "Checks balcony plants (mint, roses, cherry tomatoes)" },{ "time": "13:00", "activity": "Cooks something light (grilled cheese, potato stew)" },{ "time": "16:00", "activity": "Listens to Romanian radio and does light stretches" },{ "time": "18:30", "activity": "Watches football highlights or looks through family photo albums" },{ "time": "21:00", "activity": "Takes evening medication and prepares for bed by 22:00" }],"interests": ["Romanian football history (especially Steaua in the 1980s)","Balcony gardening and herbs","Old family memories","Light humor","Weather, birthdays, daily curiosities"],"dislikes": ["Being rushed","Cold meals","Tech jargon"],"shared_memory": "Vlad once told Reflectify about attending a Steaua match with his brother in 1986, wearing matching scarves and cheering until they lost their voices."}',
    });
  }

  Future<void> _initializeAudioPlayback() async {
    // Initialize audio playback service
    _audioPlaybackService.initialize();
    console.log('🔊 Initializing AudioPlaybackService...');

    // Set up callbacks
    _audioPlaybackService.onPlaybackComplete = () {
      console.log('🔊 Audio playback completed');
      _startDetection();
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
      startListening();
    });
  }

  void startListening() async {
    console.log(
      '🎯 Wake phrase detected - starting extended listening session',
    );
    setState(() {
      state = "TRANSITION";
    });

    await Future.delayed(Duration(seconds: 2));

    // DON'T stop detection yet - just extend the current session
    setState(() {
      state = "LISTENING";
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
        timeoutDuration: Duration(seconds: 5),
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
  }

  Future<void> _startDetection() async {
    console.log('🔍 Starting phrase detection...');
    setState(() {
      state = "IDLE";
    });
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
          state = "SPEAKING";
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
    chat.add({"role": "user", "content": userInput});
    var res = await _geminiService.getResponse(chat, instructions);
    chat.add({"role": "model", "content": res});
    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (state == "IDLE") {
      return IdleScreen();
    } else if (state == "LISTENING") {
      return ListenScreen();
    } else if (state == "TRANSITION") {
      return TransitionScreen();
    } else {
      return NewSpeakingScreen();
    }
  }
}
