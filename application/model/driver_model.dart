/*
  운전자 정보를 담든 모델 클래스 입니다.
  -DriverItem
    -drivername: 운전자 이름
    -registrationDate: 등록 날짜
    -profileImage: 프로필 이미지
  서버로 이미지를 보낼 때 Uint8List로 변환하여 보내야 합니다.
  서버에서 이미지를 받을 때 Uint8List를 Base64로 인코딩하여 받아야 합니다.
  이미지 부분에 대한 개선이 필요할 수 도 있습니다.
  
  import 'package:dku_capstone/model/driver_model.dart';
*/

import 'dart:convert';
import 'dart:typed_data';

class DriverItem {
  final String drivername;
  final String registrationDate;
  final Uint8List profileImage;

  DriverItem({
    required this.drivername,
    required this.registrationDate,
    required this.profileImage,
  });

  // JSON에서 DriverItem 생성
  factory DriverItem.fromJson(Map<String, dynamic> json) {
    // Base64 이미지를 Uint8List로 디코딩
    String base64Image = json['profile_image'];

    if (base64Image.startsWith('data:image/jpeg;base64,')) {
      base64Image = base64Image.replaceFirst('data:image/jpeg;base64,', '');
    }

    Uint8List imageBytes = base64Decode(base64Image);

    return DriverItem(
      drivername: json['drivername'],
      registrationDate: json['registration_date'],
      profileImage: imageBytes,
    );
  }
}
