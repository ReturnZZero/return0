import 'package:flutter/material.dart';

import '../../common/api/favorite_service.dart';

class HomeDetailPage extends StatefulWidget {
  const HomeDetailPage({Key? key, required this.item}) : super(key: key);

  final Map<String, dynamic> item;

  @override
  State<HomeDetailPage> createState() => _HomeDetailPageState();
}

class _HomeDetailPageState extends State<HomeDetailPage> {
  final _favoriteService = const FavoriteService();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final id = FavoriteService.itemId(widget.item);
    final isFav = await _favoriteService.isFavorite(id);
    if (!mounted) {
      return;
    }
    setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    await _favoriteService.toggleFavorite(widget.item);
    if (!mounted) {
      return;
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.item['title'] ?? '이름 없음'}';
    final address = '${widget.item['addr1'] ?? ''}';
    final imageUrl = '${widget.item['firstimage'] ?? ''}';
    final tel = '${widget.item['tel'] ?? ''}'.trim();
    final homepage = '${widget.item['homepage'] ?? ''}'.trim();
    final overviewRaw = '${widget.item['overview'] ?? ''}'.trim();
    final overview =
        overviewRaw.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('상세정보'),
        actions: [
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            color: _isFavorite ? Colors.redAccent : Colors.black54,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _NetworkImageWithFallback(
                imageUrl: imageUrl,
                height: 220,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              address.isEmpty ? '주소 정보 없음' : address,
              style: const TextStyle(color: Colors.black54),
            ),
            if (tel.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(label: '전화', value: tel),
            ],
            if (homepage.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: '홈페이지', value: homepage),
            ],
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '설명',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                overview,
                style: const TextStyle(color: Colors.black87, height: 1.4),
              ),
            ],
          ],
        ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
