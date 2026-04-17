import 'package:flutter/material.dart';

import '../../common/api/favorite_service.dart';
import '../../common/api/firestore_service.dart';
import 'home_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _favoriteService = const FavoriteService();
  final _firestoreService = FirestoreService();
  final List<Map<String, dynamic>> _results = [];
  final Set<String> _favoriteIds = {};

  final List<_CategoryItem> _categories = const [
    _CategoryItem(label: '숙박', assetPath: 'assets/icon_house.png'),
    _CategoryItem(label: '행사', assetPath: 'assets/icon_walk.png'),
    _CategoryItem(label: '체험관광', assetPath: 'assets/icon_cafe.png'),
    _CategoryItem(label: '음식', assetPath: 'assets/icon_food.png'),
    _CategoryItem(label: '역사관광', assetPath: 'assets/icon_cafe.png'),
    _CategoryItem(label: '스포츠', assetPath: 'assets/icon_walk.png'),
    _CategoryItem(label: '자연관광', assetPath: 'assets/icon_cafe.png'),
    _CategoryItem(label: '문화관광', assetPath: 'assets/icon_cafe.png'),
  ];

  int? _selectedIndex;
  bool _isSearching = false;

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

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final list = await _favoriteService.loadFavorites();
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(list.map(FavoriteService.itemId));
    });
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final list = await _favoriteService.toggleFavorite(item);
    if (!mounted) {
      return;
    }
    setState(() {
      _favoriteIds
        ..clear()
        ..addAll(list.map(FavoriteService.itemId));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검색어를 입력해 주세요.')));
      return;
    }

    final selectedLabel = _selectedIndex == null
        ? null
        : _categories[_selectedIndex!].label;
    final lclsSystm1 = selectedLabel == null
        ? null
        : _categoryCodeMap[selectedLabel];

    setState(() => _isSearching = true);
    try {
      final results = await _firestoreService.searchTourPlaces(
        keyword: keyword,
        categoryCode: lclsSystm1,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results
          ..clear()
          ..addAll(results);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('검색 결과 ${results.length}건')));
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

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFFDE59);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Center(child: Image.asset('assets/icon_login.png', width: 240)),
                const SizedBox(height: 24),
                const Text(
                  '반가워요.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  '오늘은 누구와 어디로 떠나볼까요?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                _buildSearchBar(),
                const SizedBox(height: 24),
                _buildCategoryGrid(accentColor),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildResultsList(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '검색 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final item = _results[index];
            final title = '${item['title'] ?? '이름 없음'}';
            final address = '${item['addr1'] ?? ''}';
            final isFavorite = _favoriteIds.contains(
              FavoriteService.itemId(item),
            );
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
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HomeDetailPage(item: item),
                    ),
                  );
                  await _loadFavorites();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _toggleFavorite(item),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                          ),
                          color: isFavorite ? Colors.redAccent : Colors.black54,
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
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: _results.length,
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(Color accentColor) {
    final double itemWidth =
        (MediaQuery.of(context).size.width - 16 * 2 - 12 * 3) / 4;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(_categories.length, (index) {
        final item = _categories[index];
        final isSelected = _selectedIndex == index;
        return SizedBox(
          width: itemWidth,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _selectedIndex = _selectedIndex == index ? null : index;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E6E6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CategoryIcon(item: item),
                  const SizedBox(height: 8),
                  Text(item.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '어디로 떠나고 싶으신가요?',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDE59),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isSearching
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    _search();
                  },
            child: Text(_isSearching ? '검색 중...' : '검색'),
          ),
        ),
      ],
    );
  }
}

class _CategoryItem {
  const _CategoryItem({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.item});

  final _CategoryItem item;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      item.assetPath,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
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
