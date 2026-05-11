import 'package:flutter/material.dart';

import '../../common/api/firebase_auth_service.dart';
import '../../common/api/firestore_service.dart';
import '../../common/api/tour_seed_service.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _authService = FirebaseAuthService();
  final _tourSeedService = TourSeedService();
  final _firestoreService = FirestoreService();
  final _nicknameController = TextEditingController();
  bool _isSeeding = false;
  bool _isResetting = false;
  bool _isLoadingNickname = false;
  bool _isSavingNickname = false;
  bool _hasSeededTourPlaces = false;
  bool _isCheckingTourPlaces = true;
  String _seedStatus = 'DB업로드 버튼을 누르면 지역 데이터를 Firestore에 적재합니다.';
  TourSeedResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadNickname();
    _loadTourPlaceStatus();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuthService().signOut();
      messenger.showSnackBar(const SnackBar(content: Text('로그아웃 되었습니다.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('로그아웃에 실패했어요.')));
    }
  }

  Future<void> _loadNickname() async {
    final user = _authService.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isLoadingNickname = true);
    try {
      final nickname = await _firestoreService.ensureUserNickname(
        uid: user.uid,
      );
      if (!mounted) {
        return;
      }
      _nicknameController.text = nickname;
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('닉네임을 불러오지 못했어요: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingNickname = false);
      }
    }
  }

  Future<void> _saveNickname() async {
    final user = _authService.currentUser;
    final nickname = _nicknameController.text.trim();
    if (user == null || nickname.isEmpty || _isSavingNickname) {
      return;
    }

    setState(() => _isSavingNickname = true);
    try {
      await _firestoreService.saveUserNickname(
        uid: user.uid,
        nickname: nickname,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 저장했어요.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('닉네임 저장에 실패했어요: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSavingNickname = false);
      }
    }
  }

  Future<void> _seedTourPlaces() async {
    if (_isSeeding || _hasSeededTourPlaces) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSeeding = true;
      _lastResult = null;
      _seedStatus = '적재를 준비 중입니다...';
    });

    try {
      final result = await _tourSeedService.seedTourPlaces(
        onProgress: (message) {
          if (!mounted) {
            return;
          }
          setState(() => _seedStatus = message);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastResult = result;
        _hasSeededTourPlaces = result.savedCount > 0 || _hasSeededTourPlaces;
        _seedStatus =
            '적재 완료: ${result.savedCount}건 저장, ${result.skippedCount}개 지역 건너뜀';
      });

      messenger.showSnackBar(
        SnackBar(content: Text('DB업로드 완료: ${result.savedCount}건 저장')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _seedStatus = '적재 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text('적재에 실패했어요: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<void> _loadTourPlaceStatus() async {
    setState(() => _isCheckingTourPlaces = true);

    try {
      final hasTourPlaces = await _firestoreService.hasTourPlaces();
      if (!mounted) {
        return;
      }

      setState(() {
        _hasSeededTourPlaces = hasTourPlaces;
        if (hasTourPlaces) {
          _seedStatus = 'tour_places 데이터가 이미 있어서 DB업로드 버튼이 비활성화됐습니다.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _seedStatus = 'Firestore 상태 확인 실패: $error');
    } finally {
      if (mounted) {
        setState(() => _isCheckingTourPlaces = false);
      }
    }
  }

  Future<void> _resetTourPlaces() async {
    if (_isResetting || _isCheckingTourPlaces) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('장소 DB 초기화'),
          content: const Text(
            'tour_places 장소 데이터만 삭제합니다.\n회원가입 정보나 다른 데이터는 삭제되지 않습니다.\n초기화할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isResetting = true;
      _lastResult = null;
      _seedStatus = 'tour_places 데이터를 초기화하는 중입니다...';
    });

    try {
      final deletedCount = await _firestoreService.clearTourPlaces();
      if (!mounted) {
        return;
      }

      setState(() {
        _hasSeededTourPlaces = false;
        _seedStatus = deletedCount > 0
            ? '초기화 완료: tour_places ${deletedCount}건 삭제'
            : '초기화 완료: 삭제할 tour_places 데이터가 없었습니다.';
      });

      messenger.showSnackBar(
        SnackBar(content: Text('tour_places 초기화 완료: ${deletedCount}건 삭제')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _seedStatus = '초기화 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text('초기화에 실패했어요: $error')));
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('마이'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = 20.0;
              const topPadding = 20.0;
              const bottomPadding = 20.0;
              final contentMinHeight =
                  constraints.maxHeight - topPadding - bottomPadding;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentMinHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: () => _logout(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('로그아웃'),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '닉네임',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _nicknameController,
                                enabled:
                                    !_isLoadingNickname && !_isSavingNickname,
                                decoration: InputDecoration(
                                  hintText: _isLoadingNickname
                                      ? '불러오는 중...'
                                      : '닉네임을 입력하세요',
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
                                  onPressed:
                                      _isLoadingNickname || _isSavingNickname
                                      ? null
                                      : _saveNickname,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: Text(
                                    _isSavingNickname ? '저장 중...' : '닉네임 저장',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed:
                              _isSeeding ||
                                  _isResetting ||
                                  _isCheckingTourPlaces ||
                                  _hasSeededTourPlaces
                              ? null
                              : _seedTourPlaces,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isCheckingTourPlaces
                                ? '상태 확인 중...'
                                : _isSeeding
                                ? '적재 중...'
                                : _hasSeededTourPlaces
                                ? '테스트DB업로드 완료'
                                : '테스트DB업로드',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed:
                              _isSeeding ||
                                  _isResetting ||
                                  _isCheckingTourPlaces
                              ? null
                              : _resetTourPlaces,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(_isResetting ? '초기화 중...' : '초기화'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
