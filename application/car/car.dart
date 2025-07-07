/*
  카 클래스 입니다.

  import 'package:dku_capstone/car/car.dart';
*/

class Car {
  final String carNumber;
  final String cameraIp;
  final String cameraSerial;
  final bool isActive;

  Car(
      {required this.carNumber,
      required this.cameraIp,
      required this.cameraSerial,
      required this.isActive});

  Car copyWith({
    String? carNumber,
    String? cameraIp,
    String? cameraSerial,
    bool? isActive,
  }) {
    return Car(
      carNumber: carNumber ?? this.carNumber,
      cameraIp: cameraIp ?? this.cameraIp,
      cameraSerial: cameraSerial ?? this.cameraSerial,
      isActive: isActive ?? this.isActive,
    );
  }
}
