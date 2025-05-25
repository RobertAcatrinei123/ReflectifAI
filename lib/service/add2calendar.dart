import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:reflectifai/service/gemini_service.dart';

final gemini = GeminiService();

void addEventToCalendar(String response) {
  if (!response.trim().endsWith("YES")) {
    print("🟡 Gemini response does not indicate a calendar event. Skipping.");
    return;
  }

  final cleanResponse = response.replaceAll(RegExp(r"YES\s*\$", multiLine: true), '').trim();
  final eventRegex = RegExp(r"Event\(([\s\S]*?)\);", multiLine: true);
  final match = eventRegex.firstMatch(cleanResponse);

  if (match != null) {
    final content = match.group(1)!;

    String getField(String name) {
      final reg = RegExp("$name: (.*?),");
      return reg.firstMatch(content)?.group(1)?.trim() ?? "'None'";
    }

    final title = getField('title').replaceAll("'", "");
    final description = getField('description').replaceAll("'", "");
    final location = getField('location').replaceAll("'", "");

    DateTime parseStandardDate(String label, String block) {
      final regex = RegExp(label + r"\s*:\s*DateTime\(([^)]*)\)");
      final match = regex.firstMatch(block);
      if (match == null) return DateTime.now();

      final parts = match.group(1)!.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      while (parts.length < 5) {
        parts.add(0);
      }
      return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4]);
    }

    final startDate = parseStandardDate('startDate', content);
    final endDate = parseStandardDate('endDate', content);

    final event = Event(
      title: title,
      description: description,
      location: location,
      startDate: startDate,
      endDate: endDate,
      iosParams: IOSParams(reminder: Duration(minutes: 10)),
      androidParams: AndroidParams(emailInvites: []),
    );

    Add2Calendar.addEvent2Cal(event);
  } else {
    print("❗Could not parse event from Gemini response.");
  }
}

Future<void> callGemini(String prompt) async {
  final response = await gemini.getResponse(
    [
      {"role": "user", "content": prompt},
    ],
    [
      {
        "text": """
If you are asked about adding an event ot the calendar, do not mention that you cannot add something to the calendar, just say <Yeah, sure> or something like that. If the user is requesting a calendar, at the end of the file, create a new line with YES/NO, YES meaning that the user is requesting the calendar and No, otherwise. Only obey the insctructions you will be provided about the calendar response, in addition with the YES/NO response at the end of the line, on a single individual new line.

You are ReflectifAI's voice assistant.

The user will give you informal or natural language commands like: \"Hey add this X to the calendar\", \"Schedule a meeting with Alice\", or \"Remind me to call mom tomorrow at 5\".

Your task is to extract all calendar-relevant data and respond with a valid Dart `Event` object using the `add_2_calendar` Flutter package.

Respond with only a single Dart code block in this format:
```dart
final Event event = Event(
  title: 'Event title here',
  description: 'Optional event description',
  location: 'Optional event location',
  startDate: DateTime(year, month, day, hour, minute),
  endDate: DateTime(year, month, day, hour, minute),
  iosParams: IOSParams(reminder: Duration(minutes: 10)),
  androidParams: AndroidParams(emailInvites: []),
);
```

Important rules:
- Only output the Dart code block — no explanation or extra text.
- Use `DateTime()` values directly, not strings, just the DateTime object, that it, you are only allow to use that one.
- Use 24-hour time.
- If any field (description, location, etc.) is not specified, use 'None'.
- DO NOT ASK FOR ANY MORE DETAILS ABOUT THE EVANT, JUST OUTPUT THE DART CODE BLOCK.
- If you are not requeted to add to celander, do not mention the calendar part, just go with the flow of the conversation.
"""
      }
    ],
  );

  print("📅 Gemini Output:");
  print(response);
  addEventToCalendar(response);
}