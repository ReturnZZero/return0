import 'package:flutter/material.dart';

import '../../common/api/favorite_service.dart';
import '../home/home_detail_page.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({Key? key}) : super(key: key);

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final _favoriteService = const FavoriteService();
  final List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = false;
  late final VoidCallback _listener;

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
    return Scaffold(
      appBar: AppBar(title: const Text('찜')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(child: Text('찜한 장소가 없습니다.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemBuilder: (context, index) {
                    final item = _favorites[index];
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
                                  onPressed: () => _removeFavorite(item),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: _favorites.length,
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
