import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'google_geocoding_service.dart';
import 'kor_tour_service.dart';

class MapService {
  const MapService({
    KorTourService? korTourService,
    GoogleGeocodingService? geocodingService,
  })  : _korTourService = korTourService ?? const KorTourService(),
        _geocodingService = geocodingService ?? const GoogleGeocodingService();

  final KorTourService _korTourService;
  final GoogleGeocodingService _geocodingService;

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 꺼져 있어요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 필요해요.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('설정에서 위치 권한을 허용해 주세요.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<List<Map<String, dynamic>>> fetchNearbyItems({
    required LatLng current,
    int radius = 20000,
    String? lDongRegnCd,
    String? lDongSignguCd,
  }) async {
    return _korTourService.fetchLocationBasedList(
      mapX: current.longitude,
      mapY: current.latitude,
      radius: radius,
      lDongRegnCd: lDongRegnCd,
      lDongSignguCd: lDongSignguCd,
    );
  }

  Future<List<Marker>> fetchNearbyMarkers({
    required LatLng current,
    int radius = 20000,
    String? lDongRegnCd,
    String? lDongSignguCd,
  }) async {
    final items = await fetchNearbyItems(
      current: current,
      radius: radius,
      lDongRegnCd: lDongRegnCd,
      lDongSignguCd: lDongSignguCd,
    );

    return items
        .map((item) {
          final mapX = double.tryParse('${item['mapx']}');
          final mapY = double.tryParse('${item['mapy']}');
          if (mapX == null || mapY == null) {
            return null;
          }
          final title = '${item['title'] ?? '이름 없음'}';
          final address = '${item['addr1'] ?? ''}';
          return Marker(
            markerId: MarkerId('item_${item['contentid'] ?? title}'),
            position: LatLng(mapY, mapX),
            infoWindow: InfoWindow(title: title, snippet: address),
          );
        })
        .whereType<Marker>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchLDongCodes({
    int numOfRows = 1000,
    String mobileOS = 'IOS',
    String mobileApp = 'mypettrip',
    String lDongListYn = 'Y',
  }) async {
    return _korTourService.fetchLDongCodes(
      numOfRows: numOfRows,
      mobileOS: mobileOS,
      mobileApp: mobileApp,
      lDongListYn: lDongListYn,
    );
  }

  Future<List<Map<String, dynamic>>> searchKeyword({
    required String keyword,
    String? lclsSystm1,
    String mobileOS = 'IOS',
    String mobileApp = 'mypettrip',
    String arrange = 'O',
  }) async {
    return _korTourService.searchKeyword(
      keyword: keyword,
      lclsSystm1: lclsSystm1,
      mobileOS: mobileOS,
      mobileApp: mobileApp,
      arrange: arrange,
    );
  }

  Future<LatLng> geocodeAddress(String address) async {
    final result = await _geocodingService.geocodeAddress(address);
    return LatLng(result['lat']!, result['lng']!);
  }
}
