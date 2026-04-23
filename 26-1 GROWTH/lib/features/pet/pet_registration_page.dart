import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PetGender { male, female }

enum PetActivityLevel { low, medium, high }

class PetRegistrationPage extends StatefulWidget {
  const PetRegistrationPage({super.key});

  @override
  State<PetRegistrationPage> createState() => _PetRegistrationPageState();
}

class _PetRegistrationPageState extends State<PetRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _travelCheckControllers = List.generate(
    3,
    (_) => TextEditingController(),
  );

  PetGender _gender = PetGender.male;
  PetActivityLevel _activityLevel = PetActivityLevel.medium;
  bool _isNeutered = false;
  bool _isDangerousBreed = false;
  bool _isOffLeash = false;
  bool _indoorAllowed = true;
  bool _parkingAvailable = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    for (final controller in _travelCheckControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? get _weightKg => double.tryParse(_weightController.text.trim());

  String get _size {
    final weight = _weightKg;
    if (weight == null) {
      return '-';
    }
    if (weight < 10) {
      return 'Small';
    }
    if (weight < 25) {
      return 'Medium';
    }
    return 'Large';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final travelNotes = _travelCheckControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'age': int.parse(_ageController.text.trim()),
      'gender': _gender.name,
      'isNeutered': _isNeutered,
      'breed': _breedController.text.trim(),
      'isDangerousBreed': _isDangerousBreed,
      'weightKg': _weightKg,
      'size': _size,
      'activityLevel': _activityLevel.name,
      'travelChecklist': travelNotes,
      'isOffLeash': _isOffLeash,
      'indoorAllowed': _indoorAllowed,
      'parkingAvailable': _parkingAvailable,
    };

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    const background = Colors.white;
    const accent = Color(0xFFFFD54A);
    const borderColor = Color(0xFFD9D9D9);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text('반려동물 등록'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _buildSectionTitle('이름'),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _nameController,
                hintText: '입력하세요',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '이름을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              _buildSectionTitle('나이'),
              const SizedBox(height: 8),
              const Text(
                '정확한 나이가 기억나지 않는 경우 대략 나이를 입력해 주세요.',
                style: TextStyle(color: Color(0xFF7F7F7F), fontSize: 13),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _ageController,
                hintText: '정수로 입력하세요',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final age = int.tryParse((value ?? '').trim());
                  if (age == null) {
                    return '나이를 숫자로 입력해 주세요.';
                  }
                  if (age < 0 || age > 40) {
                    return '나이는 0~40 사이로 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),
              _buildSectionTitle('성별'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'Male',
                      selected: _gender == PetGender.male,
                      onTap: () => setState(() => _gender = PetGender.male),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'Female',
                      selected: _gender == PetGender.female,
                      onTap: () => setState(() => _gender = PetGender.female),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildBooleanTile(
                title: '중성화 여부',
                value: _isNeutered,
                onChanged: (value) => setState(() => _isNeutered = value),
              ),
              const SizedBox(height: 18),
              _buildSectionTitle('품종'),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _breedController,
                hintText: '입력하세요',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '품종을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              _buildBooleanTile(
                title: '법적 맹견 품종 여부',
                value: _isDangerousBreed,
                onChanged: (value) => setState(() => _isDangerousBreed = value),
              ),
              const SizedBox(height: 22),
              _buildSectionTitle('무게 (kg)'),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _weightController,
                hintText: '예: 4.5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final weight = double.tryParse((value ?? '').trim());
                  if (weight == null) {
                    return '무게를 숫자로 입력해 주세요.';
                  }
                  if (weight <= 0 || weight > 120) {
                    return '무게는 0보다 크고 120 이하로 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Text(
                      '사이즈',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _size,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A5A5A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildSectionTitle('활동량'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'Low',
                      selected: _activityLevel == PetActivityLevel.low,
                      onTap: () =>
                          setState(() => _activityLevel = PetActivityLevel.low),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'Med',
                      selected: _activityLevel == PetActivityLevel.medium,
                      onTap: () => setState(
                        () => _activityLevel = PetActivityLevel.medium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildChoiceButton(
                      label: 'High',
                      selected: _activityLevel == PetActivityLevel.high,
                      onTap: () => setState(
                        () => _activityLevel = PetActivityLevel.high,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildSectionTitle('여행할 때 꼭 확인할 것'),
              const SizedBox(height: 8),
              const Text(
                '최대 3개까지 입력해 주세요.',
                style: TextStyle(color: Color(0xFF7F7F7F), fontSize: 13),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _travelCheckControllers.length; i++) ...[
                _buildTextField(
                  controller: _travelCheckControllers[i],
                  hintText: '예: 물 자주 마시기',
                ),
                if (i != _travelCheckControllers.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 18),
              _buildBooleanTile(
                title: '목줄 자유 여부',
                value: _isOffLeash,
                onChanged: (value) => setState(() => _isOffLeash = value),
              ),
              const SizedBox(height: 10),
              _buildBooleanTile(
                title: '실내 이용 여부',
                value: _indoorAllowed,
                onChanged: (value) => setState(() => _indoorAllowed = value),
              ),
              const SizedBox(height: 10),
              _buildBooleanTile(
                title: '주차장 이용 가능 여부',
                value: _parkingAvailable,
                onChanged: (value) => setState(() => _parkingAvailable = value),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFE0B93C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '등록하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        errorStyle: const TextStyle(color: Color(0xFFD04B4B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE082) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFE0B93C) : const Color(0xFFD9D9D9),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBooleanTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFFD54A),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE4E4E4),
            trackOutlineColor: const WidgetStatePropertyAll(Color(0xFFD4D4D4)),
          ),
        ],
      ),
    );
  }
}
