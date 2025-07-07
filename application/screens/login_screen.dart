/*
  로그인 화면입니다.
  이메일과 비밀번호를 입력받아 로그인을 시도합니다.
  로그인 성공 시, 서버를 거쳐 차량의 카메라로 fcm 토큰과 ip 주소를 전달합니다.
  이를 기반으로 로그인한 앱에서만 푸시 알림 및 로그, 카메라를 볼 수 있습니다.

  import 'package:dku_capstone/screens/login_screen.dart';
*/

import 'package:flutter/material.dart';
import 'package:dku_capstone/screens/car_list_screen.dart';
import 'package:dku_capstone/screens/signup_screen.dart';
import 'package:dku_capstone/login/auth_service.dart';
import 'package:dku_capstone/utils/jwt_token.dart';
import 'package:dku_capstone/utils/goose_util.dart';
import 'package:dku_capstone/login/login_form.dart';
import 'package:dku_capstone/car/car.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  final String? token;
  const LoginScreen({super.key, required this.token});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final JwtTokenManager _jwtManager = JwtTokenManager();
  final AuthService _authService = AuthService();
  bool _isAutoSaveEmail = false;

  //하드코딩된 비밀번호를 입력... 추후 삭제!!!!!!!!!!!!!!!!!!!
  @override
  void initState() {
    super.initState();
    _loadPreferences(); // 자동 이메일 입력 기능
  }

  // SharedPreferences를 사용하여 저장된 이메일을 불러오는 함수
  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');
    bool? autoSave = prefs.getBool('autoSaveEmail');

    if (savedEmail != null && autoSave == true) {
      _emailController.text = savedEmail;
      setState(() {
        _isAutoSaveEmail = true;
      });
    }
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (_isAutoSaveEmail) {
      await prefs.setString('email', _emailController.text); // 이메일 저장
    } else {
      await prefs.remove('email'); // 이메일 삭제
    }
    await prefs.setBool('autoSaveEmail', _isAutoSaveEmail); // 자동 입력 여부 저장
  }

  void _navigateToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        elevation: 0.0,
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              const Text(
                'GOOSE',
                style: TextStyle(
                  fontSize: 80, // 크기를 크게 설정
                  fontWeight: FontWeight.bold, // 굵은 볼드체
                  color: Color.fromARGB(255, 130, 127, 127), // 회색 텍스트
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isAutoSaveEmail,
                          onChanged: (bool? value) {
                            setState(() {
                              _isAutoSaveEmail = value ?? false;
                            });
                          },
                        ),
                        const Text('Auto-fill Email'),
                      ],
                    ),
                    const SizedBox(height: 0), // 이메일 입력란과 간격 조정
                    LoginForm(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      onLogin: _handleLogin,
                      onNavigateToSignUp: _navigateToSignUp,
                    ),
                    const SizedBox(height: 70), // 하단 여백 추가
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse('https://34.64.207.115/');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                      child: const Text(
                        'Check Product Details',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Contacting Goose: goose@goose.com',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5), // 여백 추가
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Goose ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey, // 굵고 회색
                            ),
                          ),
                          TextSpan(
                            text:
                                'Copyright © Goose Corp. All Rights Reserved.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey, // 나머지는 회색
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    final emailInput = _emailController.text;
    final passwordInput = _passwordController.text;

    try {
      final responseData = await _authService.login(
        emailInput,
        passwordInput,
        widget.token!,
      );

      await _jwtManager.saveAccessToken(responseData['access']);
      await _jwtManager.saveRefreshToken(responseData['refresh']);
      await _savePreferences();

      List<String> carNumbers = List<String>.from(
          responseData['car_numbers']?.map((e) => e ?? '') ?? []);
      List<String> cameraIps = List<String>.from(
          responseData['camera_ips']?.map((e) => e ?? '') ?? []);
      List<String> cameraSerials = List<String>.from(
          responseData['camera_serials']?.map((e) => e ?? '') ?? []);
      List<bool> isActives = List<bool>.from(
          responseData['is_actives']?.map((e) => e ?? false) ?? []);

      List<Car> cars = [];
      for (int i = 0; i < carNumbers.length; i++) {
        cars.add(Car(
            carNumber: carNumbers[i],
            cameraIp: i < cameraIps.length ? cameraIps[i] : '', // IndexError 방지
            cameraSerial: i < cameraSerials.length ? cameraSerials[i] : '',
            isActive: i < isActives.length ? isActives[i] : false));
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CarListScreen(
            cars: cars,
          ),
        ),
      );
    } catch (e) {
      showSnackBar(context, '$e');
    }
  }
}
