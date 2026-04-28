import 'dart:convert';

import 'package:flutter/material.dart';

import '../../common/api/firestore_service.dart';
import '../../common/api/openai_service.dart';
import '../../common/api/pet_profile_service.dart';
import '../home/home_detail_page.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({Key? key}) : super(key: key);

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage>
    with AutomaticKeepAliveClientMixin {
  static const _prettyJsonEncoder = JsonEncoder.withIndent('  ');
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _openAiService = OpenAiService();
  final _petProfileService = const PetProfileService();
  final _firestoreService = FirestoreService();
  final List<_ChatMessage> _messages = [];
  Map<String, dynamic>? _selectedPetProfile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedPetProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, content: text));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();
    try {
      final history = _messages
          .map(
            (m) => {
              'role': m.role == _ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            },
          )
          .toList();

      final reply = await _openAiService.sendMessage(
        messages: history,
        selectedPetProfile: _selectedPetProfile,
      );
      final recommendations = await _fetchFirestoreRecommendations(reply);

      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.assistant,
            content: _formatAssistantReply(reply),
            recommendations: recommendations,
          ),
        );
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSelectedPetProfile() async {
    final profile = await _petProfileService.loadSelectedPetProfile();
    if (!mounted) {
      return;
    }
    setState(() => _selectedPetProfile = profile);
  }

  Future<List<Map<String, dynamic>>> _fetchFirestoreRecommendations(
    String reply,
  ) async {
    final jsonRange = _findJsonRange(reply);
    if (jsonRange == null) {
      return const [];
    }

    try {
      final jsonText = reply.substring(jsonRange.$1, jsonRange.$2);
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        return const [];
      }

      final filters = Map<String, dynamic>.from(decoded);
      final mapX = _asDouble(filters['mapX']);
      final mapY = _asDouble(filters['mapY']);
      if (mapX == null || mapY == null) {
        return const [];
      }

      return _firestoreService.recommendTourPlacesForAi(filters: filters);
    } catch (_) {
      return const [];
    }
  }

  String _formatAssistantReply(String reply) {
    final jsonRange = _findJsonRange(reply);
    if (jsonRange == null) {
      return reply;
    }

    try {
      final jsonText = reply.substring(jsonRange.$1, jsonRange.$2);
      final decoded = jsonDecode(jsonText);
      final prettyJson = _prettyJsonEncoder.convert(decoded);
      final prefix = reply.substring(0, jsonRange.$1).trimRight();
      final suffix = reply.substring(jsonRange.$2).trimLeft();
      if (prefix.isEmpty) {
        if (suffix.isEmpty) {
          return prettyJson;
        }
        return '$prettyJson\n\n$suffix';
      }
      if (suffix.isEmpty) {
        return '$prefix\n\n$prettyJson';
      }
      return '$prefix\n\n$prettyJson\n\n$suffix';
    } catch (_) {
      return reply;
    }
  }

  (int, int)? _findJsonRange(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start) {
      return null;
    }
    return (start, end + 1);
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse('$value');
  }

  Widget _buildRecommendationCarousel(List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, top: 4, bottom: 10),
          child: Text(
            '추천 장소',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final title = '${item['title'] ?? '이름 없음'}';
              final address = '${item['addr1'] ?? ''}';
              return SizedBox(
                width: 264,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HomeDetailPage(item: item),
                        ),
                      );
                    },
                    child: Container(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            address.isEmpty ? '주소 정보 없음' : address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _NetworkImageWithFallback(
                                imageUrl: '${item['firstimage'] ?? ''}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('AI 채팅'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message.role == _ChatRole.user;
                  return Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFFFFDE59)
                                : const Color(0xFFF2F2F2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.content,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      if (!isUser && message.recommendations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 8),
                          child: _buildRecommendationCarousel(
                            message.recommendations,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('AI 응답 중...'),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: '메시지를 입력하세요',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _sendMessage();
                            },
                      child: const Text('전송'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  _ChatMessage({
    required this.role,
    required this.content,
    this.recommendations = const [],
  });

  final _ChatRole role;
  final String content;
  final List<Map<String, dynamic>> recommendations;
}

class _NetworkImageWithFallback extends StatelessWidget {
  const _NetworkImageWithFallback({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty || imageUrl == 'null') {
      return Image.asset(
        'assets/img_default.png',
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          'assets/img_default.png',
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
