
enum LmsItemType {
  singleDocument,
  folderDirectory,
  pageContent,
  externalUrl,
  quiz,
  assignment,
  unknown,
}

class LmsContentItem {
  final String name;
  final String? viewerUrl;
  final String? downloadUrl;
  final String fileType; // pdf, pptx, docx, etc.
  final String? description;
  final String? rawHtml;

  const LmsContentItem({
    required this.name,
    this.viewerUrl,
    this.downloadUrl,
    this.fileType = 'unknown',
    this.description,
    this.rawHtml,
  });

  bool get isPdf =>
      fileType.toLowerCase() == 'pdf' ||
      (viewerUrl != null && viewerUrl!.contains('pdf.php')) ||
      (downloadUrl != null && downloadUrl!.toLowerCase().contains('.pdf'));

  bool get isOfficeDoc =>
      ['docx', 'doc', 'pptx', 'ppt', 'xlsx', 'xls'].contains(fileType.toLowerCase()) ||
      (viewerUrl != null && viewerUrl!.contains('officeviewer'));

  bool get isMarkdown =>
      fileType.toLowerCase() == 'md' ||
      fileType.toLowerCase() == 'markdown' ||
      (downloadUrl != null && downloadUrl!.toLowerCase().endsWith('.md'));

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'viewerUrl': viewerUrl,
      'downloadUrl': downloadUrl,
      'fileType': fileType,
      'description': description,
      'rawHtml': rawHtml,
    };
  }

  factory LmsContentItem.fromJson(Map<String, dynamic> json) {
    return LmsContentItem(
      name: json['name'] as String? ?? 'Untitled',
      viewerUrl: json['viewerUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      fileType: json['fileType'] as String? ?? 'unknown',
      description: json['description'] as String?,
      rawHtml: json['rawHtml'] as String?,
    );
  }
}

enum CourseSectionCategory {
  overview,
  theory,
  practical,
  assessmentModel,
  liveSessions,
  surpriseTest,
  quiz,
  assignment;

  String get label {
    switch (this) {
      case CourseSectionCategory.overview:
        return 'Overview';
      case CourseSectionCategory.theory:
        return 'Theory';
      case CourseSectionCategory.practical:
        return 'Practical';
      case CourseSectionCategory.assessmentModel:
        return 'Assessment Model';
      case CourseSectionCategory.liveSessions:
        return 'Live Session Links';
      case CourseSectionCategory.surpriseTest:
        return 'Surprise Test';
      case CourseSectionCategory.quiz:
        return 'Quiz';
      case CourseSectionCategory.assignment:
        return 'Assignments';
    }
  }
}

class CourseUnit {
  final String id;
  final String title;
  final String? summary;
  final String? sectionUrl;
  final List<CourseActivity> activities;
  final int sectionNumber;
  final CourseSectionCategory category;
  final String parentUnit;

  const CourseUnit({
    required this.id,
    required this.title,
    this.summary,
    this.sectionUrl,
    this.activities = const [],
    this.sectionNumber = 0,
    this.category = CourseSectionCategory.theory,
    this.parentUnit = 'General',
  });

  bool get isTheory => category == CourseSectionCategory.theory;
  bool get isPractical => category == CourseSectionCategory.practical;
  bool get isOverview => category == CourseSectionCategory.overview;
  bool get isAssessmentModel => category == CourseSectionCategory.assessmentModel;
  bool get isLiveSessions => category == CourseSectionCategory.liveSessions;
  bool get isSurpriseTest => category == CourseSectionCategory.surpriseTest;
  bool get isQuiz => category == CourseSectionCategory.quiz;
  bool get isAssignment => category == CourseSectionCategory.assignment;
  bool get isHeaderOnly => activities.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'sectionUrl': sectionUrl,
      'sectionNumber': sectionNumber,
      'category': category.name,
      'parentUnit': parentUnit,
      'activities': activities.map((a) => a.toJson()).toList(),
    };
  }

  factory CourseUnit.fromJson(Map<String, dynamic> json) {
    final catName = json['category'] as String?;
    final title = json['title'] as String? ?? 'Unit';
    final secNum = (json['sectionNumber'] as num?)?.toInt() ?? 0;

    final category = CourseSectionCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => resolveCategory(title, secNum),
    );

    final parent = json['parentUnit'] as String? ?? resolveParentUnit(title, secNum);

    return CourseUnit(
      id: json['id'] as String? ?? '',
      title: title,
      summary: json['summary'] as String?,
      sectionUrl: json['sectionUrl'] as String?,
      sectionNumber: secNum,
      category: category,
      parentUnit: parent,
      activities: (json['activities'] as List<dynamic>?)
              ?.map((a) => CourseActivity.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static CourseSectionCategory resolveCategory(String title, int secNumber) {
    final lower = title.toLowerCase();
    if (lower.contains('surprise test') || lower.contains('surprise')) {
      return CourseSectionCategory.surpriseTest;
    }
    if (lower.contains('quiz') || lower.contains('quizzes')) {
      return CourseSectionCategory.quiz;
    }
    if (lower.contains('live session') ||
        lower.contains('session link') ||
        lower.contains('meeting') ||
        lower.contains('live class')) {
      return CourseSectionCategory.liveSessions;
    }
    if (lower.contains('assessment model') ||
        lower.contains('evaluation scheme') ||
        lower.contains('assessment scheme')) {
      return CourseSectionCategory.assessmentModel;
    }
    if (lower.contains('assignment') || lower.contains('submission')) {
      return CourseSectionCategory.assignment;
    }
    if (lower.contains('practical') || lower.contains('experiment') || lower.contains('lab')) {
      return CourseSectionCategory.practical;
    }
    if (secNumber == 0 ||
        lower.contains('overview') ||
        lower.contains('general') ||
        lower.contains('getting started') ||
        lower == 'announcements') {
      return CourseSectionCategory.overview;
    }
    return CourseSectionCategory.theory;
  }

  static String resolveParentUnit(String title, int secNumber) {
    final lower = title.toLowerCase();
    if (lower.contains('surprise test') || lower.contains('surprise')) {
      return 'Surprise Tests';
    }
    if (lower.contains('quiz') || lower.contains('quizzes')) {
      return 'Quizzes & MSTs';
    }
    if (lower.contains('live session') || lower.contains('session link') || lower.contains('meeting')) {
      return 'Live Session Links';
    }
    if (lower.contains('assessment model')) {
      return 'Assessment Model';
    }
    if (lower.contains('assignment') || lower.contains('submission')) {
      return 'Assignments';
    }
    if (secNumber == 0 || lower.contains('overview') || lower.contains('general') || lower == 'announcements') {
      return 'Course Overview';
    }

    final isPrac = lower.contains('practical') || lower.contains('experiment') || lower.contains('lab');
    final match = RegExp(r'(?:unit|chapter|experiment|exp)[\s\-_]*(\d+)', caseSensitive: false).firstMatch(title);
    if (match != null) {
      final numStr = match.group(1);
      return isPrac ? 'Practical Unit $numStr' : 'Unit $numStr';
    }

    return isPrac ? 'Practicals & Labs' : 'Theory Chapters';
  }
}

class CourseActivity {
  final String id;
  final String name;
  final String typeName; // File, Page, Folder, Forum, Quiz, Assign
  final String url;
  final String iconType;

  const CourseActivity({
    required this.id,
    required this.name,
    required this.typeName,
    required this.url,
    this.iconType = 'file',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'typeName': typeName,
      'url': url,
      'iconType': iconType,
    };
  }

  factory CourseActivity.fromJson(Map<String, dynamic> json) {
    return CourseActivity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      typeName: json['typeName'] as String? ?? '',
      url: json['url'] as String? ?? '',
      iconType: json['iconType'] as String? ?? 'file',
    );
  }
}

class LmsExtractedContent {
  final String pageTitle;
  final LmsItemType type;
  final List<LmsContentItem> items;
  final String? pageBodyHtml;
  final String? originalUrl;

  const LmsExtractedContent({
    required this.pageTitle,
    required this.type,
    required this.items,
    this.pageBodyHtml,
    this.originalUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'pageTitle': pageTitle,
      'type': type.name,
      'items': items.map((i) => i.toJson()).toList(),
      'pageBodyHtml': pageBodyHtml,
      'originalUrl': originalUrl,
    };
  }

  factory LmsExtractedContent.fromJson(Map<String, dynamic> json) {
    return LmsExtractedContent(
      pageTitle: json['pageTitle'] as String? ?? 'Content',
      type: LmsItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LmsItemType.unknown,
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => LmsContentItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      pageBodyHtml: json['pageBodyHtml'] as String?,
      originalUrl: json['originalUrl'] as String?,
    );
  }
}
