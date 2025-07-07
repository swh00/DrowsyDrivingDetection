/* 
  차량의 카메라 영상을 스트리밍하는 화면입니다.
  실시간으로 차량 내부의 상태를 확인할 수 있습니다.

  import 'package:dku_capstone/screens/streaming_video_screen.dart';
*/

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StreamingVideoScreen extends StatefulWidget {
  final String videoUrl;

  const StreamingVideoScreen({super.key, required this.videoUrl});

  @override
  _StreamingVideoScreen createState() => _StreamingVideoScreen();
}

class _StreamingVideoScreen extends State<StreamingVideoScreen> {
  late WebViewController _webViewController;

  @override
  void initState() {
    _webViewController = WebViewController()
      ..loadRequest(Uri.parse(widget.videoUrl))
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WebViewWidget(controller: _webViewController),
    );
  }
}
