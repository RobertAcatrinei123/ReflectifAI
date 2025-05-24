import 'dart:convert';
import 'dart:developer' as console;
import 'package:http/http.dart' as http;
import 'package:reflectifai/apikeys.dart';

class GeminiService {
  static const String apiKey = Apikeys.gemini;
  Future<String> getResponse(
    List<Map<String, String>> chat,
    List<Map<String, String>> instructions,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-04-17:generateContent?key=$apiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "system_instruction": {"parts": instructions},
      "contents":
          chat
              .map(
                (msg) => {
                  "role": msg["role"],
                  "parts": [
                    {"text": msg["content"]},
                  ],
                },
              )
              .toList(),
    });
    try {
      console.log("Sending request to Gemini API: $body");
      final response = await http.post(url, headers: headers, body: body);
      console.log("Received response from Gemini API: " + response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String assistantMessage =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return assistantMessage;
      } else {
        console.log('Gemini API error: ${response.body}');
        throw Exception(
          'Failed to get response: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      console.log('Error getting Gemini response: $e');
      return e.toString();
    }
  }

  Future<Map<String, dynamic>> getResponseold(
    List<Map<String, String>> chat,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "contents":
          chat
              .map(
                (msg) => {
                  "role": msg["role"],
                  "parts": [
                    {"text": msg["content"]},
                  ],
                },
              )
              .toList(),
    });
    try {
      console.log("Sending request to Gemini API: $body");
      final response = await http.post(url, headers: headers, body: body);
      console.log("Received response from Gemini API: " + response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String assistantMessage =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        String voice = assistantMessage.split('\n').first.trim();
        return {'text': assistantMessage, 'voice': voice};
      } else {
        console.log('Gemini API error: ${response.body}');
        throw Exception(
          'Failed to get response: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      console.log('Error getting Gemini response: $e');
      return {'error': e.toString()};
    }
  }
}
