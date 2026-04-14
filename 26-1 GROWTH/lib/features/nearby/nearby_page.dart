import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../common/api/map_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({Key? key}) : super(key: key);

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  static const int _defaultSearchRadius = 4000;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final _mapService = MapService();
  final List<Map<String, dynamic>> _items = [];

  static const LatLng _defaultCenter = LatLng(37.5665, 126.9780);
  static const List<String> _categoryOptions = [
    '숙박',
    '행사',
    '체험관광',
    '음식',
    '역사관광',
    '스포츠',
    '자연관광',
    '문화관광',
  ];
  static const Map<String, String> _categoryCodeMap = {
    '숙박': 'AC',
    '행사': 'EV',
    '체험관광': 'EX',
    '음식': 'FD',
    '역사관광': 'HS',
    '스포츠': 'LS',
    '자연관광': 'NA',
    '문화관광': 'VE',
  };

  String? _selectedCategory;
  LatLng _mapCenter = _defaultCenter;
  bool _isSearching = false;
  bool _showList = false;
  bool _isLoadingRegions = false;

  List<Map<String, String>> _sidoList = const [
    {'code': 'sido_seoul', 'name': '서울특별시'},
    {'code': 'sido_busan', 'name': '부산광역시'},
  ];
  Map<String, List<Map<String, String>>> _sigunguBySido = const {
    'sido_seoul': [
      {'code': 'sigungu_seodaemun', 'name': '서대문구'},
      {'code': 'sigungu_dongjak', 'name': '동작구'},
      {'code': 'sigungu_mapo', 'name': '마포구'},
      {'code': 'sigungu_gangnam', 'name': '강남구'},
    ],
    'sido_busan': [
      {'code': 'sigungu_haeundae', 'name': '해운대구'},
      {'code': 'sigungu_suyeong', 'name': '수영구'},
    ],
  };
  String _selectedSidoCode = 'sido_seoul';
  String _selectedSigunguCode = 'sigungu_seodaemun';

  List<Map<String, String>> get _currentSigunguList {
    return _sigunguBySido[_selectedSidoCode] ?? const [];
  }

  String get _selectedSidoName {
    return _sidoList.firstWhere(
          (item) => item['code'] == _selectedSidoCode,
          orElse: () => const {'name': ''},
        )['name'] ??
        '';
  }

  String get _selectedSigunguName {
    return _currentSigunguList.firstWhere(
          (item) => item['code'] == _selectedSigunguCode,
          orElse: () => const {'name': ''},
        )['name'] ??
        '';
  }

  @override
  void initState() {
    super.initState();
    _loadLDongCodes();
  }

  Future<void> _loadLDongCodes() async {
    setState(() => _isLoadingRegions = true);
    try {
      final items = await _mapService.fetchLDongCodes();
      if (!mounted || items.isEmpty) {
        return;
      }

      final Map<String, String> sidoMap = {};
      final Map<String, Map<String, String>> sigunguMap = {};

      for (final item in items) {
        final regnCode = '${item['lDongRegnCd'] ?? ''}'.trim();
        final regnName = '${item['lDongRegnNm'] ?? ''}'.trim();
        final signguCode = '${item['lDongSignguCd'] ?? ''}'.trim();
        final signguName = '${item['lDongSignguNm'] ?? ''}'.trim();

        if (regnCode.isNotEmpty && regnName.isNotEmpty) {
          sidoMap[regnCode] = regnName;
        }
        if (regnCode.isNotEmpty && signguCode.isNotEmpty) {
          sigunguMap.putIfAbsent(regnCode, () => {});
          if (signguName.isNotEmpty) {
            sigunguMap[regnCode]![signguCode] = signguName;
          }
        }
      }

      if (sidoMap.isEmpty) {
        return;
      }

      final newSidoList = sidoMap.entries
          .map((entry) => {'code': entry.key, 'name': entry.value})
          .toList();

      newSidoList.sort((a, b) => a['name']!.compareTo(b['name']!));

      final Map<String, List<Map<String, String>>> newSigunguBySido = {};
      for (final entry in sigunguMap.entries) {
        final list = entry.value.entries
            .map((e) => {'code': e.key, 'name': e.value})
            .toList();
        list.sort((a, b) => a['name']!.compareTo(b['name']!));
        newSigunguBySido[entry.key] = list;
      }

      final seoulEntry = newSidoList.firstWhere(
        (item) => (item['name'] ?? '').contains('서울'),
        orElse: () => newSidoList.first,
      );
      final seoulCode = seoulEntry['code']!;
      final sigunguList = newSigunguBySido[seoulCode] ?? const [];
      final seodaemunEntry = sigunguList.firstWhere(
        (item) => (item['name'] ?? '').contains('서대문'),
        orElse: () => sigunguList.isNotEmpty ? sigunguList.first : const {},
      );

      setState(() {
        _sidoList = newSidoList;
        _sigunguBySido = newSigunguBySido;
        _selectedSidoCode = seoulCode;
        _selectedSigunguCode = (seodaemunEntry['code'] ?? _selectedSigunguCode);
      });

      await _searchByRegion();
    } catch (_) {
      // 실패 시 기본 목록 유지
    } finally {
      if (mounted) {
        setState(() => _isLoadingRegions = false);
      }
    }
  }

  Future<double> _calculateVisibleRadius(LatLng center) async {
    final controller = _mapController;
    if (controller == null) {
      return _defaultSearchRadius.toDouble();
    }

    try {
      final bounds = await controller.getVisibleRegion();
      final distToNe = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        bounds.northeast.latitude,
        bounds.northeast.longitude,
      );
      final distToSw = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        bounds.southwest.latitude,
        bounds.southwest.longitude,
      );
      final radius = distToNe > distToSw ? distToNe : distToSw;
      return radius.isFinite && radius > 0
          ? radius
          : _defaultSearchRadius.toDouble();
    } catch (_) {
      return _defaultSearchRadius.toDouble();
    }
  }

  Future<void> _searchAt(LatLng center, {int? radius}) async {
    if (_isSearching) {
      return;
    }
    setState(() => _isSearching = true);

    try {
      final categoryCode = _selectedCategory == null
          ? null
          : _categoryCodeMap[_selectedCategory!];
      final items = await _mapService.fetchNearbyItems(
        current: center,
        radius: radius ?? _defaultSearchRadius,
        categoryCode: categoryCode,
      );
      final markers = _mapService.buildMarkersFromItems(items);

      if (!mounted) {
        return;
      }

      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _markers
          ..removeWhere((marker) => marker.markerId.value.startsWith('item_'))
          ..addAll(markers);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await _mapService.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);

      setState(() {
        _markers
          ..removeWhere((marker) => marker.markerId.value == 'me')
          ..add(
            Marker(
              markerId: const MarkerId('me'),
              position: current,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: const InfoWindow(title: '내 위치'),
            ),
          );
        _mapCenter = current;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: current, zoom: 16),
        ),
      );

      await _animateToRadius(current, _defaultSearchRadius.toDouble());
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _searchByRegion() async {
    if (_selectedSidoName.isEmpty || _selectedSigunguName.isEmpty) {
      return;
    }
    try {
      final target = await _mapService.geocodeAddress(
        '${_selectedSidoName} ${_selectedSigunguName}',
      );
      _mapCenter = target;
      await _animateToRadius(target, _defaultSearchRadius.toDouble());
      await _searchAt(target, radius: _defaultSearchRadius);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('주소 좌표 변환에 실패했어요.')));
    }
  }

  Future<void> _animateToRadius(LatLng center, double radiusMeters) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final latRadians = center.latitude * math.pi / 180;
    final latDelta = radiusMeters / 111320;
    final lngDelta = radiusMeters / (111320 * math.cos(latRadians));

    final southwest = LatLng(
      center.latitude - latDelta,
      center.longitude - lngDelta,
    );
    final northeast = LatLng(
      center.latitude + latDelta,
      center.longitude + lngDelta,
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southwest, northeast: northeast),
        48,
      ),
    );
  }

  Widget _buildOverlayButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFFDE59);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSidoCode,
                      decoration: _dropdownDecoration(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _sidoList
                          .map(
                            (item) => DropdownMenuItem(
                              value: item['code'],
                              child: Text(item['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingRegions
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              final nextSigungu =
                                  _sigunguBySido[value]?.first['code'];
                              setState(() {
                                _selectedSidoCode = value;
                                _selectedSigunguCode =
                                    nextSigungu ?? _selectedSigunguCode;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSigunguCode,
                      decoration: _dropdownDecoration(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _currentSigunguList
                          .map(
                            (item) => DropdownMenuItem(
                              value: item['code'],
                              child: Text(item['name'] ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingRegions
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedSigunguCode = value);
                            },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final label = _categoryOptions[index];
                  final isSelected = _selectedCategory == label;
                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    selectedColor: accentColor.withOpacity(0.35),
                    side: const BorderSide(color: accentColor),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = _selectedCategory == label
                            ? null
                            : label;
                      });
                      _searchByRegion();
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _categoryOptions.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSearching ? null : _searchByRegion,
                  child: Text(_isSearching ? '검색 중...' : '검색'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Stack(
                children: [
                  IndexedStack(
                    index: _showList ? 1 : 0,
                    children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: _defaultCenter,
                          zoom: 14,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        markers: _markers,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        onCameraMove: (position) {
                          _mapCenter = position.target;
                        },
                      ),
                      _buildListView(),
                    ],
                  ),
                  if (!_showList)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Center(
                        child: _buildOverlayButton(
                          label: _isSearching ? '검색 중...' : '이 지역 재검색',
                          onPressed: _isSearching
                              ? () {}
                              : () async {
                                  final radius = await _calculateVisibleRadius(
                                    _mapCenter,
                                  );
                                  await _searchAt(
                                    _mapCenter,
                                    radius: radius.round(),
                                  );
                                },
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: _buildOverlayButton(
                        label: _showList ? '지도보기' : '목록보기',
                        onPressed: () => setState(() => _showList = !_showList),
                      ),
                    ),
                  ),
                  if (!_showList)
                    Positioned(
                      right: 16,
                      bottom: 80,
                      child: FloatingActionButton(
                        onPressed: _moveToCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_items.isEmpty) {
      return const Center(child: Text('표시할 장소가 없습니다.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemBuilder: (context, index) {
        final item = _items[index];
        final title = '${item['title'] ?? '이름 없음'}';
        final address = '${item['addr1'] ?? ''}';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5E5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                address.isEmpty ? '주소 정보 없음' : address,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: _items.length,
    );
  }
}
