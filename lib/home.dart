import 'dart:developer' as console;

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:reflectifai/service/audio_recording_service.dart';
import 'package:reflectifai/service/phrase_detection_service.dart';
import 'package:reflectifai/service/elevenlabs.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  String text = 'stop';

  @override
  void initState() {
    super.initState();
    _initializePhraseDetection();
    _startDetection();
    _audioRecordingService.init();
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

    // Enable debug mode for testing (uses mock data when API fails)
    _phraseDetectionService.setDebugMode(true);

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
        text = 'start';
      });
      startListening();
    });
  }

  void startListening() async {
    await _stopDetection();
    var bytes = await _audioRecordingService.startRecording();
    String? words = null;
    if (bytes != null) {
      console.log('🎤 AUDIO RECORDING COMPLETED, SIZE: ${bytes.length} bytes');
      // Process the recorded audio bytes as needed
      words = await _elevenlabsService.transcribeAudioBytes(bytes);
    } else {
      console.log('❌ AUDIO RECORDING FAILED OR TIMED OUT');
    }
    if (words != null && words.isNotEmpty) {
      setState(() {
        text = 'stop';
      });
      console.log('📝 TRANSCRIPTION RESULT: "$words"');
    } else {
      console.log('🔇 NO WORDS DETECTED IN TRANSCRIPTION');
    }
    await _startDetection();
  }

  Future<void> _startDetection() async {
    final success = await _phraseDetectionService.startDetection();
    if (success) {
    } else {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(text)));
  }
}
