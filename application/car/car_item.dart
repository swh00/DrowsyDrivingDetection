/*
  서버로 부터 받아온 차량 정보를 리스트에 표시하는 클래스입니다.
  리스트를 터치하면 해당 차량의 카메라 IP가 담긴 MainScreen으로 이동합니다.
  차량을 삭제하려면 삭제 버튼을 누르면 됩니다.

  import 'package:dku_capstone/car/car_item.dart';
*/

import 'package:flutter/material.dart';
import 'package:dku_capstone/car/car.dart';
import 'package:dku_capstone/screens/main_screen.dart';

class CarItem extends StatelessWidget {
  final Car car;
  final VoidCallback onDelete;

  const CarItem({super.key, required this.car, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // 차량의 활성화 상태에 따라 색상 및 스타일 설정
    final isActive = car.isActive;
    final cardColor =
        isActive ? Colors.white : Colors.grey[300]; // 비활성화 시 회색으로 설정
    final textColor = isActive ? Colors.black : Colors.grey; // 비활성화 시 회색으로 설정

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      color: cardColor, // 카드 색상 설정
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(
          car.carNumber,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor, // 텍스트 색상 설정
            decoration:
                isActive ? null : TextDecoration.lineThrough, // 비활성화 시 빗금
          ),
        ),
        subtitle: Text(
          'Camera Serial: ${car.cameraSerial}',
          style: TextStyle(
            color: textColor, // 텍스트 색상 설정
            decoration:
                isActive ? null : TextDecoration.lineThrough, // 비활성화 시 빗금
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: () {
          // 카메라 활성화 여부 체크
          if (!car.isActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please turn on the camera first.')),
            );
          } else {
            // MainScreen으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainScreen(
                  baseUrl: car.cameraIp,
                  carNumber: car.carNumber,
                  camera_serial: car.cameraSerial,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
