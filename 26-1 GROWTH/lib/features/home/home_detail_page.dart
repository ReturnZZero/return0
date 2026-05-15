import 'package:flutter/material.dart';

import '../../common/api/favorite_service.dart';
import '../../common/api/firebase_auth_service.dart';
import '../../common/api/firestore_service.dart';

class HomeDetailPage extends StatefulWidget {
  const HomeDetailPage({Key? key, required this.item}) : super(key: key);

  final Map<String, dynamic> item;

  @override
  State<HomeDetailPage> createState() => _HomeDetailPageState();
}

class _HomeDetailPageState extends State<HomeDetailPage> {
  final _authService = FirebaseAuthService();
  final _favoriteService = const FavoriteService();
  final _firestoreService = FirestoreService();
  final _reviewController = TextEditingController();
  bool _isFavorite = false;
  bool _isSubmittingReview = false;
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    _loadNickname();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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

  Future<void> _loadNickname() async {
    final user = _authService.currentUser;
    if (user == null) {
      return;
    }

    final nickname = await _firestoreService.ensureUserNickname(uid: user.uid);
    if (!mounted) {
      return;
    }
    setState(() => _nickname = nickname);
  }

  String get _placeId {
    final contentId = '${widget.item['contentId'] ?? ''}'.trim();
    if (contentId.isNotEmpty) {
      return contentId;
    }
    final docId = '${widget.item['docId'] ?? ''}'.trim();
    if (docId.isNotEmpty) {
      return docId;
    }
    return FavoriteService.itemId(widget.item);
  }

  Future<void> _submitReview() async {
    final user = _authService.currentUser;
    final content = _reviewController.text.trim();
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 리뷰를 작성할 수 있어요.')));
      return;
    }
    if (content.isEmpty || _isSubmittingReview) {
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      final nickname = _nickname.isEmpty
          ? await _firestoreService.ensureUserNickname(uid: user.uid)
          : _nickname;
      await _firestoreService.addPlaceReview(
        placeId: _placeId,
        userId: user.uid,
        nickname: nickname,
        content: content,
      );
      _reviewController.clear();
      FocusScope.of(context).unfocus();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리뷰를 등록했어요.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리뷰 등록에 실패했어요: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.item['title'] ?? '이름 없음'}';
    final address = '${widget.item['addr1'] ?? ''}';
    final imageUrl = '${widget.item['firstimage'] ?? ''}';
    final tel = '${widget.item['tel'] ?? ''}'.trim();
    final homepage = '${widget.item['homepage'] ?? ''}'.trim();
    final overviewRaw = '${widget.item['overview'] ?? ''}'.trim();
    final overview = overviewRaw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final shopInfoItems = _buildShopInfoItems(widget.item);
    final shopInfoTags = _buildShopInfoTags(widget.item);

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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
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
              if (shopInfoItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  '확인하면 좋은 정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < shopInfoItems.length; i++) ...[
                        _InfoRow(
                          label: shopInfoItems[i].label,
                          value: shopInfoItems[i].value,
                        ),
                        if (i < shopInfoItems.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
              if (shopInfoTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: shopInfoTags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4C4),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFF0D66A)),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A432F),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
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
              const SizedBox(height: 24),
              const Text(
                '리뷰',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nickname.isEmpty
                          ? '닉네임으로 리뷰를 남겨보세요.'
                          : '$_nickname님으로 리뷰 작성',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reviewController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: '이 장소에 대한 후기를 남겨주세요',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmittingReview ? null : _submitReview,
                        child: Text(_isSubmittingReview ? '등록 중...' : '리뷰 작성'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreService.watchPlaceReviews(placeId: _placeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final reviews = snapshot.data ?? const [];
                  if (reviews.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: const Text(
                        '아직 등록된 리뷰가 없습니다.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }

                  return Column(
                    children: reviews
                        .map(
                          (review) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E5E5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${review['nickname'] ?? '닉네임'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${review['content'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  List<_DetailInfoItem> _buildShopInfoItems(Map<String, dynamic> item) {
    final items = <_DetailInfoItem>[];

    final placeType = _formatPlaceType(item['placeType']);
    if (placeType.isNotEmpty) {
      items.add(_DetailInfoItem(label: '장소 유형', value: placeType));
    }

    final petSize = _formatPetSize(item['petSize']);
    if (petSize.isNotEmpty) {
      items.add(_DetailInfoItem(label: '입장가능', value: petSize));
    }

    return items;
  }

  List<String> _buildShopInfoTags(Map<String, dynamic> item) {
    final tags = <String>[];
    final petSize = '${item['petSize'] ?? ''}'.trim().toUpperCase();

    if (item['indoorAllowed'] == true) {
      tags.add('실내 이용 가능');
    }
    if (item['parkingAvailable'] == true) {
      tags.add('주차 가능');
    }
    if (item['leashRequired'] == true) {
      tags.add('목줄 필수');
    }
    if (item['isFierceDog'] == true) {
      tags.add('맹견 가능');
    }
    if (petSize == 'L') {
      tags.add('대형견가능');
    }

    final checklist = item['travelChecklist'];
    if (checklist is List) {
      for (final value in checklist.take(3)) {
        final text = '$value'.trim();
        if (text.isNotEmpty &&
            text != '중성화 확인' &&
            text != '실내' &&
            text != '주차') {
          tags.add(text == '목줄' ? '목줄 필수' : text);
        }
      }
    }

    return tags.toSet().toList();
  }

  String _formatPlaceType(dynamic value) {
    final text = '${value ?? ''}'.trim().toUpperCase();
    switch (text) {
      case 'AC':
        return '숙소';
      case 'FD':
        return '음식점';
      case 'SH':
        return '쇼핑';
      case 'LS':
        return '스포츠';
      case 'EX':
        return '체험관광';
      case 'NA':
        return '자연관광';
      case 'VE':
        return '문화관광';
      case 'HS':
        return '역사관광';
      default:
        return text;
    }
  }

  String _formatPetSize(dynamic value) {
    final text = '${value ?? ''}'.trim().toUpperCase();
    switch (text) {
      case 'S':
        return '소형견 미만 (10kg)';
      case 'M':
        return '중형견 미만 (25kg)';
      case 'L':
        return '제한없음';
      default:
        return '';
    }
  }
}

class _DetailInfoItem {
  const _DetailInfoItem({required this.label, required this.value});

  final String label;
  final String value;
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
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }
}
