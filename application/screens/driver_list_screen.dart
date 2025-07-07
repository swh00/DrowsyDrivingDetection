import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dku_capstone/utils/ssl_ioclient.dart';
import 'package:dku_capstone/model/driver_model.dart';
import 'package:dku_capstone/screens/user_detail_screen.dart';
import 'package:dku_capstone/utils/jwt_token.dart';
import 'package:image_picker/image_picker.dart';

class DriverListScreen extends StatefulWidget {
  final String camera_serial;
  DriverListScreen({super.key, required this.camera_serial});

  @override
  _DriverListScreen createState() => _DriverListScreen();
}

class _DriverListScreen extends State<DriverListScreen> {
  List<DriverItem> drivers = []; // 서버에서 받아온 사용자 목록
  final JwtTokenManager _jwtTokenManager = JwtTokenManager();
  late String baseUrl;

  @override
  void initState() {
    super.initState();
    _loadDrivers(); // 사용자 목록 불러오기
    baseUrl = 'https://34.64.207.115/accounts/api/${widget.camera_serial}/';
  }

  // 사용자 목록을 불러오고 화면에 반영
  Future<void> _loadDrivers() async {
    final token = await _jwtTokenManager.getAccessToken(); // 액세스 토큰 가져오기
    final ioClient = await createSecureIOClient();

    final response = await ioClient.get(
      Uri.parse('${baseUrl}loaddrivers/'), // 사용자 목록 불러오기
      headers: {
        'Authorization': 'Bearer $token', // JWT 토큰 추가
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> driverJson = json.decode(response.body);

      drivers = driverJson.map((json) {
        // drivername을 UTF-8로 디코딩
        final decodedDrivername =
            utf8.decode(json['drivername'].runes.toList());
        return DriverItem.fromJson({
          ...json,
          'drivername': decodedDrivername, // 디코딩된 drivername으로 수정
        });
      }).toList();

      setState(() {}); // 데이터 로드 후 화면 업데이트
    } else {
      // 오류 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('운전자 목록을 불러올 수 없습니다.')),
      );
    }
  }

  // 사용자 추가 시 화면 업데이트
  Future<void> _handleAddDriver() async {
    final Map<String, dynamic>? result = await _addDriverFromDialog(context);
    if (result != null) {
      final DriverItem newDriver = result['driverItem'];
      final String imagePath = result['imagePath'];
      final token = await _jwtTokenManager.getAccessToken(); // 액세스 토큰 가져오기
      final ioClient = await createSecureIOClient();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${baseUrl}adddriver/'),
      );

      request.headers['Authorization'] = 'Bearer $token'; // JWT 토큰 추가
      request.fields['drivername'] = newDriver.drivername;
      request.fields['registration_date'] = newDriver.registrationDate;
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_image',
          imagePath, // selectedImage의 경로 사용
        ),
      );
      // 요청 전송
      final response = await ioClient.send(request);

      if (response.statusCode == 201) {
        // 사용자 추가 성공
        setState(() {
          drivers.add(newDriver);
        });
      } else {
        // 오류 처리
        final responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 추가 실패: $responseBody')),
        );
      }

      // IOClient 닫기
      ioClient.close();
    }
  }

  // 사용자 삭제 시 화면 업데이트
  Future<void> _handleDeleteUser(int index) async {
    final drivername = drivers[index].drivername; // 사용자 이름 가져오기

    // 삭제 확인 대화상자 표시
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('삭제 확인'),
          content: Text('$drivername 드라이버를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 취소
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // 확인
              child: Text('삭제'),
            ),
          ],
        );
      },
    );

    // 삭제를 확인한 경우에만 요청을 보냄
    if (shouldDelete == true) {
      final token = await _jwtTokenManager.getAccessToken(); // 액세스 토큰 가져오기
      final ioClient = await createSecureIOClient();

      final response = await ioClient.delete(
        Uri.parse('${baseUrl}deletedriver/$drivername/'),
        headers: {
          'Authorization': 'Bearer $token', // JWT 토큰 추가
        },
      );

      if (response.statusCode == 204) {
        setState(() {
          drivers.removeAt(index); // 사용자 삭제 후 화면 업데이트
        });
      } else {
        // 오류 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 삭제 실패: ${response.body}')),
        );
      }
    }
  }

  void _showUserDetail(DriverItem driver) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverDetailScreen(driver: driver),
      ),
    );
  }

  Future<Map<String, dynamic>?> _addDriverFromDialog(
      BuildContext context) async {
    String username = '';
    File? selectedImage;

    // 이미지 선택 함수
    Future<void> _pickImage() async {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        selectedImage = File(image.path);
      }
    }

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Driver'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Drive Name'),
                  onChanged: (value) {
                    username = value;
                  },
                ),
                SizedBox(height: 10),
                selectedImage == null
                    ? const Text('There is no Selected image.')
                    : Image.file(selectedImage!, width: 100, height: 100),
                TextButton(
                  onPressed: () async {
                    await _pickImage();
                    setState(() {}); // 상태 업데이트
                  },
                  child: Text('Select Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null); // 다이얼로그 닫기
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (username.isNotEmpty && selectedImage != null) {
                  final bytes = await selectedImage!.readAsBytes();

                  // 사용자 정보를 모두 입력했을 경우
                  Navigator.of(context).pop({
                    'driverItem': DriverItem(
                      drivername: username,
                      registrationDate: DateTime.now().toLocal().toString(),
                      profileImage: bytes, // Uint8List로 저장
                    ),
                    'imagePath': selectedImage!.path, // 이미지 경로 추가
                  });
                } else {
                  // 오류 메시지 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill out all fields.')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: drivers.length,
        itemBuilder: (context, index) {
          final driver = drivers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: driver.profileImage.isNotEmpty
                  ? MemoryImage(driver.profileImage) // Base64로 디코딩한 이미지 사용
                  : null, // 이미지가 없으면 기본값
            ),
            title: Text(driver.drivername),
            subtitle: Text(driver.registrationDate),
            onTap: () => _showUserDetail(driver),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _handleDeleteUser(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAddDriver,
        tooltip: 'Add User',
        child: Icon(Icons.add),
      ),
    );
  }
}
