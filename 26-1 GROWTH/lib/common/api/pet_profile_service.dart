import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetProfileService {
  const PetProfileService();

  static const String _petProfilesKey = 'pet_profiles_v2';
  static const String _selectedPetIdKey = 'selected_pet_id_v1';
  static const String _legacyPetProfileKey = 'pet_profile_v1';

  Future<List<Map<String, dynamic>>> loadPetProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = await _migrateLegacyProfileIfNeeded(prefs);
    if (migrated != null) {
      return migrated;
    }

    final raw = prefs.getString(_petProfilesKey);
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

  Future<Map<String, dynamic>?> loadSelectedPetProfile() async {
    final profiles = await loadPetProfiles();
    if (profiles.isEmpty) {
      return null;
    }

    final selectedId = await loadSelectedPetId();
    if (selectedId == null || selectedId.isEmpty) {
      return profiles.first;
    }

    return profiles.firstWhere(
      (profile) => '${profile['id'] ?? ''}' == selectedId,
      orElse: () => profiles.first,
    );
  }

  Future<String?> loadSelectedPetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedPetIdKey);
  }

  Future<void> setSelectedPetId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedPetIdKey, id);
  }

  Future<Map<String, dynamic>> upsertPetProfile(
    Map<String, dynamic> profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadPetProfiles();

    final normalized = Map<String, dynamic>.from(profile);
    final id = '${normalized['id'] ?? ''}'.trim().isEmpty
        ? 'pet_${DateTime.now().millisecondsSinceEpoch}'
        : '${normalized['id']}';
    normalized['id'] = id;

    final index = profiles.indexWhere((item) => '${item['id'] ?? ''}' == id);
    if (index >= 0) {
      profiles[index] = normalized;
    } else {
      profiles.add(normalized);
    }

    await prefs.setString(_petProfilesKey, jsonEncode(profiles));
    await prefs.setString(_selectedPetIdKey, id);
    return normalized;
  }

  Future<void> deletePetProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadPetProfiles();
    final index = profiles.indexWhere((item) => '${item['id'] ?? ''}' == id);
    if (index < 0) {
      return;
    }

    final removed = profiles.removeAt(index);
    final imagePath = '${removed['imagePath'] ?? ''}'.trim();
    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await prefs.setString(_petProfilesKey, jsonEncode(profiles));

    final selectedId = prefs.getString(_selectedPetIdKey);
    if (selectedId == id) {
      if (profiles.isEmpty) {
        await prefs.remove(_selectedPetIdKey);
      } else {
        await prefs.setString(_selectedPetIdKey, '${profiles.first['id']}');
      }
    }
  }

  Future<String> savePetImage({
    required String sourcePath,
    String? fileNamePrefix,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final petDir = Directory('${appDir.path}/pet_profile');
    if (!await petDir.exists()) {
      await petDir.create(recursive: true);
    }

    final extension = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safePrefix = (fileNamePrefix ?? 'pet').replaceAll(
      RegExp(r'[^a-zA-Z0-9가-힣_]'),
      '_',
    );
    final targetPath = '${petDir.path}/${safePrefix}_$timestamp$extension';

    final savedFile = await File(sourcePath).copy(targetPath);
    return savedFile.path;
  }

  Future<List<Map<String, dynamic>>?> _migrateLegacyProfileIfNeeded(
    SharedPreferences prefs,
  ) async {
    if (prefs.containsKey(_petProfilesKey)) {
      return null;
    }

    final raw = prefs.getString(_legacyPetProfileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }

    final profile = Map<String, dynamic>.from(decoded);
    profile['id'] =
        '${profile['id'] ?? 'pet_${DateTime.now().millisecondsSinceEpoch}'}';
    final profiles = [profile];

    await prefs.setString(_petProfilesKey, jsonEncode(profiles));
    await prefs.setString(_selectedPetIdKey, '${profile['id']}');
    await prefs.remove(_legacyPetProfileKey);
    return profiles;
  }
}
