import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetProfileService {
  const PetProfileService();

  static const String _petProfilesKey = 'pet_profiles_v2';
  static const String _selectedPetIdKey = 'selected_pet_id_v1';
  static const String _legacyPetProfileKey = 'pet_profile_v1';

  Future<List<Map<String, dynamic>>> loadPetProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final petProfilesKey = _scopedKey(_petProfilesKey);
    final selectedPetIdKey = _scopedKey(_selectedPetIdKey);
    final migrated = await _migrateLegacyProfileIfNeeded(
      prefs,
      petProfilesKey: petProfilesKey,
      selectedPetIdKey: selectedPetIdKey,
    );
    if (migrated != null) {
      return migrated;
    }

    final raw = prefs.getString(petProfilesKey);
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
    return prefs.getString(_scopedKey(_selectedPetIdKey));
  }

  Future<void> setSelectedPetId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_selectedPetIdKey), id);
  }

  Future<Map<String, dynamic>> upsertPetProfile(
    Map<String, dynamic> profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadPetProfiles();
    final petProfilesKey = _scopedKey(_petProfilesKey);
    final selectedPetIdKey = _scopedKey(_selectedPetIdKey);

    final normalized = _normalizePetProfile(profile);
    final id = '${normalized['id'] ?? ''}'.trim().isEmpty
        ? 'pet_${DateTime.now().millisecondsSinceEpoch}'
        : '${normalized['id']}';
    normalized['id'] = id;

    final index = profiles.indexWhere((item) => '${item['id'] ?? ''}' == id);
    if (index >= 0) {
      profiles[index] = {
        ..._normalizePetProfile(profiles[index]),
        ...normalized,
      };
    } else {
      profiles.add(normalized);
    }

    await prefs.setString(petProfilesKey, jsonEncode(profiles));
    await prefs.setString(selectedPetIdKey, id);
    return normalized;
  }

  Future<void> deletePetProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadPetProfiles();
    final petProfilesKey = _scopedKey(_petProfilesKey);
    final selectedPetIdKey = _scopedKey(_selectedPetIdKey);
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

    await prefs.setString(petProfilesKey, jsonEncode(profiles));

    final selectedId = prefs.getString(selectedPetIdKey);
    if (selectedId == id) {
      if (profiles.isEmpty) {
        await prefs.remove(selectedPetIdKey);
      } else {
        await prefs.setString(selectedPetIdKey, '${profiles.first['id']}');
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

  String _scopedKey(String baseKey) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${baseKey}_$uid';
  }

  Map<String, dynamic> _normalizePetProfile(Map<String, dynamic> profile) {
    final normalized = Map<String, dynamic>.from(profile);

    final petName = '${normalized['petName'] ?? normalized['name'] ?? ''}'
        .trim();
    final petAge = _parseInt(normalized['petAge'] ?? normalized['age']);
    final petGender = _normalizePetGender(
      normalized['petGender'] ?? normalized['gender'],
    );
    final isNeutered = normalized['isNeutered'] == true;
    final petBread = '${normalized['petBread'] ?? normalized['breed'] ?? ''}'
        .trim();
    final isFierceDog =
        normalized['isFierceDog'] == true ||
        normalized['isDangerousBreed'] == true;
    final petWeight = _parseDouble(
      normalized['petWeight'] ?? normalized['weightKg'],
    );
    final petSize = _normalizePetSize(
      normalized['petSize'] ?? _sizeFromWeight(petWeight),
    );
    final activityLevel = _normalizeActivityLevel(normalized['activityLevel']);
    final travelChecklist = _normalizeTravelChecklist(
      normalized['travelChecklist'],
    );
    final isOffLeash = normalized['isOffLeash'] == true;
    final indoorAllowed = normalized['indoorAllowed'] == true;
    final parkingAvailable = normalized['parkingAvailable'] == true;
    final imagePath = '${normalized['imagePath'] ?? ''}'.trim();

    return {
      ...normalized,
      'petName': petName,
      'petAge': petAge,
      'petGender': petGender,
      'isNeutered': isNeutered,
      'petBread': petBread,
      'isFierceDog': isFierceDog,
      'petWeight': petWeight,
      'petSize': petSize,
      'activityLevel': activityLevel,
      'travelChecklist': travelChecklist,
      'isOffLeash': isOffLeash,
      'indoorAllowed': indoorAllowed,
      'parkingAvailable': parkingAvailable,
      'imagePath': imagePath,
    };
  }

  int? _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return null;
    }
    return int.tryParse('$value'.trim());
  }

  double? _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value'.trim());
  }

  String _normalizePetGender(dynamic value) {
    final raw = '$value'.trim().toUpperCase();
    if (raw == 'F' || raw == 'FEMALE') {
      return 'F';
    }
    return 'M';
  }

  String _normalizePetSize(dynamic value) {
    final raw = '$value'.trim().toUpperCase();
    if (raw == 'S' || raw == 'SMALL') {
      return 'S';
    }
    if (raw == 'M' || raw == 'MEDIUM') {
      return 'M';
    }
    if (raw == 'L' || raw == 'LARGE') {
      return 'L';
    }
    return '';
  }

  String _normalizeActivityLevel(dynamic value) {
    final raw = '$value'.trim().toUpperCase();
    if (raw == 'L' || raw == 'LOW') {
      return 'L';
    }
    if (raw == 'H' || raw == 'HIGH') {
      return 'H';
    }
    return 'M';
  }

  List<String> _normalizeTravelChecklist(dynamic value) {
    if (value is! List) {
      return [];
    }
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList();
  }

  String _sizeFromWeight(double? weight) {
    if (weight == null) {
      return '';
    }
    if (weight < 10) {
      return 'S';
    }
    if (weight < 25) {
      return 'M';
    }
    return 'L';
  }

  Future<List<Map<String, dynamic>>?> _migrateLegacyProfileIfNeeded(
    SharedPreferences prefs, {
    required String petProfilesKey,
    required String selectedPetIdKey,
  }) async {
    if (prefs.containsKey(petProfilesKey)) {
      return null;
    }

    if (prefs.containsKey(_petProfilesKey)) {
      final rawProfiles = prefs.getString(_petProfilesKey);
      if (rawProfiles != null && rawProfiles.isNotEmpty) {
        await prefs.setString(petProfilesKey, rawProfiles);
      }

      final selectedId = prefs.getString(_selectedPetIdKey);
      if (selectedId != null && selectedId.isNotEmpty) {
        await prefs.setString(selectedPetIdKey, selectedId);
      }

      await prefs.remove(_petProfilesKey);
      await prefs.remove(_selectedPetIdKey);

      return loadPetProfiles();
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
    final profiles = [_normalizePetProfile(profile)];

    await prefs.setString(petProfilesKey, jsonEncode(profiles));
    await prefs.setString(selectedPetIdKey, '${profile['id']}');
    await prefs.remove(_legacyPetProfileKey);
    return profiles;
  }
}
