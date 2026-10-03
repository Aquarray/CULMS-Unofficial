class AssignmentTeacherFile {
  final String name;
  final String downloadUrl;
  final String fileType;

  const AssignmentTeacherFile({
    required this.name,
    required this.downloadUrl,
    this.fileType = 'unknown',
  });

  bool get isPdf =>
      fileType.toLowerCase() == 'pdf' || name.toLowerCase().endsWith('.pdf');

  Map<String, dynamic> toJson() => {
        'name': name,
        'downloadUrl': downloadUrl,
        'fileType': fileType,
      };

  factory AssignmentTeacherFile.fromJson(Map<String, dynamic> json) =>
      AssignmentTeacherFile(
        name: json['name'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        fileType: json['fileType'] as String? ?? 'unknown',
      );
}

class AssignmentSubmissionFile {
  final String name;
  final String downloadUrl;
  final String? timeModified;

  const AssignmentSubmissionFile({
    required this.name,
    required this.downloadUrl,
    this.timeModified,
  });

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  Map<String, dynamic> toJson() => {
        'name': name,
        'downloadUrl': downloadUrl,
        'timeModified': timeModified,
      };

  factory AssignmentSubmissionFile.fromJson(Map<String, dynamic> json) =>
      AssignmentSubmissionFile(
        name: json['name'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        timeModified: json['timeModified'] as String?,
      );
}

class DraftFileInfo {
  final String filename;
  final String? filesize;
  final String? url;
  final String? icon;

  const DraftFileInfo({
    required this.filename,
    this.filesize,
    this.url,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'filesize': filesize,
        'url': url,
        'icon': icon,
      };

  factory DraftFileInfo.fromJson(Map<String, dynamic> json) => DraftFileInfo(
        filename: json['filename'] as String? ?? json['name'] as String? ?? '',
        filesize: json['filesize']?.toString(),
        url: json['url'] as String?,
        icon: json['icon'] as String?,
      );
}

class AssignmentSubmissionConfig {
  final int assignId;
  final int itemId;
  final String clientId;
  final int maxBytes;
  final String maxBytesText;
  final int maxFiles;
  final List<String> acceptedTypes;
  final String? contextId;
  final String? author;
  final List<DraftFileInfo> draftFiles;
  final String formAction;
  final Map<String, String> hiddenFields;
  final bool hasExistingSubmission;

  const AssignmentSubmissionConfig({
    required this.assignId,
    required this.itemId,
    required this.clientId,
    this.maxBytes = 5242880,
    this.maxBytesText = '5.0 MB',
    this.maxFiles = 1,
    this.acceptedTypes = const [],
    this.contextId,
    this.author,
    this.draftFiles = const [],
    this.formAction = 'https://lms.cuchd.in/mod/assign/view.php',
    this.hiddenFields = const {},
    this.hasExistingSubmission = false,
  });

  AssignmentSubmissionConfig copyWith({
    List<DraftFileInfo>? draftFiles,
    String? formAction,
    Map<String, String>? hiddenFields,
    bool? hasExistingSubmission,
  }) =>
      AssignmentSubmissionConfig(
        assignId: assignId,
        itemId: itemId,
        clientId: clientId,
        maxBytes: maxBytes,
        maxBytesText: maxBytesText,
        maxFiles: maxFiles,
        acceptedTypes: acceptedTypes,
        contextId: contextId,
        author: author,
        draftFiles: draftFiles ?? this.draftFiles,
        formAction: formAction ?? this.formAction,
        hiddenFields: hiddenFields ?? this.hiddenFields,
        hasExistingSubmission:
            hasExistingSubmission ?? this.hasExistingSubmission,
      );

  Map<String, dynamic> toJson() => {
        'assignId': assignId,
        'itemId': itemId,
        'clientId': clientId,
        'maxBytes': maxBytes,
        'maxBytesText': maxBytesText,
        'maxFiles': maxFiles,
        'acceptedTypes': acceptedTypes,
        'contextId': contextId,
        'author': author,
        'draftFiles': draftFiles.map((f) => f.toJson()).toList(),
        'formAction': formAction,
        'hiddenFields': hiddenFields,
        'hasExistingSubmission': hasExistingSubmission,
      };

  factory AssignmentSubmissionConfig.fromJson(Map<String, dynamic> json) =>
      AssignmentSubmissionConfig(
        assignId: json['assignId'] as int? ?? 0,
        itemId: json['itemId'] as int? ?? 0,
        clientId: json['clientId'] as String? ?? '',
        maxBytes: json['maxBytes'] as int? ?? 5242880,
        maxBytesText: json['maxBytesText'] as String? ?? '5.0 MB',
        maxFiles: json['maxFiles'] as int? ?? 1,
        acceptedTypes: (json['acceptedTypes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        contextId: json['contextId']?.toString(),
        author: json['author'] as String?,
        draftFiles: (json['draftFiles'] as List<dynamic>?)
                ?.map((e) => DraftFileInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        formAction: json['formAction'] as String? ??
            'https://lms.cuchd.in/mod/assign/view.php',
        hiddenFields: (json['hiddenFields'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
        hasExistingSubmission:
            json['hasExistingSubmission'] as bool? ?? false,
      );
}

class AssignmentDetail {
  final int id;
  final String name;
  final String? courseName;
  final String? openDate;
  final String? dueDate;
  final String? instructionsHtml;
  final String? instructionsText;
  final List<AssignmentTeacherFile> teacherFiles;
  final String? submissionStatus;
  final String? gradingStatus;
  final String? timeRemaining;
  final String? lastModified;
  final List<AssignmentSubmissionFile> submittedFiles;
  final bool canEditSubmission;
  final bool canRemoveSubmission;
  final String? editButtonLabel;
  final int submissionCommentsCount;
  final String? feedbackGrade;
  final String? feedbackGradedOn;
  final String? feedbackGradedBy;
  final String? feedbackComments;
  final Map<String, String> extraStatusFields;
  final String? moodleUserId;
  final DateTime fetchedAt;

  const AssignmentDetail({
    required this.id,
    required this.name,
    this.courseName,
    this.openDate,
    this.dueDate,
    this.instructionsHtml,
    this.instructionsText,
    this.teacherFiles = const [],
    this.submissionStatus,
    this.gradingStatus,
    this.timeRemaining,
    this.lastModified,
    this.submittedFiles = const [],
    this.canEditSubmission = false,
    this.canRemoveSubmission = false,
    this.editButtonLabel,
    this.submissionCommentsCount = 0,
    this.feedbackGrade,
    this.feedbackGradedOn,
    this.feedbackGradedBy,
    this.feedbackComments,
    this.extraStatusFields = const {},
    this.moodleUserId,
    required this.fetchedAt,
  });

  bool get isSubmitted =>
      submissionStatus != null &&
      (submissionStatus!.toLowerCase().contains('submitted') ||
          submittedFiles.isNotEmpty);

  bool get isGraded =>
      gradingStatus != null &&
      gradingStatus!.toLowerCase().contains('graded') &&
      !gradingStatus!.toLowerCase().contains('not graded');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'courseName': courseName,
        'openDate': openDate,
        'dueDate': dueDate,
        'instructionsHtml': instructionsHtml,
        'instructionsText': instructionsText,
        'teacherFiles': teacherFiles.map((f) => f.toJson()).toList(),
        'submissionStatus': submissionStatus,
        'gradingStatus': gradingStatus,
        'timeRemaining': timeRemaining,
        'lastModified': lastModified,
        'submittedFiles': submittedFiles.map((f) => f.toJson()).toList(),
        'canEditSubmission': canEditSubmission,
        'canRemoveSubmission': canRemoveSubmission,
        'editButtonLabel': editButtonLabel,
        'submissionCommentsCount': submissionCommentsCount,
        'feedbackGrade': feedbackGrade,
        'feedbackGradedOn': feedbackGradedOn,
        'feedbackGradedBy': feedbackGradedBy,
        'feedbackComments': feedbackComments,
        'extraStatusFields': extraStatusFields,
        'moodleUserId': moodleUserId,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory AssignmentDetail.fromJson(Map<String, dynamic> json) =>
      AssignmentDetail(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? 'Assignment',
        courseName: json['courseName'] as String?,
        openDate: json['openDate'] as String?,
        dueDate: json['dueDate'] as String?,
        instructionsHtml: json['instructionsHtml'] as String?,
        instructionsText: json['instructionsText'] as String?,
        teacherFiles: (json['teacherFiles'] as List<dynamic>?)
                ?.map((e) =>
                    AssignmentTeacherFile.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        submissionStatus: json['submissionStatus'] as String?,
        gradingStatus: json['gradingStatus'] as String?,
        timeRemaining: json['timeRemaining'] as String?,
        lastModified: json['lastModified'] as String?,
        submittedFiles: (json['submittedFiles'] as List<dynamic>?)
                ?.map((e) => AssignmentSubmissionFile.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
        canEditSubmission: json['canEditSubmission'] as bool? ?? false,
        canRemoveSubmission: json['canRemoveSubmission'] as bool? ?? false,
        editButtonLabel: json['editButtonLabel'] as String?,
        submissionCommentsCount:
            json['submissionCommentsCount'] as int? ?? 0,
        feedbackGrade: json['feedbackGrade'] as String?,
        feedbackGradedOn: json['feedbackGradedOn'] as String?,
        feedbackGradedBy: json['feedbackGradedBy'] as String?,
        feedbackComments: json['feedbackComments'] as String?,
        extraStatusFields: (json['extraStatusFields'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            const {},
        moodleUserId: json['moodleUserId'] as String?,
        fetchedAt: json['fetchedAt'] != null
            ? DateTime.tryParse(json['fetchedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
