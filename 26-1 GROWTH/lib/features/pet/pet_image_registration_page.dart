import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/api/pet_profile_service.dart';

class PetImageRegistrationPage extends StatefulWidget {
  const PetImageRegistrationPage({super.key, required this.petData});

  final Map<String, dynamic> petData;

  @override
  State<PetImageRegistrationPage> createState() =>
      _PetImageRegistrationPageState();
}

class _PetImageRegistrationPageState extends State<PetImageRegistrationPage> {
  final _imagePicker = ImagePicker();
  final _petProfileService = const PetProfileService();

  String? _selectedImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final imagePath = '${widget.petData['imagePath'] ?? ''}'.trim();
    _selectedImagePath = imagePath.isEmpty ? null : imagePath;
  }

  Future<void> _showImageSourceSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFE9E9E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8B8B8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSheetButton(
                  context: context,
                  label: '사진 촬영하기',
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(height: 10),
                _buildSheetButton(
                  context: context,
                  label: '앨범에서 선택하기',
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _buildSheetButton(
                  context: context,
                  label: '취소',
                  isCancel: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    bool isCancel = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: isCancel ? const Color(0xFF666666) : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isCancel ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile == null) {
        return;
      }

      final savedPath = await _petProfileService.savePetImage(
        sourcePath: pickedFile.path,
        fileNamePrefix:
            '${widget.petData['petName'] ?? widget.petData['name'] ?? 'pet'}',
      );

      if (!mounted) {
        return;
      }

      setState(() => _selectedImagePath = savedPath);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지를 불러오지 못했어요: $error')));
    }
  }

  Future<void> _completeRegistration() async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = await _petProfileService.upsertPetProfile({
        ...widget.petData,
        'imagePath': _selectedImagePath,
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(profile);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFD54A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('반려동물 등록'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.35),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '아이의 사진을 등록해 주세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () => _showImageSourceSheet(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: _selectedImagePath == null
                              ? Image.asset(
                                  'assets/icon_reg_default.png',
                                  width: 156,
                                  height: 156,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_selectedImagePath!),
                                  width: 156,
                                  height: 156,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return Image.asset(
                                      'assets/icon_reg_default.png',
                                      width: 156,
                                      height: 156,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: _completeRegistration,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF666666),
                        ),
                        child: const Text(
                          '나중에등록하기',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _completeRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFE0B93C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    _isSaving ? '저장 중...' : '완료',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
