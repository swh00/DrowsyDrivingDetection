/*
  회원 가입 화면입니다.
  이메일, 비밀번호, 비밀번호 확인을 입력받아 회원가입을 진행합니다.  
  서버 쪽 API를 호출하여 회원가입을 진행합니다.
  
  import 'package:dku_capstone/screens/signup_screen.dart';
*/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dku_capstone/utils/ssl_ioclient.dart';
import 'package:dku_capstone/utils/goose_util.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController1 = TextEditingController();
  final TextEditingController _passwordController2 = TextEditingController();

  Future<void> _register() async {
    const String url = 'https://34.64.207.115/accounts/api/signup/';
    final Map<String, String> headers = {"Content-Type": "application/json"};

    final Map<String, String> body = {
      'email': _emailController.text,
      'password1': _passwordController1.text,
      'password2': _passwordController2.text,
    };

    try {
      final ioClient = await createSecureIOClient();
      final response = await ioClient.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        showSnackBar(context,
            'Sign up successfully!\nPlease Check your email for verification.');
        Navigator.pop(context);
      } else {
        final errorResponse = jsonDecode(response.body);
        showErrorMessage(context, errorResponse);
      }
    } catch (e) {
      showSnackBar(context, 'Unable to connect to the server. Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            buildTextField(_emailController, 'Email'),
            buildTextField(_passwordController1, 'Password', obscureText: true),
            buildTextField(_passwordController2, 'Confirm password',
                obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
