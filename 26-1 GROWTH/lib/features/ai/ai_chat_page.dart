import 'dart:convert';

import 'package:flutter/material.dart';

import '../../common/api/firestore_service.dart';
import '../../common/api/openai_service.dart';
import '../../common/api/pet_profile_service.dart';

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
      final enhancedReply = await _appendFirestoreRecommendations(reply);

      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.assistant,
            content: _formatAssistantReply(enhancedReply),
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

  Future<String> _appendFirestoreRecommendations(String reply) async {
    final jsonRange = _findJsonRange(reply);
    if (jsonRange == null) {
      return reply;
    }

    try {
      final jsonText = reply.substring(jsonRange.$1, jsonRange.$2);
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) {
        return reply;
      }

      final filters = Map<String, dynamic>.from(decoded);
      final mapX = _asDouble(filters['mapX']);
      final mapY = _asDouble(filters['mapY']);
      if (mapX == null || mapY == null) {
        return reply;
      }

      final recommendations = await _firestoreService.recommendTourPlacesForAi(
        filters: filters,
      );

      if (recommendations.isEmpty) {
        return '$reply\n\n추천 장소를 아직 찾지 못했어요.';
      }

      final buffer = StringBuffer(reply);
      buffer.write('\n\n추천 장소 3곳:\n');
      for (var i = 0; i < recommendations.length; i++) {
        final item = recommendations[i];
        final title = '${item['title'] ?? '이름 없음'}'.trim();
        final address = '${item['addr1'] ?? '주소 정보 없음'}'.trim();
        buffer.write('${i + 1}. $title');
        if (address.isNotEmpty) {
          buffer.write(' - $address');
        }
        if (i < recommendations.length - 1) {
          buffer.write('\n');
        }
      }
      return buffer.toString();
    } catch (_) {
      return reply;
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
      if (prefix.isEmpty) {
        return prettyJson;
      }
      return '$prefix\n\n$prettyJson';
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
                  return Align(
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
  _ChatMessage({required this.role, required this.content});

  final _ChatRole role;
  final String content;
}
