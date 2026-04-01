import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/strings.dart';

class OpenAiService {
  OpenAiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  // 시스템 프롬프트: 사용자 질문에서 필터값 추출 규칙(개발자 확인용)
  // 필드: petType, petSize, indoorAllowed, outdoorOnly, leashRequired, placeType, parkingAvailable
  // 값 범위: 각 필드는 아래 프롬프트 규칙에 정의된 값만 허용
  static const String _systemPrompt = '''
당신은 반려동물 동반 여행 앱을 위한 도우미입니다.
반드시 한국어로 답하세요. 항상 아래 형식으로 응답하세요:
1) 짧은 자연어 답변 (1~2문장)
2) 다음 줄에 JSON 객체 1개 (키는 정확히 아래와 동일)
petType, petSize, indoorAllowed, outdoorOnly, leashRequired, placeType, parkingAvailable.

JSON 규칙:
- 아래 값만 사용하세요:
  petType: "dog" | "cat" | "all"
  petSize: "small" | "medium" | "large" | "all"
  indoorAllowed: true | false | "all"
  outdoorOnly: true | false | "all"
  leashRequired: true | false | "all"
  placeType: "cafe" | "restaurant" | "park" | "beach" | "hotel" | "trail" | "camp" | "shop" | "all"
  parkingAvailable: true | false | "all"
- 사용자가 명시하지 않은 값은 기본값을 사용하세요:
  petType="all", petSize="all", indoorAllowed="all", outdoorOnly="all",
  leashRequired="all", placeType="all", parkingAvailable="all".
- 추가 키를 넣지 마세요. JSON을 코드블록으로 감싸지 마세요.
''';

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
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          ...messages.map(
            (m) => {
              'role': m['role'],
              'content': m['content'],
            },
          ),
        ],
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
