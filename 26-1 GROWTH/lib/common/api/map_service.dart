import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'kor_tour_service.dart';

class MapService {
  const MapService({KorTourService? korTourService})
      : _korTourService = korTourService ?? const KorTourService();

  final KorTourService _korTourService;

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

  Future<List<Marker>> fetchNearbyMarkers({
    required LatLng current,
    int radius = 20000,
  }) async {
    final items = await _korTourService.fetchLocationBasedList(
      mapX: current.longitude,
      mapY: current.latitude,
      radius: radius,
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
}
