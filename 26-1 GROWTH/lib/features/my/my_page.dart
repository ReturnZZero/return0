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
  final _tourSeedService = TourSeedService();
  final _firestoreService = FirestoreService();
  bool _isSeeding = false;
  bool _hasSeededTourPlaces = false;
  bool _isCheckingTourPlaces = true;
  String _seedStatus = '테스트 버튼을 누르면 지역 데이터를 Firestore에 적재합니다.';
  TourSeedResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadTourPlaceStatus();
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
        SnackBar(content: Text('테스트 적재 완료: ${result.savedCount}건 저장')),
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
          _seedStatus = 'tour_places 데이터가 이미 있어서 테스트 버튼이 비활성화됐습니다.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text(
                '마이',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('로그아웃'),
                ),
              ),
              const Spacer(),
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
                      'DB 테스트 적재',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _seedStatus,
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    if (_lastResult != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '지역 ${_lastResult!.regionCount}개, 조회 ${_lastResult!.fetchedCount}건, 저장 ${_lastResult!.savedCount}건',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    _isSeeding || _isCheckingTourPlaces || _hasSeededTourPlaces
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
                      ? '이미 적재됨'
                      : '테스트',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
