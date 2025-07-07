/*
  로그인 서비스를 위한 파일입니다.
  서버의 API를 호출하여 로그인을 시도합니다.
  로그인 성공 시, 사용자 정보를 반환합니다.
    - login(email, password, token, ip)
      - email: 사용자 이메일
      - password: 사용자 비밀번호
      - token: 사용자의 FCM 토큰
      - ip: 사용자의 IP 주소
  FCM 토큰은 사용자의 디바이스를 식별하기 위한 토큰입니다.
  -> 추후 FCM 토큰을 이용하여 푸시 알림을 보낼 수 있습니다.
  ioClient를 이용하여 안전한 통신을 위해 SSL 인증서를 사용합니다.

  import 'package:dku_capstone/login/auth_service.dart';
*/

import 'dart:convert';
import 'package:dku_capstone/utils/ssl_ioclient.dart';

class AuthService {
  final String serverUrl = 'https://34.64.207.115/accounts/api/login/';

  Future<Map<String, dynamic>> login(
      String email, String password, String token) async {
    final ioClient = await createSecureIOClient();

    final response = await ioClient.post(
      Uri.parse(serverUrl),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'email': email,
        'password': password,
        'fcm_token': token,
      }),
    );
    print('response');
    print(response.body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Please check your email and password.';
    }
  }
}
