import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/core/services/quiz_ai_service.dart';
import 'package:cuims_unofficial2/data/models/app_settings.dart';

void main() {
  group('QuizAiService DOM Parsing Tests', () {
    late QuizAiService service;

    setUp(() {
      service = QuizAiService();
    });

    test('Parses Item 134 question correctly from actual Moodle DOM fixture', () {
      final file = File('test/fixtures/quiz_question_item134.html');
      expect(file.existsSync(), isTrue, reason: 'Item 134 fixture must exist');
      final html = file.readAsStringSync();

      final questions = service.parseQuestionsFromHtml(html);
      expect(questions.length, equals(1));

      final q = questions.first;
      expect(q.id, equals('question-3972569-2'));
      expect(q.text, contains('What is 20% of 150?'));
      expect(q.options.length, equals(4));

      expect(q.options[0].label, equals('a.'));
      expect(q.options[0].text, equals('45'));
      expect(q.options[0].id, equals('q3972569:2_answer0'));

      expect(q.options[1].label, equals('b.'));
      expect(q.options[1].text, equals('30'));
      expect(q.options[1].id, equals('q3972569:2_answer1'));

      expect(q.options[2].label, equals('c.'));
      expect(q.options[2].text, equals('50'));
      expect(q.options[2].id, equals('q3972569:2_answer2'));

      expect(q.options[3].label, equals('d.'));
      expect(q.options[3].text, equals('20'));
      expect(q.options[3].id, equals('q3972569:2_answer3'));
    });

    test('Parses Item 145 question correctly from actual Moodle DOM fixture', () {
      final file = File('test/fixtures/quiz_question_item145.html');
      expect(file.existsSync(), isTrue, reason: 'Item 145 fixture must exist');
      final html = file.readAsStringSync();

      final questions = service.parseQuestionsFromHtml(html);
      expect(questions.length, equals(1));

      final q = questions.first;
      expect(q.id, equals('question-3972569-9'));
      expect(q.text, contains('A person starts walking towards the North'));
      expect(q.options.length, equals(4));

      expect(q.options[0].text, equals('East'));
      expect(q.options[1].text, equals('South'));
      expect(q.options[2].text, equals('North'));
      expect(q.options[3].text, equals('West'));
    });

    test('buildPrompt formats prompt with question and all options', () {
      final q = QuizQuestion(
        id: 'q1',
        text: 'What is the capital of France?',
        options: const [
          QuizOption(index: 0, id: 'opt0', label: 'a.', text: 'Berlin', value: '0'),
          QuizOption(index: 1, id: 'opt1', label: 'b.', text: 'Paris', value: '1'),
        ],
      );

      final prompt = service.buildPrompt(q);
      expect(prompt, contains('QUESTION:'));
      expect(prompt, contains('What is the capital of France?'));
      expect(prompt, contains('0. a. Berlin'));
      expect(prompt, contains('1. b. Paris'));
      expect(prompt, contains('{"selected_index": <int>, "explanation": "<short explanation>"}'));
    });
  });

  group('QuizAiService AI Solving Tests with Mock Dio', () {
    test('Solves with Gemini response correctly', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {
                            'text': json.encode({
                              'selected_index': 1,
                              'explanation': '20% of 150 equals 30.'
                            })
                          }
                        ]
                      }
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final service = QuizAiService(dio: mockDio);
      final question = QuizQuestion(
        id: 'question-3972569-2',
        text: 'What is 20% of 150?',
        options: const [
          QuizOption(index: 0, id: 'opt0', label: 'a.', text: '45', value: '0'),
          QuizOption(index: 1, id: 'opt1', label: 'b.', text: '30', value: '1'),
          QuizOption(index: 2, id: 'opt2', label: 'c.', text: '50', value: '2'),
        ],
      );

      final answer = await service.solveQuestion(
        question: question,
        provider: QuizAiProvider.gemini,
        apiKey: 'fake-gemini-key',
      );

      expect(answer.isSuccess, isTrue);
      expect(answer.selectedOptionIndex, equals(1));
      expect(answer.selectedOptionId, equals('opt1'));
      expect(answer.selectedOptionText, equals('b. 30'));
      expect(answer.explanation, equals('20% of 150 equals 30.'));
      expect(answer.provider, equals(QuizAiProvider.gemini));
    });

    test('Solves with OpenAI response correctly', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'choices': [
                    {
                      'message': {
                        'content': json.encode({
                          'selected_index': 3,
                          'explanation': 'Walking north and turning left makes you face West.'
                        })
                      }
                    }
                  ]
                },
              ),
            );
          },
        ),
      );

      final service = QuizAiService(dio: mockDio);
      final question = QuizQuestion(
        id: 'question-3972569-9',
        text: 'A person starts walking towards the North. Then turns left.',
        options: const [
          QuizOption(index: 0, id: 'opt0', label: 'a.', text: 'East', value: '0'),
          QuizOption(index: 1, id: 'opt1', label: 'b.', text: 'South', value: '1'),
          QuizOption(index: 2, id: 'opt2', label: 'c.', text: 'North', value: '2'),
          QuizOption(index: 3, id: 'opt3', label: 'd.', text: 'West', value: '3'),
        ],
      );

      final answer = await service.solveQuestion(
        question: question,
        provider: QuizAiProvider.openAi,
        apiKey: 'sk-fake-openai-key',
      );

      expect(answer.isSuccess, isTrue);
      expect(answer.selectedOptionIndex, equals(3));
      expect(answer.selectedOptionId, equals('opt3'));
      expect(answer.selectedOptionText, equals('d. West'));
      expect(answer.explanation, contains('West'));
      expect(answer.provider, equals(QuizAiProvider.openAi));
    });

    test('Returns failure when API key is empty', () async {
      final service = QuizAiService();
      final question = QuizQuestion(
        id: 'q1',
        text: 'Sample',
        options: const [QuizOption(index: 0, id: 'o1', label: 'a.', text: '1', value: '0')],
      );

      final answer = await service.solveQuestion(
        question: question,
        provider: QuizAiProvider.gemini,
        apiKey: '',
      );

      expect(answer.isSuccess, isFalse);
      expect(answer.errorMessage, contains('API Key is not configured'));
    });
  });

  group('AppSettings Quiz AI Serialization Tests', () {
    test('Default values are correct', () {
      const settings = AppSettings();
      expect(settings.enableQuizAiHelper, isTrue);
      expect(settings.quizAiProvider, equals(QuizAiProvider.gemini));
      expect(settings.quizAiApiKey, isEmpty);
      expect(settings.quizAiModel, isEmpty);
    });

    test('copyWith updates quiz AI settings correctly', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        enableQuizAiHelper: false,
        quizAiProvider: QuizAiProvider.openAi,
        quizAiApiKey: 'sk-test-12345',
        quizAiModel: 'gpt-4o',
      );

      expect(updated.enableQuizAiHelper, isFalse);
      expect(updated.quizAiProvider, equals(QuizAiProvider.openAi));
      expect(updated.quizAiApiKey, equals('sk-test-12345'));
      expect(updated.quizAiModel, equals('gpt-4o'));
    });

    test('toMap and fromMap serialize and deserialize accurately', () {
      final original = const AppSettings().copyWith(
        enableQuizAiHelper: true,
        quizAiProvider: QuizAiProvider.openAi,
        quizAiApiKey: 'my-secret-key',
        quizAiModel: 'gemini-2.0-flash',
      );

      final map = original.toMap();
      expect(map['enableQuizAiHelper'], isTrue);
      expect(map['quizAiProvider'], equals('openAi'));
      expect(map['quizAiApiKey'], equals('my-secret-key'));
      expect(map['quizAiModel'], equals('gemini-2.0-flash'));

      final fromMap = AppSettings.fromMap(map);
      expect(fromMap.enableQuizAiHelper, isTrue);
      expect(fromMap.quizAiProvider, equals(QuizAiProvider.openAi));
      expect(fromMap.quizAiApiKey, equals('my-secret-key'));
      expect(fromMap.quizAiModel, equals('gemini-2.0-flash'));
    });
  });

  group('QuizAiService Model Listing Tests', () {
    test('fetchAvailableModels parses Gemini listmodels endpoint and filters generateContent models', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'models': [
                    {
                      'name': 'models/gemini-1.5-flash',
                      'displayName': 'Gemini 1.5 Flash',
                      'supportedGenerationMethods': ['generateContent', 'countTokens'],
                    },
                    {
                      'name': 'models/gemini-1.5-pro',
                      'displayName': 'Gemini 1.5 Pro',
                      'supportedGenerationMethods': ['generateContent'],
                    },
                    {
                      'name': 'models/text-embedding-004',
                      'displayName': 'Text Embedding',
                      'supportedGenerationMethods': ['embedContent'],
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final service = QuizAiService(dio: mockDio);
      final result = await service.fetchAvailableModels(
        provider: QuizAiProvider.gemini,
        apiKey: 'test-key',
      );

      expect(result.isSuccess, isTrue);
      expect(result.models.length, equals(2));
      expect(result.models.any((m) => m.id == 'gemini-1.5-flash'), isTrue);
      expect(result.models.any((m) => m.id == 'gemini-1.5-pro'), isTrue);
      expect(result.models.any((m) => m.id == 'text-embedding-004'), isFalse);
    });

    test('fetchAvailableModels parses OpenAI models endpoint and filters text generation models starting with gpt-, o1, or o3', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': [
                    {'id': 'gpt-4o'},
                    {'id': 'gpt-4o-mini'},
                    {'id': 'o1-preview'},
                    {'id': 'o3-mini'},
                    {'id': 'text-embedding-3-small'},
                    {'id': 'whisper-1'},
                    {'id': 'dall-e-3'},
                    {'id': 'tts-1'},
                    {'id': 'babbage-002'},
                  ],
                },
              ),
            );
          },
        ),
      );

      final service = QuizAiService(dio: mockDio);
      final result = await service.fetchAvailableModels(
        provider: QuizAiProvider.openAi,
        apiKey: 'sk-test',
      );

      expect(result.isSuccess, isTrue);
      expect(result.models.length, equals(4));
      expect(result.models.any((m) => m.id == 'gpt-4o'), isTrue);
      expect(result.models.any((m) => m.id == 'gpt-4o-mini'), isTrue);
      expect(result.models.any((m) => m.id == 'o1-preview'), isTrue);
      expect(result.models.any((m) => m.id == 'o3-mini'), isTrue);
      expect(result.models.any((m) => m.id == 'text-embedding-3-small'), isFalse);
      expect(result.models.any((m) => m.id == 'whisper-1'), isFalse);
      expect(result.models.any((m) => m.id == 'dall-e-3'), isFalse);
      expect(result.models.any((m) => m.id == 'tts-1'), isFalse);
      expect(result.models.any((m) => m.id == 'babbage-002'), isFalse);
    });

    test('fetchAvailableModels handles unauthorized 401 error gracefully', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 401),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final service = QuizAiService(dio: mockDio);
      final result = await service.fetchAvailableModels(
        provider: QuizAiProvider.openAi,
        apiKey: 'sk-invalid-key',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Invalid API Key or unauthorized'));
    });

    test('predefinedTestQuestion has correct math question and options', () {
      final q = QuizAiService.predefinedTestQuestion;
      expect(q.text, equals('What is 20% of 150?'));
      expect(q.options.length, equals(4));
      expect(q.options[1].text, equals('30'));
    });

    test('testModelWithPredefinedQuestion queries model and returns verified answer', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {
                            'text': json.encode({
                              'selected_index': 1,
                              'explanation': '20% of 150 is 0.20 * 150 = 30.',
                            }),
                          }
                        ]
                      }
                    }
                  ],
                },
              ),
            );
          },
        ),
      );

      final service = QuizAiService(dio: mockDio);
      final answer = await service.testModelWithPredefinedQuestion(
        provider: QuizAiProvider.gemini,
        apiKey: 'test-api-key',
        model: 'gemini-1.5-flash',
      );

      expect(answer.isSuccess, isTrue);
      expect(answer.selectedOptionIndex, equals(1));
      expect(answer.selectedOptionText, contains('30'));
      expect(answer.explanation, contains('30'));
    });
  });
}

