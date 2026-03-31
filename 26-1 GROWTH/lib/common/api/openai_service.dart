import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/strings.dart';

class OpenAiService {
  OpenAiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    String model = 'gpt-4o-mini',
  }) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppStrings.openAiApiKey}',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages
            .map(
              (m) => {
                'role': m['role'],
                'content': m['content'],
              },
            )
            .toList(),
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI 요청 실패: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('OpenAI 응답이 비어있습니다.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('OpenAI 응답 파싱 실패');
    }

    return content.trim();
  }
}
