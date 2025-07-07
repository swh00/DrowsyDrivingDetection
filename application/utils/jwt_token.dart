/*
  서버와의 안전한 통신을 위한 JWT 토큰을 관리하는 클래스 입니다.
  토큰들을 관리하는 기능들을 제공합니다.

  다만, 오랫동안 앱을 사용하지 않았을 때 토큰이 만료되어
  다시 로그인해야하는 경우가 발생할 수 있습니다.

  import 'package:dku_capstone/utils/jwt_token.dart';
*/
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dku_capstone/utils/ssl_ioclient.dart';

class JwtTokenManager {
  static const String _accessTokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<void> saveAccessToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<void> saveRefreshToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(_refreshTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> deleteTokens() async {
    final prefs = await _getPrefs();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null) {
      // 리프레시 토큰이 없을 때의 처리
      return null;
    }

    final ioClient = await createSecureIOClient();

    try {
      final response = await ioClient.post(
        Uri.parse('https://34.64.207.115:8000/api/token/refresh/'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8'
        },
        body: jsonEncode(<String, dynamic>{'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String newAccessToken = responseData['access'];
        await saveAccessToken(newAccessToken);
        return newAccessToken;
      } else {
        // HTTP 오류 처리
        print('Error refreshing token: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Network error: $e');
      return null;
    }
  }
}
