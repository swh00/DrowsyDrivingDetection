/*
  여러가지 유틸리티 함수들을 모아놓은 파일입니다.
  - showSnackBar: SnackBar를 띄워주는 함수
  - showErrorMessage: 에러 메시지를 SnackBar로 띄워주는 함수
  - fetchPublicIP: 공개 IP 주소를 가져오는 함수
  - buildTextField: TextField 위젯을 생성하는 함수

  import 'package:dku_capstone/utils/goose_util.dart';
*/

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void showSnackBar(BuildContext context, String message) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: const Color.fromARGB(255, 112, 48, 48),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

void showErrorMessage(
    BuildContext context, Map<String, dynamic>? errorResponse) {
  String errorMessage = 'Unknown error occurred.';
  print(errorResponse);

  if (errorResponse != null && errorResponse.isNotEmpty) {
    errorMessage = '';

    // error와 details를 분리해서 처리
    if (errorResponse.containsKey('error')) {
      errorMessage += 'Error: ${errorResponse['error']}';
    }

    if (errorResponse.containsKey('details')) {
      final details = errorResponse['details'];
      if (details is Map) {
        details.forEach((key, value) {
          if (value is List) {
            errorMessage += '\n$key: ${value.join(', ')}';
          } else {
            errorMessage += '\n$key: $value';
          }
        });
      }
    }

    // 불필요한 줄바꿈 제거
    errorMessage = errorMessage.replaceAll('\n\n', '\n');
  }

  // Snackbar를 통해 오류 메시지 표시
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        errorMessage.trim(),
        style: TextStyle(fontSize: 16),
      ),
      duration: Duration(seconds: 5),
      backgroundColor: const Color.fromARGB(255, 112, 48, 48),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Widget buildTextField(TextEditingController controller, String label,
    {bool obscureText = false}) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    obscureText: obscureText,
  );
}

Future<String> fetchPublicIP() async {
  final response = await http.get(Uri.parse('https://api.ipify.org'));

  if (response.statusCode == 200) {
    return response.body; // 공인 IP를 반환
  } else {
    throw Exception('Failed to load IP');
  }
}
