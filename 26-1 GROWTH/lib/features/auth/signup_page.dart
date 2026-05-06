import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../common/api/firebase_auth_service.dart';
import '../../common/api/firestore_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = FirebaseAuthService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage("이메일과 비밀번호를 입력해 주세요.");
      return;
    }
    if (password != confirm) {
      _showMessage("비밀번호가 일치하지 않아요.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.signUp(email: email, password: password);
      final user = _authService.currentUser;
      if (user != null) {
        await _firestoreService.ensureUserNickname(uid: user.uid);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_friendlyAuthMessage(e));
    } catch (_) {
      _showMessage("회원가입 중 오류가 발생했어요.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "이메일 형식이 올바르지 않아요.";
      case "weak-password":
        return "비밀번호가 너무 약해요. 6자 이상 입력해 주세요.";
      case "email-already-in-use":
        return "이미 가입된 이메일이에요.";
      case "network-request-failed":
        return "네트워크 상태를 확인해 주세요.";
      default:
        return "회원가입에 실패했어요. (${e.code})";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "이메일"),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "비밀번호"),
              ),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "비밀번호 확인"),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 24),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: Text(_isLoading ? "처리 중..." : "회원가입"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
