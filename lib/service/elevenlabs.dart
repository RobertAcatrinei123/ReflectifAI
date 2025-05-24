import 'dart:async';
import 'dart:convert';
import 'dart:developer' as console;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:reflectifai/apikeys.dart';
import 'package:reflectifai/service/local_speech_service.dart';

class ElevenlabsService {
  // Eleven Labs API settings
  static const String _elevenLabsEndpoint = 'https://api.elevenlabs.io/v1';
  static const String _speechToTextApiPath = '/speech-to-text';

  // Replace with your Eleven Labs API key
  static const String _apiKey = Apikeys.elevenlabs;

  // Default model for transcription
  static const String _modelId = 'scribe_v1';

  // Fallback service
  final LocalSpeechService _localSpeechService = LocalSpeechService();
  bool _useLocalFallback = false;

  /// Transcribe audio file using Eleven Labs Speech-to-Text API
  /// Returns the transcribed text or null if transcription fails
  Future<String?> transcribeAudio(String audioFilePath) async {
    try {
      console.log('Starting Eleven Labs transcription of $audioFilePath');

      // Check if the audio file exists
      final audioFile = File(audioFilePath);
      if (!audioFile.existsSync()) {
        console.log('Audio file does not exist');
        return null;
      }

      // Read the audio file as bytes
      final audioBytes = await audioFile.readAsBytes();

      // Make API call to Eleven Labs Speech-to-Text service
      return await _callElevenLabsSpeechApi(audioBytes);
    } catch (e) {
      console.log('Error in Eleven Labs transcription: $e');
      return null;
    }
  }

  /// Transcribe audio from bytes using Eleven Labs Speech-to-Text API
  /// Returns the transcribed text or null if transcription fails
  Future<String?> transcribeAudioBytes(List<int> audioBytes) async {
    try {
      console.log('Starting Eleven Labs transcription from audio bytes');

      if (audioBytes.isEmpty) {
        console.log('Error: Audio bytes are empty');
        return null;
      }

      // Make API call to Eleven Labs Speech-to-Text service
      return await _callElevenLabsSpeechApi(audioBytes);
    } catch (e) {
      console.log('Error in Eleven Labs transcription: $e');
      return null;
    }
  }

  /// Call Eleven Labs Speech-to-Text API
  Future<String?> _callElevenLabsSpeechApi(List<int> audioBytes) async {
    try {
      // Validate audio bytes
      if (audioBytes.isEmpty) {
        console.log('Error: Audio bytes are empty');
        return null;
      }

      console.log(
        'Preparing to send ${audioBytes.length} bytes to Eleven Labs API',
      );

      // Test network connectivity first with shorter timeout
      try {
        final testUri = Uri.parse(
          'https://8.8.8.8',
        ); // Use Google DNS for basic connectivity
        final client = http.Client();
        await client.head(testUri).timeout(const Duration(seconds: 2));
        client.close();
        console.log('Basic network connectivity: OK');
      } catch (connectivityError) {
        console.log('Network connectivity test failed: $connectivityError');
        console.log('Proceeding with API call anyway...');
      }

      // Create API URL
      final uri = Uri.parse('$_elevenLabsEndpoint$_speechToTextApiPath');

      // Create multipart request
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'xi-api-key': _apiKey,
        'Content-Type': 'multipart/form-data',
      });

      // Add audio file as 'file' parameter with appropriate MIME type
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'recording.m4a',
        ),
      );

      // Add model_id parameter
      request.fields['model_id'] = _modelId;

      console.log('Sending request to Eleven Labs Speech-to-Text API');
      console.log('Request : $request');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15), // Reduced timeout from 30 to 15 seconds
        onTimeout: () {
          console.log('Request to Eleven Labs API timed out after 15 seconds');
          throw TimeoutException(
            'API request timed out',
            const Duration(seconds: 15),
          );
        },
      );

      // Process the response
      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        console.log('Eleven Labs API response: $responseBody');

        final jsonResponse = jsonDecode(responseBody);

        // Extract text from response
        if (jsonResponse.containsKey('text')) {
          console.log('Transcription successful: ${jsonResponse['text']}');
          return jsonResponse['text'];
        } else {
          console.log('Could not find text in response: $jsonResponse');
          return null;
        }
      } else {
        final responseBody = await streamedResponse.stream.bytesToString();
        console.log(
          'Eleven Labs API error: ${streamedResponse.statusCode} $responseBody',
        );
        return null;
      }
    } catch (e) {
      console.log('Error calling Eleven Labs API: $e');
      return null;
    }
  }

  /// Transcribe audio file using Eleven Labs Speech-to-Text API with local fallback
  /// Returns the transcribed text or null if transcription fails
  Future<String?> transcribeAudioWithFallback(String audioFilePath) async {
    // First try Eleven Labs API
    final elevenLabsResult = await transcribeAudio(audioFilePath);
    if (elevenLabsResult != null && elevenLabsResult.isNotEmpty) {
      return elevenLabsResult;
    }

    console.log('Eleven Labs failed, attempting local speech recognition...');

    // Fallback to local speech recognition
    try {
      final isAvailable = await _localSpeechService.isAvailable();
      if (!isAvailable) {
        console.log('Local speech recognition not available');
        return null;
      }

      // For local speech, we need to record live audio rather than transcribe files
      // This is a limitation of the speech_to_text package
      console.log('Local speech recognition available but requires live audio');
      _useLocalFallback = true;
      return null;
    } catch (e) {
      console.log('Local speech recognition error: $e');
      return null;
    }
  }

  /// Mock transcription for testing when API is unavailable
  String? _mockTranscription() {
    // Simulate some realistic transcription results for testing
    final mockPhrases = [
      'hello there how are you',
      'hey what\'s up',
      'hello reflectifai please help me',
      'hey reflectify can you hear me',
      'this is a test of the system',
      '', // Empty result to simulate no speech
    ];

    // Return a random phrase or empty string
    final random = DateTime.now().millisecondsSinceEpoch % mockPhrases.length;
    final result = mockPhrases[random];

    if (result.isNotEmpty) {
      console.log('Using mock transcription: "$result"');
    } else {
      console.log('Mock transcription: empty (no speech detected)');
    }

    return result.isEmpty ? null : result;
  }

  /// Transcribe with mock fallback for testing
  Future<String?> transcribeAudioWithMockFallback(String audioFilePath) async {
    // First try the real API
    final apiResult = await transcribeAudio(audioFilePath);
    if (apiResult != null && apiResult.isNotEmpty) {
      return apiResult;
    }

    console.log('API failed, using mock transcription for testing...');

    // Add a small delay to simulate processing time
    await Future.delayed(const Duration(milliseconds: 500));

    return _mockTranscription();
  }

  /// Convert text to speech using Eleven Labs Text-to-Speech API
  /// Returns the audio bytes or null if conversion fails
  Future<List<int>?> textToSpeech({
    required String text,
    String voiceId = 'JBFqnCBsd6RMkjVDRZzb', // Default voice ID from template
    String outputFormat = 'mp3_44100_128',
    String modelId = 'eleven_multilingual_v2',
  }) async {
    try {
      console.log('Starting Eleven Labs text-to-speech conversion');
      console.log('Text: "$text"');
      console.log('Voice ID: $voiceId');
      console.log('Model: $modelId');

      // Create API URL with voice ID and output format
      final uri = Uri.parse(
        '$_elevenLabsEndpoint/text-to-speech/$voiceId?output_format=$outputFormat',
      );

      // Prepare request body
      final requestBody = {'text': text, 'model_id': modelId};

      console.log('Sending TTS request to: $uri');
      console.log('Request body: ${jsonEncode(requestBody)}');

      // Make API call
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'xi-api-key': _apiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              console.log('Text-to-speech request timed out');
              throw TimeoutException(
                'TTS request timed out',
                const Duration(seconds: 30),
              );
            },
          );

      // Process response
      if (response.statusCode == 200) {
        console.log('Text-to-speech conversion successful');
        console.log('Audio data size: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        console.log('Text-to-speech API error: ${response.statusCode}');
        console.log('Error response: ${response.body}');
        return null;
      }
    } catch (e) {
      console.log('Error in text-to-speech conversion: $e');
      return null;
    }
  }

  /// Convert text to speech and save to file
  /// Returns the file path or null if conversion fails
  Future<String?> textToSpeechFile({
    required String text,
    required String outputPath,
    String voiceId = 'JBFqnCBsd6RMkjVDRZzb',
    String outputFormat = 'mp3_44100_128',
    String modelId = 'eleven_multilingual_v2',
  }) async {
    try {
      final audioBytes = await textToSpeech(
        text: text,
        voiceId: voiceId,
        outputFormat: outputFormat,
        modelId: modelId,
      );

      if (audioBytes == null) {
        console.log('Failed to generate audio from text');
        return null;
      }

      // Save audio bytes to file
      final file = File(outputPath);
      await file.writeAsBytes(audioBytes);

      console.log('Audio saved to: $outputPath');
      console.log('File size: ${await file.length()} bytes');

      return outputPath;
    } catch (e) {
      console.log('Error saving text-to-speech audio to file: $e');
      return null;
    }
  }

  /// Get available voices from Eleven Labs API
  Future<List<Map<String, dynamic>>?> getAvailableVoices() async {
    try {
      console.log('Fetching available voices from Eleven Labs');

      final uri = Uri.parse('$_elevenLabsEndpoint/voices');

      final response = await http
          .get(uri, headers: {'xi-api-key': _apiKey})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              console.log('Get voices request timed out');
              throw TimeoutException('Get voices request timed out');
            },
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final voices = jsonResponse['voices'] as List;

        console.log('Retrieved ${voices.length} voices');

        // Log voice information for debugging
        for (final voice in voices) {
          console.log('Voice: ${voice['name']} (${voice['voice_id']})');
        }

        return voices.cast<Map<String, dynamic>>();
      } else {
        console.log('Failed to get voices: ${response.statusCode}');
        console.log('Error response: ${response.body}');
        return null;
      }
    } catch (e) {
      console.log('Error fetching available voices: $e');
      return null;
    }
  }

  /// Check if we should use local fallback
  bool get shouldUseLocalFallback => _useLocalFallback;

  /// Get the local speech service for direct use
  LocalSpeechService get localSpeechService => _localSpeechService;
}
