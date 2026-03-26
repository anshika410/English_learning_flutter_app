import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

enum LlmProvider { openai, deepseek }

class LlmProviderConfig {
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;

  const LlmProviderConfig({
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  bool get isConfigured => apiKey.isNotEmpty;
}

class LlmService {
  late final Map<LlmProvider, LlmProviderConfig> _providers;
  late LlmProvider _activeProvider;

  LlmProvider get activeProvider => _activeProvider;
  LlmProviderConfig get activeConfig => _providers[_activeProvider]!;
  List<LlmProvider> get availableProviders =>
      _providers.entries.where((e) => e.value.isConfigured).map((e) => e.key).toList();

  LlmService() {
    _providers = {
      LlmProvider.openai: LlmProviderConfig(
        name: 'OpenAI',
        apiKey: dotenv.env['OPENAI_API_KEY'] ?? '',
        baseUrl: dotenv.env['OPENAI_BASE_URL'] ?? 'https://api.openai.com/v1',
        model: dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini',
      ),
      LlmProvider.deepseek: LlmProviderConfig(
        name: 'DeepSeek',
        apiKey: dotenv.env['DEEPSEEK_API_KEY'] ?? '',
        baseUrl: dotenv.env['DEEPSEEK_BASE_URL'] ?? 'https://api.deepseek.com/v1',
        model: dotenv.env['DEEPSEEK_MODEL'] ?? 'deepseek-chat',
      ),
    };

    // Pick default from env or first available
    final defaultStr = dotenv.env['DEFAULT_LLM'] ?? 'openai';
    _activeProvider = defaultStr == 'deepseek' ? LlmProvider.deepseek : LlmProvider.openai;

    // Fall back if chosen provider has no key
    if (!activeConfig.isConfigured) {
      final fallback = availableProviders.isNotEmpty ? availableProviders.first : LlmProvider.openai;
      _activeProvider = fallback;
    }
  }

  void setProvider(LlmProvider provider) {
    if (_providers[provider]?.isConfigured == true) {
      _activeProvider = provider;
    }
  }

  static const _systemPrompt = '''
You are Ella, a friendly and patient English language tutor.
Your role:
1. Have natural conversations in English to help the user practice.
2. After each user message, briefly note any grammar or pronunciation issues in a "Correction" section (only if there are mistakes).
3. Keep responses concise (2-3 sentences max for conversation, 1 sentence for corrections).
4. Adjust difficulty to the user's level.
5. Occasionally suggest new vocabulary or phrases.
6. Be encouraging and supportive.

Format your response as:
[Your conversational reply here]

CORRECTION: [Any grammar/vocabulary fix, or empty if none]
''';

  Future<ChatMessage> sendMessage(List<ChatMessage> history) async {
    final config = activeConfig;
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...history.map((m) => m.toApiMap()),
    ];

    final response = await http.post(
      Uri.parse('${config.baseUrl}/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode({
        'model': config.model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 300,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('${config.name} API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['choices'][0]['message']['content'] as String;

    String mainReply = text;
    String? correction;
    final correctionMatch = RegExp(
      r'CORRECTION:\s*(.*)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (correctionMatch != null) {
      correction = correctionMatch.group(1)?.trim();
      mainReply = text.substring(0, correctionMatch.start).trim();
      if (correction != null && correction.isEmpty) correction = null;
    }

    return ChatMessage(
      role: MessageRole.assistant,
      content: mainReply,
      correction: correction,
    );
  }
}
