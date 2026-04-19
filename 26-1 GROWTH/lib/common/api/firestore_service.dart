import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String tourPlacesCollection = 'tour_places';
  static const int _maxBatchSize = 400;

  Future<bool> hasTourPlaces() async {
    final snapshot = await _firestore
        .collection(tourPlacesCollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
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

  Future<int> upsertTourPlaces(List<Map<String, dynamic>> places) async {
    if (places.isEmpty) {
      return 0;
    }

    var savedCount = 0;

    for (var i = 0; i < places.length; i += _maxBatchSize) {
      final chunk = places.skip(i).take(_maxBatchSize).toList();
      final batch = _firestore.batch();

      for (final place in chunk) {
        final documentId = '${place['contentId'] ?? place['contentid'] ?? ''}'
            .trim();
        if (documentId.isEmpty) {
          continue;
        }

        final docRef = _firestore
            .collection(tourPlacesCollection)
            .doc(documentId);
        batch.set(docRef, {
          ...place,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        savedCount++;
      }

      await batch.commit();
    }

    return savedCount;
  }
}
