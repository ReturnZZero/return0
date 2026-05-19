import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String tourPlacesCollection = 'tour_places';
  static const String userProfilesCollection = 'user_profiles';
  static const String reviewsCollection = 'reviews';
  static const String reportsCollection = 'reports';
  static const int _maxBatchSize = 400;
  static final Random _random = Random();
  static final ValueNotifier<int> nicknameTick = ValueNotifier<int>(0);

  Future<String> ensureUserNickname({required String uid}) async {
    final docRef = _firestore.collection(userProfilesCollection).doc(uid);
    final snapshot = await docRef.get();
    final nickname = '${snapshot.data()?['nickname'] ?? ''}'.trim();
    if (nickname.isNotEmpty) {
      return nickname;
    }

    final generatedNickname = _generateDefaultNickname();
    await docRef.set({
      'nickname': generatedNickname,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return generatedNickname;
  }

  Future<void> saveUserNickname({
    required String uid,
    required String nickname,
  }) async {
    await _firestore.collection(userProfilesCollection).doc(uid).set({
      'nickname': nickname.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    nicknameTick.value++;
  }

  Stream<List<Map<String, dynamic>>> watchPlaceReviews({
    required String placeId,
  }) {
    return _firestore
        .collection(tourPlacesCollection)
        .doc(placeId)
        .collection(reviewsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {...doc.data(), 'reviewId': doc.id})
              .toList(),
        );
  }

  Future<void> addPlaceReview({
    required String placeId,
    required String userId,
    required String nickname,
    required String content,
  }) async {
    final placeRef = _firestore.collection(tourPlacesCollection).doc(placeId);
    final reviewRef = placeRef.collection(reviewsCollection).doc();
    final batch = _firestore.batch();

    batch.set(reviewRef, {
      'userId': userId,
      'nickname': nickname.trim(),
      'content': content.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(placeRef, {
      'reviewCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> addPlaceReport({
    required String placeId,
    required String userId,
    required String message,
  }) async {
    final now = DateTime.now();
    final reportId =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    await _firestore.collection(reportsCollection).doc(reportId).set({
      'contentId': placeId,
      'userId': userId,
      'message': message.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'reportId': reportId,
    });
  }

  Future<List<Map<String, dynamic>>> attachReviewCounts(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      return [];
    }

    final enriched = <Map<String, dynamic>>[];
    for (final item in items) {
      final placeId = resolvePlaceId(item);
      if (placeId == null) {
        enriched.add({...item, 'reviewCount': item['reviewCount'] ?? 0});
        continue;
      }

      try {
        final snapshot = await _firestore
            .collection(tourPlacesCollection)
            .doc(placeId)
            .get();
        final reviewCount =
            (snapshot.data()?['reviewCount'] as num?)?.toInt() ??
            (item['reviewCount'] as num?)?.toInt() ??
            0;
        enriched.add({...item, 'reviewCount': reviewCount});
      } catch (_) {
        enriched.add({...item, 'reviewCount': item['reviewCount'] ?? 0});
      }
    }

    return enriched;
  }

  String? resolvePlaceId(Map<String, dynamic> item) {
    final contentId = '${item['contentId'] ?? ''}'.trim();
    if (contentId.isNotEmpty) {
      return contentId;
    }
    final docId = '${item['docId'] ?? ''}'.trim();
    if (docId.isNotEmpty) {
      return docId;
    }
    return null;
  }

  String _generateDefaultNickname() {
    final value = 1000 + _random.nextInt(9000);
    return '닉네임$value';
  }

  Future<bool> hasTourPlaces() async {
    final snapshot = await _firestore
        .collection(tourPlacesCollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<int> clearTourPlaces() async {
    var deletedCount = 0;

    while (true) {
      final snapshot = await _firestore
          .collection(tourPlacesCollection)
          .limit(_maxBatchSize)
          .get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deletedCount += snapshot.docs.length;
    }

    return deletedCount;
  }

  Future<List<Map<String, dynamic>>> searchTourPlaces({
    required String keyword,
    String? categoryCode,
    int limit = 500,
  }) async {
    debugPrint(
      'Firestore search request: keyword="$keyword", categoryCode="$categoryCode", limit=$limit',
    );

    Query<Map<String, dynamic>> query = _firestore
        .collection(tourPlacesCollection)
        .limit(limit);

    if (categoryCode != null && categoryCode.isNotEmpty) {
      query = query.where('lclsSystm1', isEqualTo: categoryCode);
    }

    final snapshot = await query.get();
    final normalizedKeyword = keyword.trim().toLowerCase();
    final results = snapshot.docs
        .map((doc) => {...doc.data(), 'docId': doc.id})
        .where((item) => _matchesKeyword(item, normalizedKeyword))
        .toList();

    debugPrint(
      'Firestore search response: fetched=${snapshot.docs.length}, matched=${results.length}',
    );
    for (final item in results.take(20)) {
      debugPrint(
        'Firestore result item: docId=${item['docId']}, title=${item['title']}, addr1=${item['addr1']}, placeType=${item['placeType']}',
      );
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> fetchNearbyTourPlaces({
    required LatLng center,
    int radius = 20000,
    String? sidoCode,
    String? sigunguCode,
    String? categoryCode,
    int limit = 1000,
  }) async {
    debugPrint(
      'Firestore nearby request: lat=${center.latitude}, lng=${center.longitude}, radius=$radius, sidoCode="$sidoCode", sigunguCode="$sigunguCode", categoryCode="$categoryCode", limit=$limit',
    );

    Query<Map<String, dynamic>> query = _firestore
        .collection(tourPlacesCollection)
        .limit(limit);

    if (sidoCode != null && sidoCode.isNotEmpty) {
      query = query.where('seedRegionSidoCode', isEqualTo: sidoCode);
    }
    if (sigunguCode != null && sigunguCode.isNotEmpty) {
      query = query.where('seedRegionSigunguCode', isEqualTo: sigunguCode);
    }
    if (categoryCode != null && categoryCode.isNotEmpty) {
      query = query.where('lclsSystm1', isEqualTo: categoryCode);
    }

    final snapshot = await query.get();
    final results =
        snapshot.docs
            .map((doc) => {...doc.data(), 'docId': doc.id})
            .where((item) => _isWithinRadius(item, center, radius))
            .toList()
          ..sort(
            (a, b) => _distanceFromCenter(
              a,
              center,
            ).compareTo(_distanceFromCenter(b, center)),
          );

    debugPrint(
      'Firestore nearby response: fetched=${snapshot.docs.length}, matched=${results.length}',
    );
    for (final item in results.take(20)) {
      debugPrint(
        'Firestore nearby item: docId=${item['docId']}, title=${item['title']}, addr1=${item['addr1']}, mapX=${item['mapX']}, mapY=${item['mapY']}',
      );
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> recommendTourPlacesForAi({
    required Map<String, dynamic> filters,
    int radius = 20000,
    int limit = 3,
  }) async {
    final normalizedFilters = _normalizeAiFilters(filters);
    final mapX = _parseCoordinate(normalizedFilters['mapX']);
    final mapY = _parseCoordinate(normalizedFilters['mapY']);
    if (mapX == null || mapY == null) {
      return [];
    }

    final requestedPetSize = _normalizeAiPetSize(
      normalizedFilters['petSize'],
      petWeight: _parseCoordinate(normalizedFilters['petWeight']),
    );
    final requestedPetType = _inferAiPetType(normalizedFilters);
    final requestedIndoorAllowed = _deriveIndoorAllowed(normalizedFilters);
    final requestedParkingAvailable = _deriveParkingAvailable(
      normalizedFilters,
    );
    final requestedOffLeash = _deriveOffLeash(normalizedFilters);
    final requestedActivityLevel = _normalizeActivityLevel(
      normalizedFilters['activityLevel'],
    );

    final nearbyItems = await fetchNearbyTourPlaces(
      center: LatLng(mapY, mapX),
      radius: radius,
      limit: 300,
    );

    final strictMatches =
        nearbyItems.where((item) {
          if (!_matchesAiPetType(item, requestedPetType)) {
            return false;
          }
          if (!_matchesAiPetGender(item, normalizedFilters['petGender'])) {
            return false;
          }
          if (!_matchesAiNeutered(item, normalizedFilters['isNeutered'])) {
            return false;
          }
          if (!_matchesAiFierceDog(item, normalizedFilters['isFierceDog'])) {
            return false;
          }
          if (!_matchesAiPetSize(item, requestedPetSize)) {
            return false;
          }
          if (!_matchesAiPetBread(item, normalizedFilters['petBread'])) {
            return false;
          }
          if (!_matchesAiPetAge(item, normalizedFilters['petAge'])) {
            return false;
          }
          if (!_matchesAiPetWeight(item, normalizedFilters['petWeight'])) {
            return false;
          }
          if (!_matchesAiTravelChecklist(
            item,
            normalizedFilters['travelChecklist'],
          )) {
            return false;
          }
          if (!_matchesAiIndoorAllowed(item, requestedIndoorAllowed)) {
            return false;
          }
          if (!_matchesAiParking(item, requestedParkingAvailable)) {
            return false;
          }
          if (!_matchesAiOffLeash(item, requestedOffLeash)) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) =>
              _scoreItem(
                b,
                requestedActivityLevel: requestedActivityLevel,
                requestedIndoorAllowed: requestedIndoorAllowed,
                requestedParkingAvailable: requestedParkingAvailable,
                requestedOffLeash: requestedOffLeash,
              ).compareTo(
                _scoreItem(
                  a,
                  requestedActivityLevel: requestedActivityLevel,
                  requestedIndoorAllowed: requestedIndoorAllowed,
                  requestedParkingAvailable: requestedParkingAvailable,
                  requestedOffLeash: requestedOffLeash,
                ),
              ),
        );

    final recommendations = <Map<String, dynamic>>[];
    final selectedIds = <String>{};

    for (final item in strictMatches) {
      if (recommendations.length >= limit) {
        break;
      }
      final itemId = _itemIdentity(item);
      if (selectedIds.add(itemId)) {
        recommendations.add(item);
      }
    }

    if (recommendations.length < limit) {
      final relaxedCandidates = [...nearbyItems]
        ..sort(
          (a, b) =>
              _scoreItem(
                b,
                requestedActivityLevel: requestedActivityLevel,
                requestedIndoorAllowed: requestedIndoorAllowed,
                requestedParkingAvailable: requestedParkingAvailable,
                requestedOffLeash: requestedOffLeash,
              ).compareTo(
                _scoreItem(
                  a,
                  requestedActivityLevel: requestedActivityLevel,
                  requestedIndoorAllowed: requestedIndoorAllowed,
                  requestedParkingAvailable: requestedParkingAvailable,
                  requestedOffLeash: requestedOffLeash,
                ),
              ),
        );

      for (final item in relaxedCandidates) {
        if (recommendations.length >= limit) {
          break;
        }
        final itemId = _itemIdentity(item);
        if (selectedIds.add(itemId)) {
          recommendations.add(item);
        }
      }
    }

    debugPrint(
      'Firestore AI recommendation: filters=$normalizedFilters, normalizedPetType=$requestedPetType, normalizedPetSize=$requestedPetSize, indoorAllowed=$requestedIndoorAllowed, parkingAvailable=$requestedParkingAvailable, offLeash=$requestedOffLeash, activityLevel=$requestedActivityLevel, strictMatched=${strictMatches.length}, returned=${recommendations.length}',
    );

    return recommendations.take(limit).toList();
  }

  Map<String, dynamic> _normalizeAiFilters(Map<String, dynamic> filters) {
    final normalized = Map<String, dynamic>.from(filters);
    normalized.removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        final text = value.trim().toLowerCase();
        return text.isEmpty || text == 'null';
      }
      if (value is List) {
        return value.isEmpty;
      }
      return false;
    });
    return normalized;
  }

  bool _matchesKeyword(Map<String, dynamic> item, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }

    final fields = [
      '${item['title'] ?? ''}',
      '${item['addr1'] ?? ''}',
      '${item['addr2'] ?? ''}',
      '${item['overview'] ?? ''}',
      '${item['petType'] ?? ''}',
      '${item['petSize'] ?? ''}',
      '${item['placeType'] ?? ''}',
      '${item['seedRegionSidoName'] ?? ''}',
      '${item['seedRegionSigunguName'] ?? ''}',
    ];

    return fields.any((field) => field.toLowerCase().contains(keyword));
  }

  bool _isWithinRadius(Map<String, dynamic> item, LatLng center, int radius) {
    final longitude = _parseCoordinate(item['mapX'] ?? item['mapx']);
    final latitude = _parseCoordinate(item['mapY'] ?? item['mapy']);
    if (longitude == null || latitude == null) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      center.latitude,
      center.longitude,
      latitude,
      longitude,
    );
    return distance <= radius;
  }

  double _distanceFromCenter(Map<String, dynamic> item, LatLng center) {
    final longitude = _parseCoordinate(item['mapX'] ?? item['mapx']);
    final latitude = _parseCoordinate(item['mapY'] ?? item['mapy']);
    if (longitude == null || latitude == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
      center.latitude,
      center.longitude,
      latitude,
      longitude,
    );
  }

  double? _parseCoordinate(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }

  bool _matchesAiPetSize(Map<String, dynamic> item, String? petSize) {
    final requested = _normalizeAiPetSize(petSize);
    if (requested.isEmpty) {
      return true;
    }

    final placePetSize = '${item['petSize'] ?? ''}'.trim().toUpperCase();
    if (placePetSize.isEmpty || placePetSize == 'all') {
      return true;
    }

    return placePetSize == requested ||
        (requested == 'S' && placePetSize == 'SMALL') ||
        (requested == 'M' && placePetSize == 'MEDIUM') ||
        (requested == 'L' && placePetSize == 'LARGE');
  }

  bool _matchesAiPetType(Map<String, dynamic> item, String? petType) {
    final requested = '${petType ?? ''}'.trim().toLowerCase();
    if (requested.isEmpty) {
      return true;
    }

    final placePetType = '${item['petType'] ?? ''}'.trim().toLowerCase();
    if (placePetType.isEmpty || placePetType == 'all') {
      return true;
    }

    return placePetType == requested;
  }

  bool _matchesAiPetGender(Map<String, dynamic> item, dynamic petGender) {
    final requested = '${petGender ?? ''}'.trim().toUpperCase();
    if (requested.isEmpty) {
      return true;
    }
    return '${item['petGender'] ?? ''}'.trim().toUpperCase() == requested;
  }

  bool _matchesAiNeutered(Map<String, dynamic> item, dynamic isNeutered) {
    if (isNeutered is! bool) {
      return true;
    }
    return item['isNeutered'] == isNeutered;
  }

  bool _matchesAiFierceDog(Map<String, dynamic> item, dynamic isFierceDog) {
    if (isFierceDog is! bool) {
      return true;
    }
    return item['isFierceDog'] == isFierceDog;
  }

  bool _matchesAiIndoorAllowed(Map<String, dynamic> item, bool? indoorAllowed) {
    if (indoorAllowed != true) {
      return true;
    }
    return item['indoorAllowed'] == true;
  }

  bool _matchesAiParking(Map<String, dynamic> item, bool? parkingAvailable) {
    if (parkingAvailable != true) {
      return true;
    }
    return item['parkingAvailable'] == true;
  }

  bool _matchesAiOffLeash(Map<String, dynamic> item, bool? isOffLeash) {
    if (isOffLeash != true) {
      return true;
    }
    final placeIsOffLeash = item['isOffLeash'];
    if (placeIsOffLeash is bool) {
      return placeIsOffLeash;
    }
    return item['leashRequired'] != true;
  }

  bool _matchesAiPetBread(Map<String, dynamic> item, dynamic petBread) {
    final requested = '${petBread ?? ''}'.trim().toLowerCase();
    if (requested.isEmpty) {
      return true;
    }
    return '${item['petBread'] ?? ''}'.trim().toLowerCase() == requested;
  }

  bool _matchesAiPetAge(Map<String, dynamic> item, dynamic petAge) {
    final requested = _parseCoordinate(petAge);
    if (requested == null) {
      return true;
    }

    final saved = _parseCoordinate(item['petAge']);
    if (saved == null) {
      return true;
    }

    return (saved - requested).abs() <= 2;
  }

  bool _matchesAiPetWeight(Map<String, dynamic> item, dynamic petWeight) {
    final requested = _parseCoordinate(petWeight);
    if (requested == null) {
      return true;
    }

    final saved = _parseCoordinate(item['petWeight']);
    if (saved == null) {
      return true;
    }

    return (saved - requested).abs() <= 5;
  }

  bool _matchesAiTravelChecklist(
    Map<String, dynamic> item,
    dynamic travelChecklist,
  ) {
    final requested = _extractChecklist(travelChecklist);
    if (requested.isEmpty) {
      return true;
    }

    final saved = _extractChecklist(item['travelChecklist']);
    if (saved.isEmpty) {
      return false;
    }

    return requested.any(saved.contains);
  }

  String _normalizeAiPetSize(dynamic value, {double? petWeight}) {
    final raw = '${value ?? ''}'.trim().toUpperCase();
    if (raw == 'S' || raw == 'SMALL') {
      return 'S';
    }
    if (raw == 'M' || raw == 'MEDIUM') {
      return 'M';
    }
    if (raw == 'L' || raw == 'LARGE') {
      return 'L';
    }

    if (petWeight != null) {
      if (petWeight < 10) {
        return 'S';
      }
      if (petWeight < 25) {
        return 'M';
      }
      return 'L';
    }

    return '';
  }

  String? _inferAiPetType(Map<String, dynamic> filters) {
    final breed = '${filters['petBread'] ?? ''}'.trim().toLowerCase();
    if (breed.isEmpty) {
      return null;
    }

    const catKeywords = [
      '고양이',
      '코리안숏헤어',
      '러시안블루',
      '샴',
      '페르시안',
      '벵갈',
      '노르웨이숲',
      '먼치킨',
      '브리티시숏헤어',
      '아비시니안',
      '스코티시폴드',
      '터키시앙고라',
      '랙돌',
      '메인쿤',
    ];

    for (final keyword in catKeywords) {
      if (breed.contains(keyword.toLowerCase())) {
        return 'cat';
      }
    }

    return 'dog';
  }

  bool? _deriveIndoorAllowed(Map<String, dynamic> filters) {
    final indoorAllowed = filters['indoorAllowed'];
    if (indoorAllowed is bool) {
      return indoorAllowed;
    }

    final checklist = _extractChecklist(filters['travelChecklist']);
    if (checklist.any((item) => item.contains('실내'))) {
      return true;
    }

    return null;
  }

  bool? _deriveParkingAvailable(Map<String, dynamic> filters) {
    final parkingAvailable = filters['parkingAvailable'];
    if (parkingAvailable is bool) {
      return parkingAvailable;
    }

    final checklist = _extractChecklist(filters['travelChecklist']);
    if (checklist.any((item) => item.contains('주차'))) {
      return true;
    }

    return null;
  }

  bool? _deriveOffLeash(Map<String, dynamic> filters) {
    final isOffLeash = filters['isOffLeash'];
    if (isOffLeash is bool) {
      return isOffLeash;
    }

    final checklist = _extractChecklist(filters['travelChecklist']);
    if (checklist.any((item) => item.contains('목줄') || item.contains('리드줄'))) {
      return false;
    }

    return null;
  }

  String _normalizeActivityLevel(dynamic value) {
    final raw = '${value ?? ''}'.trim().toUpperCase();
    if (raw == 'L' || raw == 'LOW') {
      return 'L';
    }
    if (raw == 'H' || raw == 'HIGH') {
      return 'H';
    }
    if (raw == 'M' || raw == 'MEDIUM') {
      return 'M';
    }
    return '';
  }

  List<String> _extractChecklist(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => '$item'.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  int _aiRecommendationScore(
    Map<String, dynamic> item, {
    required String requestedActivityLevel,
    required bool? requestedIndoorAllowed,
    required bool? requestedParkingAvailable,
    required bool? requestedOffLeash,
  }) {
    var score = 0;

    if (requestedActivityLevel == 'H' && item['outdoorOnly'] == true) {
      score += 3;
    }
    if (requestedActivityLevel == 'L' && item['indoorAllowed'] == true) {
      score += 3;
    }
    if (requestedActivityLevel == 'M') {
      score += 1;
    }
    if (requestedIndoorAllowed == true && item['indoorAllowed'] == true) {
      score += 2;
    }
    if (requestedParkingAvailable == true && item['parkingAvailable'] == true) {
      score += 2;
    }
    if (requestedOffLeash == true && item['leashRequired'] != true) {
      score += 2;
    }

    return score;
  }

  int _scoreItem(
    Map<String, dynamic> item, {
    required String requestedActivityLevel,
    required bool? requestedIndoorAllowed,
    required bool? requestedParkingAvailable,
    required bool? requestedOffLeash,
  }) {
    final baseScore = _aiRecommendationScore(
      item,
      requestedActivityLevel: requestedActivityLevel,
      requestedIndoorAllowed: requestedIndoorAllowed,
      requestedParkingAvailable: requestedParkingAvailable,
      requestedOffLeash: requestedOffLeash,
    );
    final hasImage = '${item['firstimage'] ?? ''}'.trim().isNotEmpty ? 1 : 0;
    return (baseScore * 10) + hasImage;
  }

  String _itemIdentity(Map<String, dynamic> item) {
    final docId = '${item['docId'] ?? ''}'.trim();
    if (docId.isNotEmpty) {
      return docId;
    }
    final contentId = '${item['contentId'] ?? ''}'.trim();
    if (contentId.isNotEmpty) {
      return contentId;
    }
    return '${item['title'] ?? ''}|${item['addr1'] ?? ''}';
  }

  Future<int> upsertTourPlaces(List<Map<String, dynamic>> places) async {
    if (places.isEmpty) {
      return 0;
    }

    var savedCount = 0;

    for (var i = 0; i < places.length; i += _maxBatchSize) {
      final chunk = places.skip(i).take(_maxBatchSize).toList();
      final batch = _firestore.batch();

      for (final place in chunk) {
        final normalizedPlace = _normalizeTourPlaceForStorage(place);
        final documentId = '${normalizedPlace['contentId'] ?? ''}'.trim();
        if (documentId.isEmpty) {
          continue;
        }

        final docRef = _firestore
            .collection(tourPlacesCollection)
            .doc(documentId);
        batch.set(docRef, {
          ...normalizedPlace,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        savedCount++;
      }

      await batch.commit();
    }

    return savedCount;
  }

  Map<String, dynamic> _normalizeTourPlaceForStorage(
    Map<String, dynamic> place,
  ) {
    final normalized = Map<String, dynamic>.from(place);
    normalized.remove('contentid');
    normalized.remove('mapx');
    normalized.remove('mapy');
    return normalized;
  }
}
