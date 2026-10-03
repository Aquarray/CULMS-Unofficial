import 'dart:convert';

class Course {
  final int id;
  final String fullname;
  final String shortname;
  final String viewurl;
  final String? courseimage;
  final int progress;
  final bool hasprogress;
  final bool isfavourite;
  final bool hidden;
  final String coursecategory;
  final int startdate;
  final int enddate;

  const Course({
    required this.id,
    required this.fullname,
    required this.shortname,
    required this.viewurl,
    this.courseimage,
    this.progress = 0,
    this.hasprogress = false,
    this.isfavourite = false,
    this.hidden = false,
    this.coursecategory = '',
    this.startdate = 0,
    this.enddate = 0,
  });

  String get cleanTitle {
    // E.g. "CONT_23CST-441 :: RESEARCH METHODOLOGY" -> "RESEARCH METHODOLOGY"
    if (fullname.contains('::')) {
      final parts = fullname.split('::');
      return parts.length > 1 ? parts[1].trim() : fullname;
    }
    return fullname;
  }

  String get courseCode {
    // E.g. "CONT_23CST-441 :: RESEARCH METHODOLOGY" -> "23CST-441"
    if (fullname.contains('::')) {
      var code = fullname.split('::').first.trim();
      code = code.replaceFirst('CONT_', '').replaceFirst('SEC_', '');
      return code;
    }
    return shortname;
  }

  /// Whether this course is dedicated to study content (lecture slides, notes, readings)
  bool get isContentCourse =>
      shortname.startsWith('CONT_') || fullname.startsWith('CONT_');

  /// Whether this course is dedicated to assessments, quizzes, MSTs, and assignments
  bool get isAssessmentCourse => !isContentCourse;

  /// User-friendly badge label
  String get courseTypeLabel => isContentCourse ? 'Study Material' : 'Tests & MSTs';

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullname: json['fullname'] as String? ?? 'Untitled Course',
      shortname: json['shortname'] as String? ?? '',
      viewurl: json['viewurl'] as String? ?? '',
      courseimage: json['courseimage'] as String?,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      hasprogress: json['hasprogress'] as bool? ?? false,
      isfavourite: json['isfavourite'] as bool? ?? false,
      hidden: json['hidden'] as bool? ?? false,
      coursecategory: json['coursecategory'] as String? ?? '',
      startdate: (json['startdate'] as num?)?.toInt() ?? 0,
      enddate: (json['enddate'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullname': fullname,
      'shortname': shortname,
      'viewurl': viewurl,
      'courseimage': courseimage,
      'progress': progress,
      'hasprogress': hasprogress,
      'isfavourite': isfavourite,
      'hidden': hidden,
      'coursecategory': coursecategory,
      'startdate': startdate,
      'enddate': enddate,
    };
  }

  static List<Course> fromJsonList(String jsonString) {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is List && decoded.isNotEmpty) {
        final data = decoded[0]['data'];
        if (data != null && data['courses'] is List) {
          return (data['courses'] as List)
              .map((c) => Course.fromJson(c as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
