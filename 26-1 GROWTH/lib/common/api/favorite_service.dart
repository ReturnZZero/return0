import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  const FavoriteService();

  static const String _key = 'favorites_v1';
  static final ValueNotifier<int> changeTick = ValueNotifier<int>(0);

  Future<List<Map<String, dynamic>>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveFavorites(List<Map<String, dynamic>> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = favorites
        .map((item) => _normalizeForStorage(item))
        .toList();
    await prefs.setString(_key, jsonEncode(normalized));
  }

  Future<bool> isFavorite(String id) async {
    final list = await loadFavorites();
    return list.any((item) => itemId(item) == id);
  }

  Future<List<Map<String, dynamic>>> toggleFavorite(
    Map<String, dynamic> item,
  ) async {
    final list = await loadFavorites();
    final id = itemId(item);
    final normalizedItem = {...item, 'favoriteId': id};
    final index = list.indexWhere((e) => itemId(e) == id);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add(normalizedItem);
    }
    await saveFavorites(list);
    changeTick.value++;
    return list;
  }

  Map<String, dynamic> _normalizeForStorage(Map<String, dynamic> item) {
    return item.map((key, value) => MapEntry(key, _normalizeValue(value)));
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry('$key', _normalizeValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  static String itemId(Map<String, dynamic> item) {
    final favoriteId = '${item['favoriteId'] ?? ''}'.trim();
    if (favoriteId.isNotEmpty && favoriteId != 'null') {
      return favoriteId;
    }
    final contentId = '${item['contentId'] ?? ''}'.trim();
    if (contentId.isNotEmpty && contentId != 'null') {
      return contentId;
    }
    final legacyContentId = '${item['contentid'] ?? ''}'.trim();
    if (legacyContentId.isNotEmpty && legacyContentId != 'null') {
      return legacyContentId;
    }
    final docId = '${item['docId'] ?? ''}'.trim();
    if (docId.isNotEmpty && docId != 'null') {
      return docId;
    }
    final title = '${item['title'] ?? ''}'.trim();
    final addr = '${item['addr1'] ?? ''}'.trim();
    return '$title|$addr';
  }
}
