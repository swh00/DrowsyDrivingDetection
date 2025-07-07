/*
  로그인 성공 후 해당 계정 정보로 등록된 차량 목록을 보여주는 화면입니다.
  차량 및 카메라 IP를 등록하고 삭제할 수 있습니다.
  카메라 하나에 한대의 차량만 등록 가능합니다.
*/

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dku_capstone/car/car.dart';
import 'package:dku_capstone/utils/jwt_token.dart';
import 'package:dku_capstone/utils/ssl_ioclient.dart';
import 'package:dku_capstone/car/add_car_dialog.dart';
import 'package:dku_capstone/car/car_item.dart';
import 'package:dku_capstone/utils/goose_util.dart';

class CarListScreen extends StatefulWidget {
  final List<Car> cars;

  const CarListScreen({
    super.key,
    required this.cars,
  });

  @override
  _CarListScreen createState() => _CarListScreen();
}

class _CarListScreen extends State<CarListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null, // title을 null로 설정합니다.
        centerTitle: true,
        flexibleSpace: Center(
          child: const Text(
            'Car List',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
      body: widget.cars.isEmpty
          ? const Center(
              child: Text(
              'No cars have been registered yet.',
              style: TextStyle(fontSize: 20),
            ))
          : ListView.builder(
              itemCount: widget.cars.length,
              itemBuilder: (context, index) {
                return CarItem(
                  car: widget.cars[index],
                  onDelete: () => _showDeleteConfirmationDialog(context, index),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddCarDialog(context);
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _updateCarStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent, // 버튼 색상
            padding: const EdgeInsets.symmetric(vertical: 16.0),
          ),
          child: const Text(
            'Update Car Status',
            style: TextStyle(
              color: Color.fromARGB(255, 226, 218, 77), // 원하는 색상으로 변경
              fontSize: 16, // 글자 크기 조정 가능
              fontWeight: FontWeight.bold, // 글자 두께 조정 가능
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AddCarDialog(
          onAdd: (carNumber, cameraSerial, cameraPw) {
            _addCar(carNumber, cameraSerial, cameraPw);
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this car?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteCar(index);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addCar(
      String carNumber, String cameraSerial, String cameraPw) async {
    final jwtManager = JwtTokenManager();
    final token = await jwtManager.getAccessToken();
    final ioClient = await createSecureIOClient();

    final response = await ioClient.post(
      Uri.parse('https://34.64.207.115/accounts/api/add_car/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'car_number': carNumber,
        'camera_serial': cameraSerial,
        'password': cameraPw
      }),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData =
          jsonDecode(utf8.decode(response.bodyBytes));

      // cameraIp 값을 추출하여 사용
      String cameraIp =
          responseData['camera_ip'] ?? ''; // 'cameraIp' 필드가 없으면 빈 문자열 사용
      bool isActive = responseData['is_active'] ?? false;

      setState(() {
        widget.cars.add(Car(
            carNumber: carNumber,
            cameraSerial: cameraSerial,
            cameraIp: cameraIp,
            isActive: isActive));
      });
    } else {
      final Map<String, dynamic> errorResponse =
          jsonDecode(utf8.decode(response.bodyBytes));

      showErrorMessage(context, errorResponse);
    }
  }

  Future<void> _deleteCar(int index) async {
    final jwtManager = JwtTokenManager();
    final token = await jwtManager.getAccessToken();
    final ioClient = await createSecureIOClient();

    final response = await ioClient.delete(
      Uri.parse(
          'https://34.64.207.115/accounts/api/delete_car/${widget.cars[index].cameraSerial}/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 204) {
      setState(() {
        widget.cars.removeAt(index);
      });
    } else {
      final Map<String, dynamic> errorResponse =
          jsonDecode(utf8.decode(response.bodyBytes));

      showErrorMessage(context, errorResponse);
    }
  }

  Future<void> _updateCarStatus() async {
    final jwtManager = JwtTokenManager();
    final token = await jwtManager.getAccessToken();
    final ioClient = await createSecureIOClient();

    const String url = 'https://34.64.207.115/accounts/api/update_cars/';

    try {
      final response = await ioClient.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> carsData =
            jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          for (var carData in carsData) {
            final car = widget.cars.firstWhere(
              (c) =>
                  c.carNumber == carData['car_number'], // key를 car_number로 수정
              orElse: () => Car(
                  carNumber: '',
                  cameraIp: '',
                  cameraSerial: '',
                  isActive: false),
            );
            if (car.carNumber.isNotEmpty) {
              int index = widget.cars.indexOf(car);
              // copyWith를 사용하여 isActive 업데이트
              widget.cars[index] = car.copyWith(isActive: carData['is_active']);
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Car status has been updated.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to update the status. \nPlease turn on the camera.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'An error occurred while sending the request to the server: $e')),
      );
    }
  }
}
