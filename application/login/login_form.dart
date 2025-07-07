/* 
  로그인 포맷을 정의하는 파일입니다.
  특별한 것은 없습니다.

  import 'package:dku_capstone/login/login_form.dart';
*/
import 'package:flutter/material.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final VoidCallback onNavigateToSignUp;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onNavigateToSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        children: [
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              minimumSize: const Size(100, 50),
            ),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 35.0,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onNavigateToSignUp,
            child: const Text(
              'Sign up?',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
