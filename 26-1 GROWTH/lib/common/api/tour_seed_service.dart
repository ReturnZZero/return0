import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'firestore_service.dart';
import 'map_service.dart';

typedef SeedProgressCallback = void Function(String message);

class TourSeedResult {
  const TourSeedResult({
    required this.regionCount,
    required this.fetchedCount,
    required this.savedCount,
    required this.skippedCount,
  });

  final int regionCount;
  final int fetchedCount;
  final int savedCount;
  final int skippedCount;
}

class TourSeedService {
  TourSeedService({MapService? mapService, FirestoreService? firestoreService})
    : _mapService = mapService ?? const MapService(),
      _firestoreService = firestoreService ?? FirestoreService();

  final MapService _mapService;
  final FirestoreService _firestoreService;

  Future<TourSeedResult> seedTourPlaces({
    SeedProgressCallback? onProgress,
  }) async {
    onProgress?.call('지역 목록을 불러오는 중...');
    final codes = await _mapService.fetchLDongCodes();
    final regions = _buildRegions(codes);

    var fetchedCount = 0;
    var savedCount = 0;
    var skippedCount = 0;
    final seenDocumentIds = <String>{};

    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final displayName = '${region.sidoName} ${region.sigunguName}'.trim();

      onProgress?.call('[${i + 1}/${regions.length}] $displayName 좌표 조회 중...');

      LatLng center;
      try {
        center = await _mapService.geocodeAddress(displayName);
      } catch (error) {
        debugPrint('Geocoding failed for $displayName: $error');
        skippedCount++;
        onProgress?.call('$displayName 좌표 조회를 건너뛰었어요.');
        continue;
      }

      onProgress?.call('[${i + 1}/${regions.length}] $displayName 장소 수집 중...');

      List<Map<String, dynamic>> items;
      try {
        items = await _mapService.fetchNearbyItems(
          current: center,
          radius: 20000,
          lDongRegnCd: region.sidoCode,
          lDongSignguCd: region.sigunguCode,
        );
      } catch (error) {
        debugPrint('Tour API failed for $displayName: $error');
        skippedCount++;
        onProgress?.call('$displayName 관광 API 호출을 건너뛰었어요.');
        continue;
      }

      fetchedCount += items.length;

      final documents = <Map<String, dynamic>>[];
      for (final item in items) {
        final document = _buildTourDocument(
          item: item,
          region: region,
          center: center,
        );
        final documentId = '${document['contentId'] ?? ''}'.trim();
        if (documentId.isEmpty || !seenDocumentIds.add(documentId)) {
          continue;
        }
        documents.add(document);
      }

      final savedForRegion = await _firestoreService.upsertTourPlaces(
        documents,
      );
      savedCount += savedForRegion;

      onProgress?.call(
        '$displayName 완료: ${items.length}건 조회, $savedForRegion건 저장',
      );
    }

    onProgress?.call('적재 완료: $savedCount건 저장했어요.');

    return TourSeedResult(
      regionCount: regions.length,
      fetchedCount: fetchedCount,
      savedCount: savedCount,
      skippedCount: skippedCount,
    );
  }

  List<_RegionInfo> _buildRegions(List<Map<String, dynamic>> items) {
    final regionMap = <String, _RegionInfo>{};

    for (final item in items) {
      final sidoCode = '${item['lDongRegnCd'] ?? ''}'.trim();
      final sidoName = '${item['lDongRegnNm'] ?? ''}'.trim();
      final sigunguCode = '${item['lDongSignguCd'] ?? ''}'.trim();
      final sigunguName = '${item['lDongSignguNm'] ?? ''}'.trim();

      if (sidoCode.isEmpty ||
          sidoName.isEmpty ||
          sigunguCode.isEmpty ||
          sigunguName.isEmpty) {
        continue;
      }

      regionMap['$sidoCode-$sigunguCode'] = _RegionInfo(
        sidoCode: sidoCode,
        sidoName: sidoName,
        sigunguCode: sigunguCode,
        sigunguName: sigunguName,
      );
    }

    final regions = regionMap.values.toList()
      ..sort((a, b) {
        final sidoCompare = a.sidoName.compareTo(b.sidoName);
        if (sidoCompare != 0) {
          return sidoCompare;
        }
        return a.sigunguName.compareTo(b.sigunguName);
      });

    return regions;
  }

  Map<String, dynamic> _buildTourDocument({
    required Map<String, dynamic> item,
    required _RegionInfo region,
    required LatLng center,
  }) {
    final contentId = _resolveContentId(item, region);
    final mapX = _parseDouble(item['mapx']) ?? _parseDouble(item['mapX']);
    final mapY = _parseDouble(item['mapy']) ?? _parseDouble(item['mapY']);
    final searchableText = _collectText(item);

    return {
      ...item,
      'contentId': contentId,
      'mapX': mapX,
      'mapY': mapY,
      'petType': _inferPetType(searchableText),
      'petSize': _inferPetSize(searchableText),
      'indoorAllowed': _inferIndoorAllowed(searchableText),
      'outdoorOnly': _inferOutdoorOnly(searchableText),
      'leashRequired': _inferLeashRequired(searchableText),
      'placeType': _inferPlaceType(item),
      'parkingAvailable': _inferParkingAvailable(searchableText),
      'seedRegionSidoCode': region.sidoCode,
      'seedRegionSidoName': region.sidoName,
      'seedRegionSigunguCode': region.sigunguCode,
      'seedRegionSigunguName': region.sigunguName,
      'seedCenterLat': center.latitude,
      'seedCenterLng': center.longitude,
      'source': 'KorPetTourService2',
    };
  }

  String _resolveContentId(Map<String, dynamic> item, _RegionInfo region) {
    final contentId = '${item['contentid'] ?? ''}'.trim();
    if (contentId.isNotEmpty && contentId != 'null') {
      return contentId;
    }

    final title = '${item['title'] ?? ''}'.trim();
    final address = '${item['addr1'] ?? ''}'.trim();
    return '${region.sidoCode}_${region.sigunguCode}_${title}_$address';
  }

  double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }

  String _collectText(Map<String, dynamic> item) {
    return item.values
        .whereType<Object?>()
        .map((value) => '$value'.toLowerCase())
        .join(' ');
  }

  String _inferPetType(String text) {
    if (text.contains('고양이')) {
      return 'cat';
    }
    if (text.contains('강아지') || text.contains('반려견') || text.contains('개')) {
      return 'dog';
    }
    return 'all';
  }

  String _inferPetSize(String text) {
    if (text.contains('소형견')) {
      return 'small';
    }
    if (text.contains('중형견')) {
      return 'medium';
    }
    if (text.contains('대형견')) {
      return 'large';
    }
    return 'all';
  }

  bool _inferIndoorAllowed(String text) {
    return text.contains('실내');
  }

  bool _inferOutdoorOnly(String text) {
    return text.contains('야외') && !text.contains('실내');
  }

  bool _inferLeashRequired(String text) {
    return text.contains('목줄') || text.contains('리드줄');
  }

  String _inferPlaceType(Map<String, dynamic> item) {
    for (final key in [
      'lclsSystm1',
      'lclsSystm2',
      'lclsSystm3',
      'cat1',
      'cat2',
      'cat3',
    ]) {
      final value = '${item[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return 'unknown';
  }

  bool _inferParkingAvailable(String text) {
    if (text.contains('주차 불가') || text.contains('주차불가')) {
      return false;
    }
    return text.contains('주차');
  }
}

class _RegionInfo {
  const _RegionInfo({
    required this.sidoCode,
    required this.sidoName,
    required this.sigunguCode,
    required this.sigunguName,
  });

  final String sidoCode;
  final String sidoName;
  final String sigunguCode;
  final String sigunguName;
}
