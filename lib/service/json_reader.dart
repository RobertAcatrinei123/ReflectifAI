import 'dart:convert';
import 'dart:io';

class JsonReader {
  Future<String> getSystemInstructions(String filePath) async {
    // Load the system instructions from a JSON file
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

    final systemInstruction =
        jsonMap['system_instruction'] as Map<String, dynamic>?;
    if (systemInstruction != null) {
      final parts = systemInstruction['parts'] as List<dynamic>?;
      if (parts != null && parts.isNotEmpty) {
        final firstPart = parts[0] as Map<String, dynamic>?;
        if (firstPart != null) {
          return firstPart['text'] as String? ?? '';
        }
      }
    }
    return '';
  }
}

Future<String?> getKnowledgeGraph(String filePath) async {
  return File(filePath)
      .readAsString()
      .then((jsonString) {
        return jsonString;
      })
      .catchError((error) {
        print('Error reading knowledge graph: $error');
        return null;
      });
}
