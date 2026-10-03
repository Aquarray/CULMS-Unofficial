import 'dart:convert';

class LmsCalendarEvent {
  final int id;
  final String name;
  final String description;
  final int timesort;
  final String formattedTime;
  final String? courseName;
  final int? courseId;
  final String? actionName;
  final String? actionUrl;
  final String eventType;
  final String purpose;

  const LmsCalendarEvent({
    required this.id,
    required this.name,
    this.description = '',
    required this.timesort,
    required this.formattedTime,
    this.courseName,
    this.courseId,
    this.actionName,
    this.actionUrl,
    this.eventType = 'course',
    this.purpose = 'event',
  });

  DateTime get eventDateTime =>
      DateTime.fromMillisecondsSinceEpoch(timesort * 1000);

  bool get isUpcoming => eventDateTime.isAfter(DateTime.now());

  Duration get timeRemaining => eventDateTime.difference(DateTime.now());

  String get cleanFormattedTime {
    // Strip HTML tags from formattedTime if present
    return formattedTime.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  factory LmsCalendarEvent.fromJson(Map<String, dynamic> json) {
    String? cName;
    int? cId;
    if (json['course'] is Map) {
      cName = json['course']['fullname'] as String?;
      cId = (json['course']['id'] as num?)?.toInt();
    }

    String? aName;
    String? aUrl;
    if (json['action'] is Map) {
      aName = json['action']['name'] as String?;
      aUrl = json['action']['url'] as String?;
    }

    return LmsCalendarEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Event',
      description: json['description'] as String? ?? '',
      timesort: (json['timesort'] as num?)?.toInt() ?? 0,
      formattedTime: json['formattedtime'] as String? ?? '',
      courseName: cName,
      courseId: cId,
      actionName: aName,
      actionUrl: aUrl,
      eventType: json['normalisedeventtype'] as String? ?? 'course',
      purpose: json['purpose'] as String? ?? 'event',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'timesort': timesort,
      'formattedtime': formattedTime,
      'courseName': courseName,
      'courseId': courseId,
      'actionName': actionName,
      'actionUrl': actionUrl,
      'normalisedeventtype': eventType,
      'purpose': purpose,
    };
  }

  static List<LmsCalendarEvent> fromJsonList(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is List && decoded.isNotEmpty) {
        final data = decoded[0]['data'];
        if (data != null && data['events'] is List) {
          return (data['events'] as List)
              .map((e) => LmsCalendarEvent.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
