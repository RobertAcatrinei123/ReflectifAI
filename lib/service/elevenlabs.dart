import 'dart:async';
import 'dart:convert';
import 'dart:developer' as console;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:reflectifai/apikeys.dart';

class ElevenlabsService {
  // Eleven Labs API settings
  static const String _elevenLabsEndpoint = 'https://api.elevenlabs.io/v1';
  static const String _speechToTextApiPath = '/speech-to-text';

  // Replace with your Eleven Labs API key
  static const String _apiKey = Apikeys.elevenlabs;

  // Default model for transcription
  static const String _modelId = 'scribe_v1';

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
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          console.log('Request to Eleven Labs API timed out');
          throw TimeoutException('API request timed out');
        },
      );

      // Process the response
      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        console.log('Eleven Labs API response: $responseBody');

        final jsonResponse = jsonDecode(responseBody);

        // Extract text from response
        if (jsonResponse.containsKey('text')) {
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
}
