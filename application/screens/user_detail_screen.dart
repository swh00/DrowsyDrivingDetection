import 'package:flutter/material.dart';
import 'package:dku_capstone/model/driver_model.dart';

class DriverDetailScreen extends StatelessWidget {
  final DriverItem driver;

  DriverDetailScreen({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(driver.drivername),
        centerTitle: true,
        elevation: 4.0, // 앱바의 그림자 효과
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 둥근 사진
              Container(
                width: 250, // 원하는 너비
                height: 350, // 원하는 높이
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0), // 모서리 둥글게
                  image: DecorationImage(
                    image: MemoryImage(driver.profileImage), // Uint8List를 사용
                    fit: BoxFit.cover, // 비율에 맞게 자르기
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 사용자 이름
              Text(
                driver.drivername,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              // 등록 날짜
              Text(
                'RegistDate: ${driver.registrationDate}',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
