import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _initializePhraseDetection();
    _startDetection();
    // Test TTS functionality on startup
    _testTextToSpeech();
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
    _phraseDetectionService.addAudioProcessingCallback((audioPath, fileSize) {
      print('🎤 AUDIO RECORDED: $audioPath');
      print('📊 File size: ${fileSize} bytes');
      print('---');
    });

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
      // Only log to console, no UI updates
      print('🎯 PHRASE DETECTED: "$detectedPhrase"');
      print('📝 Full transcript: "$fullTranscript"');
      print('⏰ Time: ${DateTime.now()}');
      print('---');

      // Handle specific phrases
      if (detectedPhrase.contains('stop listening')) {
        _stopDetection();
      }
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReflectifAI - Console Mode'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Phrase Detection Running',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Check console for phrase detections',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _testTextToSpeech,
              child: const Text('Test Text-to-Speech'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _stopDetection();
                await _startDetection();
              },
              child: const Text('Restart Detection'),
            ),
          ],
        ),
      ),
    );
  }
}
