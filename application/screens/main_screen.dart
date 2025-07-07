/* 
  실제 앱에서 운전자 로그, 실시간 영상, 운전자 목록 표시 화면들을 제어하는 클래스입니다.
  각 화면은 BottomNavigationBar를 통해 전환할 수 있습니다.
  각 화면은 다음과 같습니다.
    - LogListScreen: 운전자 로그를 표시하는 화면
    - StreamingVideoScreen: 실시간 영상을 표시하는 화면
    - DriverListScreen: 운전자 목록을 표시하는 화면

  import 'package:dku_capstone/screens/main_screen.dart';
*/

import 'package:dku_capstone/screens/driver_list_screen.dart';
import 'package:dku_capstone/screens/log_list_screen.dart';
import 'package:dku_capstone/screens/streaming_video_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  final String baseUrl;
  final String carNumber;
  final String camera_serial;
  const MainScreen(
      {super.key,
      this.baseUrl = '220.149.235.111',
      required this.carNumber,
      required this.camera_serial});

  @override
  _MainScreen createState() => _MainScreen();
}

class _MainScreen extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final baseHttpUrl = 'http://${widget.baseUrl}:9999/';

    _screens = [
      LogListScreen(logUrl: '${baseHttpUrl}log2'),
      StreamingVideoScreen(videoUrl: baseHttpUrl),
      DriverListScreen(camera_serial: widget.camera_serial),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 3,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "${widget.carNumber}",
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.jumpToPage(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Log List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_collection),
            label: 'Video',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Driver List',
          ),
        ],
      ),
    );
  }
}
