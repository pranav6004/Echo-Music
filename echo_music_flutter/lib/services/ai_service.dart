import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../data/settings.dart';

class AiTrackSuggestion {
  final String title;
  final String artist;

  const AiTrackSuggestion({required this.title, required this.artist});
}

class AiConnectionTestResult {
  final bool success;
  final String message;
  final int latencyMs;
  final String? model;

  const AiConnectionTestResult({
    required this.success,
    required this.message,
    required this.latencyMs,
    this.model,
  });
}

class AiService {
  AiService._();
  static final instance = AiService._();

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 90), // 90s for long playlist generations
    ),
  );

  static const defaultModels = {
    'openrouter': 'google/gemini-2.0-flash-exp:free',
    'openai': 'gpt-4o-mini',
    'anthropic': 'claude-3-5-haiku-20241022',
    'gemini': 'gemini-2.0-flash',
    'groq': 'llama-3.3-70b-versatile',
    'mistral': 'mistral-small-latest',
    'custom': 'default',
  };

  String normalizeEndpoint(String provider, String customEndpoint) {
    switch (provider.toLowerCase()) {
      case 'openrouter':
        return 'https://openrouter.ai/api/v1/chat/completions';
      case 'openai':
        return 'https://api.openai.com/v1/chat/completions';
      case 'anthropic':
        return 'https://api.anthropic.com/v1/messages';
      case 'gemini':
        return 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions';
      case 'groq':
        return 'https://api.groq.com/openai/v1/chat/completions';
      case 'mistral':
        return 'https://api.mistral.ai/v1/chat/completions';
      case 'custom':
      default:
        var ep = customEndpoint.trim();
        if (ep.isEmpty) return 'http://localhost:20128/v1/chat/completions';
        if (!ep.startsWith('http://') && !ep.startsWith('https://')) {
          ep = 'http://$ep';
        }
        if (!ep.contains('/chat/completions') && !ep.contains('/messages')) {
          if (ep.endsWith('/')) {
            ep = '${ep}v1/chat/completions';
          } else if (ep.endsWith('/v1')) {
            ep = '$ep/chat/completions';
          } else {
            ep = '$ep/v1/chat/completions';
          }
        }
        final uri = Uri.tryParse(ep);
        if (uri != null) {
          final host = uri.host.toLowerCase();
          if (host.startsWith('169.254.') || host == 'metadata.google.internal') {
            throw ArgumentError('Custom AI endpoint pointing to cloud metadata service is prohibited');
          }
        }
        return ep;
    }
  }

  Future<String> _postPrompt({
    required String provider,
    required String apiKey,
    required String model,
    required String endpoint,
    required String userPrompt,
    String? systemPrompt,
    int maxTokens = 2000,
    double temperature = 0.7,
  }) async {
    if (provider == 'anthropic') {
      final res = await _dio.post<dynamic>(
        endpoint,
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'max_tokens': maxTokens,
          if (systemPrompt != null) 'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userPrompt}
          ],
        },
      );
      final contentList = res.data?['content'] as List<dynamic>?;
      return contentList?.first?['text'] as String? ?? '';
    } else {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        if (provider == 'openrouter') ...{
          'HTTP-Referer': 'https://github.com/pranav6004/Echo-Music',
          'X-Title': 'Resona Desktop',
        },
      };

      final res = await _dio.post<dynamic>(
        endpoint,
        options: Options(headers: headers),
        data: {
          'model': model,
          'messages': [
            if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': maxTokens,
          'temperature': temperature,
        },
      );

      final choices = res.data?['choices'] as List<dynamic>?;
      return choices?.first?['message']?['content'] as String? ?? '';
    }
  }

  Future<AiConnectionTestResult> testConnection() async {
    final s = Settings.instance;
    final provider = s.aiProvider;
    final apiKey = s.aiApiKey.trim();
    final model = s.aiModel.trim().isNotEmpty
        ? s.aiModel.trim()
        : (defaultModels[provider] ?? 'gpt-4o-mini');
    final endpoint = normalizeEndpoint(provider, s.aiCustomEndpoint);

    final stopwatch = Stopwatch()..start();

    try {
      await _postPrompt(
        provider: provider,
        apiKey: apiKey,
        model: model,
        endpoint: endpoint,
        userPrompt: 'ping',
        maxTokens: 10,
      );
      stopwatch.stop();
      return AiConnectionTestResult(
        success: true,
        message: 'Connected successfully ($model)',
        latencyMs: stopwatch.elapsedMilliseconds,
        model: model,
      );
    } catch (e) {
      stopwatch.stop();
      var msg = '$e';
      if (e is DioException) {
        if (e.response != null) {
          msg = 'Status ${e.response?.statusCode}: ${e.response?.data}';
        } else {
          msg = e.message ?? '$e';
        }
      }
      return AiConnectionTestResult(
        success: false,
        message: msg,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<List<AiTrackSuggestion>> generatePlaylist({
    required String prompt,
    int count = 20,
  }) async {
    final s = Settings.instance;
    final provider = s.aiProvider;
    final apiKey = s.aiApiKey.trim();
    final model = s.aiModel.trim().isNotEmpty
        ? s.aiModel.trim()
        : (defaultModels[provider] ?? 'gpt-4o-mini');
    final endpoint = normalizeEndpoint(provider, s.aiCustomEndpoint);

    const systemPrompt = '''You are an expert music curator and DJ.
Generate a cohesive playlist based on the user prompt.
Output strictly a JSON array of objects with keys "title" and "artist".
Do NOT include markdown code blocks (```json) or extra explanation. Only the raw JSON array.
Example: [{"title": "Midnight City", "artist": "M83"}]''';

    final userPrompt = 'Generate $count tracks for: "$prompt"';

    try {
      var responseText = await _postPrompt(
        provider: provider,
        apiKey: apiKey,
        model: model,
        endpoint: endpoint,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 2000,
        temperature: 0.7,
      );

      // Clean JSON string
      responseText = responseText.trim();
      if (responseText.startsWith('```json')) {
        responseText = responseText.substring(7);
      } else if (responseText.startsWith('```')) {
        responseText = responseText.substring(3);
      }
      if (responseText.endsWith('```')) {
        responseText = responseText.substring(0, responseText.length - 3);
      }
      responseText = responseText.trim();

      final decoded = jsonDecode(responseText);
      if (decoded is List) {
        final list = <AiTrackSuggestion>[];
        for (final item in decoded) {
          if (item is Map) {
            final title = item['title']?.toString() ?? '';
            final artist = item['artist']?.toString() ?? '';
            if (title.isNotEmpty) {
              list.add(AiTrackSuggestion(title: title, artist: artist));
            }
          }
        }
        return list;
      }
    } catch (_) {}

    return [];
  }

  Future<String> translateLyrics({
    required String lyrics,
    required String targetLanguage,
  }) async {
    final s = Settings.instance;
    final provider = s.aiProvider;
    final apiKey = s.aiApiKey.trim();
    final model = s.aiModel.trim().isNotEmpty
        ? s.aiModel.trim()
        : (defaultModels[provider] ?? 'gpt-4o-mini');
    final endpoint = normalizeEndpoint(provider, s.aiCustomEndpoint);

    final systemPrompt = '''You are a professional song lyrics translator.
Translate the following lyrics into $targetLanguage.
Maintain any LRC timestamps like [01:23.45] exactly as they are on the corresponding lines.
Do NOT omit or add timestamps. Only translate the text.
Do not add introductory or explanatory text. Return only the translated lyrics.''';

    try {
      final translated = await _postPrompt(
        provider: provider,
        apiKey: apiKey,
        model: model,
        endpoint: endpoint,
        systemPrompt: systemPrompt,
        userPrompt: lyrics,
        maxTokens: 3000,
        temperature: 0.3,
      );
      return translated.trim().isNotEmpty ? translated.trim() : lyrics;
    } catch (_) {
      return lyrics;
    }
  }
}