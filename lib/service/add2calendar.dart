import 'package:add_2_calendar/add_2_calendar.dart';

void addEventToCalendar() {
  final Event event = Event(
    title: 'ReflectifAI Session',
    description: 'Voice agent design workshop',
    location: 'Transylvania Tech Hub',
    startDate: DateTime.now().add(Duration(minutes: 15)),
    endDate: DateTime.now().add(Duration(hours: 1)),
    iosParams: IOSParams(
      reminder: Duration(minutes: 10),
    ),
    androidParams: AndroidParams(
      emailInvites: [], // Optional
    ),
  );

  Add2Calendar.addEvent2Cal(event).then((success) {
    print(success ? '✅ Event added!' : '❌ Failed to add event');
  });
}