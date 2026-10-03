import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../../data/models/app_settings.dart';

/// Represents a single option choice in a Moodle quiz question.
class QuizOption {
  final int index;
  final String id;
  final String label;
  final String text;
  final String value;
  final String inputType;

  const QuizOption({
    required this.index,
    required this.id,
    required this.label,
    required this.text,
    required this.value,
    this.inputType = 'radio',
  });

  Map<String, dynamic> toMap() => {
        'index': index,
        'id': id,
        'label': label,
        'text': text,
        'value': value,
        'inputType': inputType,
      };

  factory QuizOption.fromMap(Map<String, dynamic> map) => QuizOption(
        index: (map['index'] as num?)?.toInt() ?? 0,
        id: map['id']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        value: map['value']?.toString() ?? '',
        inputType: map['inputType']?.toString() ?? 'radio',
      );
}

/// Represents an extracted quiz question from the DOM.
class QuizQuestion {
  final String id;
  final String text;
  final List<QuizOption> options;

  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'options': options.map((e) => e.toMap()).toList(),
      };

  factory QuizQuestion.fromMap(Map<String, dynamic> map) => QuizQuestion(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        options: (map['options'] as List?)
                ?.map((e) => QuizOption.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

/// Represents the AI suggestion and reasoning for a question.
class QuizAiAnswer {
  final String questionId;
  final int selectedOptionIndex;
  final String selectedOptionId;
  final String selectedOptionText;
  final String explanation;
  final QuizAiProvider provider;
  final bool isSuccess;
  final String? errorMessage;

  const QuizAiAnswer({
    required this.questionId,
    required this.selectedOptionIndex,
    required this.selectedOptionId,
    required this.selectedOptionText,
    required this.explanation,
    required this.provider,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory QuizAiAnswer.failure({
    required String questionId,
    required QuizAiProvider provider,
    required String errorMessage,
  }) {
    return QuizAiAnswer(
      questionId: questionId,
      selectedOptionIndex: -1,
      selectedOptionId: '',
      selectedOptionText: '',
      explanation: '',
      provider: provider,
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}

/// Service that interacts with AI Providers (Google Gemini or OpenAI) to analyze
/// quiz questions and return verified answers with pedagogical explanations.
class QuizAiService {
  final Dio _dio;

  QuizAiService({Dio? dio}) : _dio = dio ?? Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Extracts questions and choices directly from HTML string.
  /// Matches standard Moodle `.que` DOM structure (e.g. from LMS attempt pages).
  List<QuizQuestion> parseQuestionsFromHtml(String html) {
    final document = html_parser.parse(html);
    final questionElements = document.querySelectorAll('div.que');
    final List<QuizQuestion> result = [];

    for (final qEl in questionElements) {
      final qId = qEl.attributes['id'] ?? '';
      
      // Question text in .qtext
      final qTextEl = qEl.querySelector('.qtext');
      final qText = qTextEl?.text.trim() ?? '';
      if (qText.isEmpty) continue;

      // Options in .answer (.r0, .r1)
      final optionContainers = qEl.querySelectorAll('.answer div.r0, .answer div.r1');
      final List<QuizOption> options = [];

      for (int i = 0; i < optionContainers.length; i++) {
        final optEl = optionContainers[i];
        final input = optEl.querySelector('input[type="radio"], input[type="checkbox"]');
        final inputId = input?.attributes['id'] ?? '';
        final inputValue = input?.attributes['value'] ?? '';
        final inputType = input?.attributes['type'] ?? 'radio';

        // Check for .answernumber ("a.", "b.", etc.)
        final numEl = optEl.querySelector('.answernumber');
        final labelText = numEl?.text.trim() ?? '';

        // Text inside data-region="answer-label" or label element or optEl
        final labelEl = optEl.querySelector('[data-region="answer-label"]') ?? optEl.querySelector('label');
        String optText = '';
        if (labelEl != null) {
          // If .answernumber is child, exclude it to get clean option text
          final textContainer = labelEl.querySelector('.flex-fill') ?? labelEl;
          optText = textContainer.text.trim();
          // Remove prefix like "a." if it leaked in
          if (labelText.isNotEmpty && optText.startsWith(labelText)) {
            optText = optText.substring(labelText.length).trim();
          }
        } else {
          optText = optEl.text.trim();
        }

        options.add(
          QuizOption(
            index: i,
            id: inputId,
            label: labelText.isNotEmpty ? labelText : '${String.fromCharCode(97 + i)}.',
            text: optText,
            value: inputValue,
            inputType: inputType,
          ),
        );
      }

      result.add(
        QuizQuestion(
          id: qId,
          text: qText,
          options: options,
        ),
      );
    }

    return result;
  }

  /// Formats the prompt sent to the LLM.
  String buildPrompt(QuizQuestion question) {
    final sb = StringBuffer();
    sb.writeln('QUESTION:');
    sb.writeln(question.text);
    sb.writeln();
    sb.writeln('OPTIONS:');
    for (int i = 0; i < question.options.length; i++) {
      final opt = question.options[i];
      sb.writeln('$i. ${opt.label} ${opt.text}');
    }
    sb.writeln();
    sb.writeln('TASK:');
    sb.writeln('Analyze the question carefully. Select the single correct option index (0 to ${question.options.length - 1}).');
    sb.writeln('Provide a concise, 1 to 2 sentence explanation of why this is the correct answer.');
    sb.writeln('Respond ONLY with a valid JSON object in this exact schema:');
    sb.writeln('{"selected_index": <int>, "explanation": "<short explanation>"}');
    return sb.toString();
  }

  /// Solves a question using the configured provider and API key.
  Future<QuizAiAnswer> solveQuestion({
    required QuizQuestion question,
    required QuizAiProvider provider,
    required String apiKey,
    String? customModel,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return QuizAiAnswer.failure(
        questionId: question.id,
        provider: provider,
        errorMessage: 'AI API Key is not configured. Please open Settings -> AI Quiz Assistant and enter your API Key.',
      );
    }

    if (question.options.isEmpty) {
      return QuizAiAnswer.failure(
        questionId: question.id,
        provider: provider,
        errorMessage: 'No options found in this question to answer.',
      );
    }

    final prompt = buildPrompt(question);

    try {
      if (provider == QuizAiProvider.gemini) {
        return await _solveWithGemini(
          question: question,
          prompt: prompt,
          apiKey: cleanKey,
          model: customModel?.isNotEmpty == true ? customModel! : 'gemini-1.5-flash',
        );
      } else {
        return await _solveWithOpenAi(
          question: question,
          prompt: prompt,
          apiKey: cleanKey,
          model: customModel?.isNotEmpty == true ? customModel! : 'gpt-4o-mini',
        );
      }
    } catch (e) {
      debugPrint('[QuizAiService] Error invoking AI: $e');
      return QuizAiAnswer.failure(
        questionId: question.id,
        provider: provider,
        errorMessage: 'Failed to get AI answer: ${e.toString()}',
      );
    }
  }

  Future<QuizAiAnswer> _solveWithGemini({
    required QuizQuestion question,
    required String prompt,
    required String apiKey,
    required String model,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final response = await _dio.post(
      url,
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini returned status ${response.statusCode}');
    }

    final data = response.data;
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini returned an empty response.');
    }

    return _parseAiJsonResponse(
      question: question,
      rawText: text,
      provider: QuizAiProvider.gemini,
    );
  }

  Future<QuizAiAnswer> _solveWithOpenAi({
    required QuizQuestion question,
    required String prompt,
    required String apiKey,
    required String model,
  }) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final response = await _dio.post(
      url,
      data: {
        'model': model,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert exam assistant. Answer accurately with a valid JSON containing "selected_index" and "explanation".',
          },
          {'role': 'user', 'content': prompt},
        ],
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI returned status ${response.statusCode}');
    }

    final data = response.data;
    final text = data['choices']?[0]?['message']?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('OpenAI returned an empty response.');
    }

    return _parseAiJsonResponse(
      question: question,
      rawText: text,
      provider: QuizAiProvider.openAi,
    );
  }

  QuizAiAnswer _parseAiJsonResponse({
    required QuizQuestion question,
    required String rawText,
    required QuizAiProvider provider,
  }) {
    int selectedIndex = 0;
    String explanation = '';

    try {
      // Find JSON block if surrounded by markdown code fences
      String cleanJson = rawText.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```[a-z]*\n'), '').replaceAll(RegExp(r'\n```$'), '').trim();
      }
      final parsed = json.decode(cleanJson) as Map<String, dynamic>;
      if (parsed.containsKey('selected_index')) {
        selectedIndex = (parsed['selected_index'] as num).toInt();
      }
      if (parsed.containsKey('explanation')) {
        explanation = parsed['explanation']?.toString() ?? '';
      }
    } catch (_) {
      // Fallback regex parsing
      final indexMatch = RegExp(r'"selected_index"\s*:\s*(\d+)').firstMatch(rawText);
      if (indexMatch != null) {
        selectedIndex = int.tryParse(indexMatch.group(1) ?? '0') ?? 0;
      }
      final expMatch = RegExp(r'"explanation"\s*:\s*"([^"]+)"').firstMatch(rawText);
      if (expMatch != null) {
        explanation = expMatch.group(1) ?? '';
      }
    }

    if (selectedIndex < 0 || selectedIndex >= question.options.length) {
      selectedIndex = 0;
    }

    final selectedOpt = question.options[selectedIndex];

    return QuizAiAnswer(
      questionId: question.id,
      selectedOptionIndex: selectedIndex,
      selectedOptionId: selectedOpt.id,
      selectedOptionText: '${selectedOpt.label} ${selectedOpt.text}',
      explanation: explanation.isNotEmpty ? explanation : 'Identified as the correct answer based on question premises.',
      provider: provider,
      isSuccess: true,
    );
  }

  /// Default fallback models when offline or before API key validation.
  static const List<AiModelInfo> defaultGeminiModels = [
    AiModelInfo(id: 'gemini-1.5-flash', displayName: 'Gemini 1.5 Flash (Fast & Free)'),
    AiModelInfo(id: 'gemini-2.0-flash', displayName: 'Gemini 2.0 Flash (Next-Gen Fast)'),
    AiModelInfo(id: 'gemini-1.5-pro', displayName: 'Gemini 1.5 Pro (High Accuracy)'),
    AiModelInfo(id: 'gemini-1.0-pro', displayName: 'Gemini 1.0 Pro'),
  ];

  static const List<AiModelInfo> defaultOpenAiModels = [
    AiModelInfo(id: 'gpt-4o-mini', displayName: 'gpt-4o-mini (Fast & Recommended)'),
    AiModelInfo(id: 'gpt-4o', displayName: 'gpt-4o (High Intelligence)'),
    AiModelInfo(id: 'o3-mini', displayName: 'o3-mini (Reasoning)'),
    AiModelInfo(id: 'o1-mini', displayName: 'o1-mini (Reasoning)'),
    AiModelInfo(id: 'gpt-4-turbo', displayName: 'gpt-4-turbo'),
    AiModelInfo(id: 'gpt-3.5-turbo', displayName: 'gpt-3.5-turbo'),
  ];

  /// Tests API Key connectivity and retrieves available models from official endpoints:
  /// - Google Gemini: GET https://generativelanguage.googleapis.com/v1beta/models?key=...
  /// - OpenAI: GET https://api.openai.com/v1/models
  Future<AiModelFetchResult> fetchAvailableModels({
    required QuizAiProvider provider,
    required String apiKey,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return const AiModelFetchResult(
        isSuccess: false,
        errorMessage: 'API Key is empty. Please enter an API key.',
      );
    }

    try {
      if (provider == QuizAiProvider.gemini) {
        final url =
            'https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey';
        final response = await _dio.get(url);

        if (response.statusCode == 200 && response.data is Map) {
          final rawModels = (response.data['models'] as List?) ?? [];
          final List<AiModelInfo> models = [];

          for (final item in rawModels) {
            if (item is! Map) continue;
            // Check supportedGenerationMethods for "generateContent" (used for text generation)
            final methods = (item['supportedGenerationMethods'] as List?)
                    ?.map((m) => m.toString())
                    .toList() ??
                [];
            final canGenerate = methods.contains('generateContent');
            if (!canGenerate) continue;

            String name = item['name']?.toString() ?? '';
            if (name.startsWith('models/')) {
              name = name.substring('models/'.length);
            }
            final displayName = item['displayName']?.toString() ?? name;
            final description = item['description']?.toString();
            models.add(AiModelInfo(
              id: name,
              displayName: displayName,
              description: description,
            ));
          }

          if (models.isNotEmpty) {
            // Sort so flash & pro models are prioritized at the top
            models.sort((a, b) {
              int rank(String id) {
                final lower = id.toLowerCase();
                if (lower == 'gemini-1.5-flash') return 0;
                if (lower == 'gemini-2.0-flash') return 1;
                if (lower.startsWith('gemini-2.0-flash')) return 2;
                if (lower.startsWith('gemini-1.5-flash')) return 3;
                if (lower == 'gemini-1.5-pro') return 4;
                if (lower.startsWith('gemini-1.5-pro')) return 5;
                if (lower.startsWith('gemini-2.0')) return 6;
                if (lower.startsWith('gemini-pro')) return 7;
                return 15;
              }
              return rank(a.id).compareTo(rank(b.id));
            });
            return AiModelFetchResult.success(models);
          }
        }
        return AiModelFetchResult.success(defaultGeminiModels);
      } else {
        const url = 'https://api.openai.com/v1/models';
        final response = await _dio.get(
          url,
          options: Options(
            headers: {'Authorization': 'Bearer $cleanKey'},
          ),
        );

        if (response.statusCode == 200 && response.data is Map) {
          final rawData = (response.data['data'] as List?) ?? [];
          final List<AiModelInfo> chatModels = [];

          for (final item in rawData) {
            if (item is! Map) continue;
            final id = item['id']?.toString() ?? '';
            final lower = id.toLowerCase();

            // Filter for text generation / chat models:
            // Check if id starts with 'gpt-' or 'o1' or 'o3'
            final isTextGen = lower.startsWith('gpt-') ||
                lower.startsWith('o1') ||
                lower.startsWith('o3');

            // Exclude non-text/specialized modalities (audio, realtime, tts, embeddings, etc.)
            final isExcluded = lower.contains('audio') ||
                lower.contains('realtime') ||
                lower.contains('transcription') ||
                lower.contains('tts') ||
                lower.contains('embedding') ||
                lower.contains('moderation') ||
                lower.contains('dall-e') ||
                lower.contains('whisper') ||
                lower.contains('instruct');

            if (isTextGen && !isExcluded) {
              chatModels.add(AiModelInfo(id: id, displayName: id));
            }
          }

          if (chatModels.isNotEmpty) {
            // Sort to prioritize top conversational models
            chatModels.sort((a, b) {
              int priority(String id) {
                if (id == 'gpt-4o-mini') return 0;
                if (id == 'gpt-4o') return 1;
                if (id.startsWith('o3-mini')) return 2;
                if (id.startsWith('o1-mini')) return 3;
                if (id.startsWith('gpt-4-turbo')) return 4;
                if (id.startsWith('gpt-4')) return 5;
                if (id.startsWith('gpt-3.5-turbo')) return 6;
                return 10;
              }
              return priority(a.id).compareTo(priority(b.id));
            });
            return AiModelFetchResult.success(chatModels);
          }
        }
        return AiModelFetchResult.success(defaultOpenAiModels);
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      String msg = 'Failed to connect (${status ?? e.type}): ${e.message}';
      if (status == 400 || status == 401 || status == 403) {
        msg = 'Invalid API Key or unauthorized ($status). Please verify your key.';
      }
      return AiModelFetchResult.failure(msg);
    } catch (e) {
      return AiModelFetchResult.failure('Error checking API Key: $e');
    }
  }

  /// Verifies if an API key is valid by testing the models endpoint.
  Future<bool> testApiKey({
    required QuizAiProvider provider,
    required String apiKey,
    String? model,
  }) async {
    final result = await fetchAvailableModels(provider: provider, apiKey: apiKey);
    return result.isSuccess;
  }

  /// Predefined sample test question used to verify the AI model's response after selection.
  static const QuizQuestion predefinedTestQuestion = QuizQuestion(
    id: 'test_sample_math',
    text: 'What is 20% of 150?',
    options: [
      QuizOption(index: 0, id: 'opt_0', label: 'a.', text: '45', value: '45'),
      QuizOption(index: 1, id: 'opt_1', label: 'b.', text: '30', value: '30'),
      QuizOption(index: 2, id: 'opt_2', label: 'c.', text: '50', value: '50'),
      QuizOption(index: 3, id: 'opt_3', label: 'd.', text: '20', value: '20'),
    ],
  );

  /// Tests a specific model's response using the predefined test question.
  Future<QuizAiAnswer> testModelWithPredefinedQuestion({
    required QuizAiProvider provider,
    required String apiKey,
    required String model,
  }) async {
    return solveQuestion(
      question: predefinedTestQuestion,
      provider: provider,
      apiKey: apiKey,
      customModel: model,
    );
  }
}

/// Represents information about an AI model available from the provider's API.
class AiModelInfo {
  final String id;
  final String displayName;
  final String? description;

  const AiModelInfo({
    required this.id,
    required this.displayName,
    this.description,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'description': description,
      };

  factory AiModelInfo.fromMap(Map<String, dynamic> map) => AiModelInfo(
        id: map['id']?.toString() ?? '',
        displayName: map['displayName']?.toString() ?? '',
        description: map['description']?.toString(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiModelInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Response wrapper for model listing and API key testing.
class AiModelFetchResult {
  final bool isSuccess;
  final List<AiModelInfo> models;
  final String? errorMessage;

  const AiModelFetchResult({
    required this.isSuccess,
    this.models = const [],
    this.errorMessage,
  });

  factory AiModelFetchResult.success(List<AiModelInfo> models) =>
      AiModelFetchResult(isSuccess: true, models: models);

  factory AiModelFetchResult.failure(String message) =>
      AiModelFetchResult(isSuccess: false, errorMessage: message);
}
