import 'package:flutter/material.dart';

import '../../common/api/favorite_service.dart';
import '../home/home_detail_page.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({Key? key}) : super(key: key);

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  static const List<String> _categoryOptions = [
    '숙소',
    '쇼핑',
    '음식점',
    '스포츠',
    '체험관광',
    '자연관광',
    '문화관광',
    '역사관광',
  ];
  static const Map<String, String> _categoryCodeMap = {
    '숙소': 'AC',
    '쇼핑': 'SH',
    '음식점': 'FD',
    '스포츠': 'LS',
    '체험관광': 'EX',
    '자연관광': 'NA',
    '문화관광': 'VE',
    '역사관광': 'HS',
  };

  final _favoriteService = const FavoriteService();
  final List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = false;
  late final VoidCallback _listener;
  String? _selectedCategory;

  List<Map<String, dynamic>> get _filteredFavorites {
    final selectedCode = _selectedCategory == null
        ? null
        : _categoryCodeMap[_selectedCategory!];
    if (selectedCode == null || selectedCode.isEmpty) {
      return _favorites;
    }

    return _favorites.where((item) {
      final lclsSystm1 = '${item['lclsSystm1'] ?? ''}'.trim().toUpperCase();
      final placeType = '${item['placeType'] ?? ''}'.trim().toUpperCase();
      return lclsSystm1 == selectedCode || placeType == selectedCode;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _listener = () => _loadFavorites();
    FavoriteService.changeTick.addListener(_listener);
    _loadFavorites();
  }

  @override
  void dispose() {
    FavoriteService.changeTick.removeListener(_listener);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final list = await _favoriteService.loadFavorites();
    if (!mounted) {
      return;
    }
    setState(() {
      _favorites
        ..clear()
        ..addAll(list);
      _isLoading = false;
    });
  }

  Future<void> _removeFavorite(Map<String, dynamic> item) async {
    await _favoriteService.toggleFavorite(item);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFF4C84A);
    final filteredFavorites = _filteredFavorites;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('찜'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 12),
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
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: _categoryOptions.length,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _favorites.isEmpty
                      ? const Center(child: Text('찜한 장소가 없습니다.'))
                      : filteredFavorites.isEmpty
                      ? const Center(child: Text('선택한 카테고리의 찜 장소가 없습니다.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemBuilder: (context, index) {
                            final item = filteredFavorites[index];
                            final title = '${item['title'] ?? '이름 없음'}';
                            final address = '${item['addr1'] ?? ''}';
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E5E5),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0F000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HomeDetailPage(item: item),
                                    ),
                                  );
                                  await _loadFavorites();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                address.isEmpty
                                                    ? '주소 정보 없음'
                                                    : address,
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () =>
                                              _removeFavorite(item),
                                          icon: const Icon(Icons.favorite),
                                          color: Colors.redAccent,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _NetworkImageWithFallback(
                                        imageUrl: '${item['firstimage'] ?? ''}',
                                        height: 160,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemCount: filteredFavorites.length,
                        ),
                ),
              ],
            ),
    );
  }
}

class _NetworkImageWithFallback extends StatelessWidget {
  const _NetworkImageWithFallback({
    required this.imageUrl,
    required this.height,
  });

  final String imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty || imageUrl == 'null') {
      return Image.asset(
        'assets/img_default.png',
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          'assets/img_default.png',
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
