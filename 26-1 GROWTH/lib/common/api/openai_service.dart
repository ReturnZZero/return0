import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/strings.dart';
import 'google_geocoding_service.dart';

class OpenAiService {
  OpenAiService({http.Client? client, GoogleGeocodingService? geocodingService})
    : _client = client ?? http.Client(),
      _geocodingService = geocodingService ?? const GoogleGeocodingService();

  final http.Client _client;
  final GoogleGeocodingService _geocodingService;
  static const String _regionSuffixPattern =
      r'(?:의|에|에서|으로|로|과|와|이|가|을|를|은|는|도|만|부터|까지|근처|인근|주변|쪽)?';
  static const Map<String, String> _regionAliases = {
    '서울특별시': '서울특별시',
    '서울시': '서울특별시',
    '서울': '서울특별시',
    '부산광역시': '부산광역시',
    '부산시': '부산광역시',
    '부산': '부산광역시',
    '대구광역시': '대구광역시',
    '대구시': '대구광역시',
    '대구': '대구광역시',
    '인천광역시': '인천광역시',
    '인천시': '인천광역시',
    '인천': '인천광역시',
    '광주광역시': '광주광역시',
    '광주시': '광주광역시',
    '광주': '광주광역시',
    '대전광역시': '대전광역시',
    '대전시': '대전광역시',
    '대전': '대전광역시',
    '울산광역시': '울산광역시',
    '울산시': '울산광역시',
    '울산': '울산광역시',
    '세종특별자치시': '세종특별자치시',
    '세종시': '세종특별자치시',
    '세종': '세종특별자치시',
    '경기도': '경기도',
    '경기': '경기도',
    '강원특별자치도': '강원특별자치도',
    '강원도': '강원특별자치도',
    '강원': '강원특별자치도',
    '충청북도': '충청북도',
    '충북': '충청북도',
    '충청남도': '충청남도',
    '충남': '충청남도',
    '전북특별자치도': '전북특별자치도',
    '전라북도': '전북특별자치도',
    '전북': '전북특별자치도',
    '전라남도': '전라남도',
    '전남': '전라남도',
    '경상북도': '경상북도',
    '경북': '경상북도',
    '경상남도': '경상남도',
    '경남': '경상남도',
    '제주특별자치도': '제주특별자치도',
    '제주도': '제주특별자치도',
    '제주': '제주특별자치도',
  };
  static const String _systemPrompt = '''
당신은 반려동물 동반 여행 앱을 위한 도우미입니다.
반드시 한국어로 답하세요. 항상 아래 형식으로 응답하세요:
1) 짧은 자연어 답변 (1~2문장)
2) 다음 줄에 JSON 객체 1개 (키는 정확히 아래와 동일, 순서도 유지)
mapX, mapY, petName, petAge, petGender, isNeutered, petBread, isFierceDog, petWeight, petSize, activityLevel, travelChecklist, isOffLeash, indoorAllowed, parkingAvailable.

JSON 규칙:
- mapX, mapY는 좌표(경도, 위도). 사용자가 지역을 언급하면 해당 지역의 중심 좌표를 넣어라.
- 사용자가 지역을 모호하게 표현해도 반드시 가장 가까운 행정구역으로 해석하여 좌표를 넣어라.
- 예: "경기도 인근" → "경기도", "서울 근처" → "서울특별시"
- 절대 mapX, mapY를 null로 두지 마라 (지역이 한 글자라도 있으면 반드시 좌표 반환)
- 좌표를 알 수 없으면 대한민국 중심 좌표를 반환하라 (mapX=127.7669, mapY=35.9078)
- 반려동물 관련 필드는 사용자가 질문 안에서 특정 반려동물 이름을 명시했을 때만 채우세요.
- 현재 선택된 반려동물 정보가 제공되더라도, 질문에 그 반려동물 이름이 직접 등장하지 않으면 반려동물 관련 필드는 자동으로 채우지 마세요.
- 사용자가 특정 반려동물 이름을 말하면 그 이름을 기준으로 이해하고, 제공된 선택 반려동물 정보와 이름이 일치할 때만 그 값을 JSON에 반영하세요.
- 사용자가 질문에 특정 조건을 직접 말하면 그 조건을 JSON에 반드시 반영하세요.
- 예: "맹견" 또는 "법적맹견"이 들어가면 isFierceDog=true 로 설정하세요.
- 예: "맹견 아님", "맹견 아닌", "맹견 제외"가 들어가면 isFierceDog=false 로 설정하세요.
- petGender는 "M" 또는 "F"만 사용하세요.
- petSize는 "S" | "M" | "L"만 사용하세요.
- activityLevel은 "L" | "M" | "H"만 사용하세요.
- travelChecklist는 문자열 배열이며 최대 3개입니다.
- bool 필드는 true, false, null 중 하나만 사용하세요.
- 문자열 필드는 값이 없으면 null을 사용하세요.
- 숫자 필드는 값이 없으면 null을 사용하세요.
- travelChecklist 값이 없으면 빈 배열 []을 사용하세요.
- JSON에서 null 또는 [] 로 내려간 항목은 "조건 없음", 즉 all 의미입니다.
- JSON의 정확성이 자연어 답변보다 우선이다.
- 추가 키를 넣지 마세요. JSON을 코드블록으로 감싸지 마세요.
''';

  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    List<Map<String, dynamic>> petProfiles = const [],
    Map<String, dynamic>? selectedPetProfile,
    String model = 'gpt-4o-mini',
  }) async {
    final matchedPetProfile = _resolveMatchedPetProfile(
      messages: messages,
      petProfiles: petProfiles,
      selectedPetProfile: selectedPetProfile,
    );
    final selectedPetProfilePrompt = _buildSelectedPetProfilePrompt(
      matchedPetProfile,
    );
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
          {'role': 'system', 'content': selectedPetProfilePrompt},
          ...messages.map((m) => {'role': m['role'], 'content': m['content']}),
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

    return _applyResponsePostProcessing(
      content: content.trim(),
      messages: messages,
      selectedPetProfile: matchedPetProfile,
    );
  }

  Future<String> _applyResponsePostProcessing({
    required String content,
    required List<Map<String, String>> messages,
    Map<String, dynamic>? selectedPetProfile,
  }) async {
    final jsonRange = _findJsonRange(content);
    if (jsonRange == null) {
      return content;
    }

    try {
      final jsonText = content.substring(jsonRange.$1, jsonRange.$2);
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        return content;
      }

      final normalized = Map<String, dynamic>.from(decoded);
      _mergeSelectedPetProfile(normalized, selectedPetProfile);
      _applyQuestionDerivedFilters(
        normalized,
        latestUserText:
            messages.lastWhere(
              (m) => m['role'] == 'user',
              orElse: () => const {'content': ''},
            )['content'] ??
            '',
      );

      final regionText = _extractRegionText(messages);
      if (regionText != null && regionText.isNotEmpty) {
        final geocoded = await _geocodingService.geocodeAddress(regionText);
        normalized['mapX'] = geocoded['lng'];
        normalized['mapY'] = geocoded['lat'];
      }

      return '${content.substring(0, jsonRange.$1)}${jsonEncode(normalized)}${content.substring(jsonRange.$2)}';
    } catch (_) {
      return content;
    }
  }

  void _mergeSelectedPetProfile(
    Map<String, dynamic> normalized,
    Map<String, dynamic>? selectedPetProfile,
  ) {
    if (selectedPetProfile == null || selectedPetProfile.isEmpty) {
      return;
    }

    const scalarKeys = <String>[
      'petName',
      'petAge',
      'petGender',
      'isNeutered',
      'petBread',
      'isFierceDog',
      'petWeight',
      'petSize',
      'activityLevel',
      'isOffLeash',
      'indoorAllowed',
      'parkingAvailable',
    ];

    for (final key in scalarKeys) {
      final currentValue = normalized[key];
      final profileValue = selectedPetProfile[key];
      if (_isMissingJsonValue(currentValue) &&
          !_isMissingJsonValue(profileValue)) {
        normalized[key] = profileValue;
      }
    }

    final currentChecklist = _normalizeStringList(
      normalized['travelChecklist'],
    );
    final profileChecklist = _normalizeStringList(
      selectedPetProfile['travelChecklist'],
    );
    if (currentChecklist.isEmpty && profileChecklist.isNotEmpty) {
      normalized['travelChecklist'] = profileChecklist;
    }
  }

  bool _isMissingJsonValue(dynamic value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    return false;
  }

  List<String> _normalizeStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _applyQuestionDerivedFilters(
    Map<String, dynamic> normalized, {
    required String latestUserText,
  }) {
    final text = latestUserText.trim().toLowerCase();
    if (text.isEmpty) {
      return;
    }

    if (_mentionsNegativeFierceDog(text)) {
      normalized['isFierceDog'] = false;
    } else if (_mentionsPositiveFierceDog(text)) {
      normalized['isFierceDog'] = true;
    }
  }

  bool _mentionsPositiveFierceDog(String text) {
    return text.contains('맹견') || text.contains('법적맹견');
  }

  bool _mentionsNegativeFierceDog(String text) {
    return text.contains('맹견 아님') ||
        text.contains('맹견아님') ||
        text.contains('맹견 아닌') ||
        text.contains('맹견 제외') ||
        text.contains('법적맹견 아님') ||
        text.contains('법적맹견 아닌') ||
        text.contains('법적맹견 제외');
  }

  String _buildSelectedPetProfilePrompt(Map<String, dynamic>? profile) {
    if (profile == null || profile.isEmpty) {
      return '''
현재 선택된 반려동물 정보가 없습니다.
반려동물 관련 JSON 필드는 아래 기본값으로 채우세요.
- petName: null
- petAge: null
- petGender: null
- isNeutered: null
- petBread: null
- isFierceDog: null
- petWeight: null
- petSize: null
- activityLevel: null
- travelChecklist: []
- isOffLeash: null
- indoorAllowed: null
- parkingAvailable: null
''';
    }

    final petName = '${profile['petName'] ?? ''}'.trim();
    final normalized = <String, dynamic>{
      'petName': petName,
      'petAge': profile['petAge'],
      'petGender': profile['petGender'],
      'isNeutered': profile['isNeutered'],
      'petBread': profile['petBread'],
      'isFierceDog': profile['isFierceDog'],
      'petWeight': profile['petWeight'],
      'petSize': profile['petSize'],
      'activityLevel': profile['activityLevel'],
      'travelChecklist': profile['travelChecklist'] ?? const [],
      'isOffLeash': profile['isOffLeash'],
      'indoorAllowed': profile['indoorAllowed'],
      'parkingAvailable': profile['parkingAvailable'],
    };

    return '''
현재 선택된 반려동물 정보입니다.
질문에 아래 반려동물 이름이 직접 포함될 때만 이 값을 사용하세요.
- 선택된 반려동물 이름: ${petName.isEmpty ? '없음' : petName}
질문에 이 이름이 없으면 반려동물 관련 JSON 필드는 null 또는 [] 기본값으로 유지하세요.
${jsonEncode(normalized)}
''';
  }

  String? _extractRegionText(List<Map<String, String>> messages) {
    final userMessages = messages.where((m) => m['role'] == 'user').toList();
    if (userMessages.isEmpty) {
      return null;
    }

    final latestUserText = '${userMessages.last['content'] ?? ''}'.trim();
    if (latestUserText.isEmpty) {
      return null;
    }

    final canonicalRegion = _findCanonicalRegionAlias(latestUserText);
    if (canonicalRegion != null) {
      return canonicalRegion;
    }

    final normalizedText = _normalizeRegionAliases(latestUserText);
    final patterns = <RegExp>[
      RegExp(
        '([가-힣]+(?:특별시|광역시|특별자치시|도|특별자치도)\\s*[가-힣]+(?:시|군|구))(?=${_regionSuffixPattern}(?:\\s|[,.!?]|\$))',
      ),
      RegExp(
        '([가-힣]+(?:특별시|광역시|특별자치시|도|특별자치도))(?=${_regionSuffixPattern}(?:\\s|[,.!?]|\$))',
      ),
      RegExp('([가-힣]+(?:시|군|구))(?=${_regionSuffixPattern}(?:\\s|[,.!?]|\$))'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(normalizedText).toList();
      if (matches.isEmpty) {
        continue;
      }

      final value =
          matches
              .map((match) => match.group(0)?.trim() ?? '')
              .where((text) => text.isNotEmpty)
              .toList()
            ..sort((a, b) => b.length.compareTo(a.length));

      if (value.isNotEmpty) {
        return value.first.replaceAll(RegExp(r'\s+'), ' ');
      }
    }

    return null;
  }

  Map<String, dynamic>? _resolveMatchedPetProfile({
    required List<Map<String, String>> messages,
    required List<Map<String, dynamic>> petProfiles,
    Map<String, dynamic>? selectedPetProfile,
  }) {
    final latestUserText = _latestUserText(messages);
    if (latestUserText.isEmpty) {
      return null;
    }

    final candidates = <Map<String, dynamic>>[
      ...petProfiles,
      if (selectedPetProfile != null && selectedPetProfile.isNotEmpty)
        selectedPetProfile,
    ];
    candidates.sort((a, b) {
      final aName = '${a['petName'] ?? ''}'.trim();
      final bName = '${b['petName'] ?? ''}'.trim();
      return bName.length.compareTo(aName.length);
    });

    for (final candidate in candidates) {
      final petName = '${candidate['petName'] ?? ''}'.trim();
      if (petName.isEmpty) {
        continue;
      }
      if (latestUserText.contains(petName)) {
        return candidate;
      }
    }

    return null;
  }

  String _latestUserText(List<Map<String, String>> messages) {
    final userMessages = messages.where((m) => m['role'] == 'user').toList();
    if (userMessages.isEmpty) {
      return '';
    }

    final latestUserText = '${userMessages.last['content'] ?? ''}'.trim();
    return latestUserText;
  }

  String _normalizeRegionAliases(String text) {
    var normalized = text;
    final entries = _regionAliases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in entries) {
      normalized = normalized.replaceAllMapped(
        RegExp(
          '(^|\\s)(${RegExp.escape(entry.key)})(?=${_regionSuffixPattern}(?:\\s|[,.!?]|\$))',
        ),
        (match) => '${match.group(1) ?? ''}${entry.value}',
      );
    }
    return normalized.trim();
  }

  String? _findCanonicalRegionAlias(String text) {
    final entries = _regionAliases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in entries) {
      final pattern = RegExp(
        '(^|\\s)${RegExp.escape(entry.key)}(?=${_regionSuffixPattern}(?:\\s|[,.!?]|\$))',
      );
      if (pattern.hasMatch(text)) {
        return entry.value;
      }
    }
    return null;
  }

  (int, int)? _findJsonRange(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start) {
      return null;
    }
    return (start, end + 1);
  }
}
