import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/strings.dart';

class KorTourService {
  const KorTourService();

  Future<List<Map<String, dynamic>>> fetchLocationBasedList({
    required double mapX,
    required double mapY,
    int radius = 20000,
    String mobileOS = 'IOS',
    String mobileApp = 'mypettrip',
  }) async {
    final uri = Uri.parse(
      'https://apis.data.go.kr/B551011/KorPetTourService2/locationBasedList2',
    ).replace(
      queryParameters: {
        'serviceKey': AppStrings.korTourApiKey,
        'MobileOS': mobileOS,
        'MobileApp': mobileApp,
        'mapX': mapX.toStringAsFixed(6),
        'mapY': mapY.toStringAsFixed(6),
        'radius': radius.toString(),
        '_type': 'json',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('API 요청 실패: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final items =
        decoded?['response']?['body']?['items']?['item'] as dynamic;

    if (items == null) {
      return [];
    }

    if (items is List) {
      return items.cast<Map<String, dynamic>>();
    }

    if (items is Map<String, dynamic>) {
      return [items];
    }

    return [];
  }
}
