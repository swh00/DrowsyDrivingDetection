/*
  새로운 차량 및 카메라ip의 정보를 입력 받는 다이얼로그입니다.

  import 'package:dku_capstone/car/add_car_dialog.dart';
*/

import 'package:flutter/material.dart';

class AddCarDialog extends StatelessWidget {
  final Function(String carNumber, String cameraIp, String password) onAdd;

  const AddCarDialog({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final TextEditingController carNumberController = TextEditingController();
    final TextEditingController cameraSerialController =
        TextEditingController();
    final TextEditingController passwordController =
        TextEditingController(); // 비밀번호 컨트롤러 추가
    return AlertDialog(
      title: const Text('Add Car'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: carNumberController,
            decoration: const InputDecoration(labelText: 'Car Number'),
          ),
          TextField(
            controller: cameraSerialController,
            decoration:
                const InputDecoration(labelText: 'Camera Serial Number'),
          ),
          TextField(
            controller: passwordController, // 비밀번호 입력 필드 추가
            decoration: const InputDecoration(labelText: 'Camera Password'),
            obscureText: true, // 비밀번호 숨기기
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onAdd(
              carNumberController.text,
              cameraSerialController.text,
              passwordController.text,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
