/* 
  카메라에서 운전자 로그를 볼 수 있는 화면입니다.
  버튼을 클릭 시 로그를 최신 순으로 표시합니다.
  Reload 버튼을 클릭 시 로그를 다시 불러올 수 있습니다.

  import :'package:dku_capstone/screens/log_list_screen.dart';
*/
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogListScreen extends StatefulWidget {
  final String logUrl;

  const LogListScreen({super.key, required this.logUrl});

  @override
  _LogListScreen createState() => _LogListScreen();
}

class _LogListScreen extends State<LogListScreen>
    with AutomaticKeepAliveClientMixin {
  late WebViewController _webViewController;
  bool _showWebView = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..loadRequest(Uri.parse(widget.logUrl))
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  void _downloadHtml() async {
    String? htmlContent = await _webViewController.runJavaScriptReturningResult(
        "document.documentElement.outerHTML") as String?;

    if (htmlContent != null) {
      htmlContent =
          htmlContent.replaceAll(r'\u003C', '<').replaceAll(r'\"', '"');

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/log.html';
      final file = File(path);

      await file.writeAsString(htmlContent);
    }
  }

  void _onShowWebViewPressed() {
    setState(() {
      _showWebView = true;
    });
  }

  void _onReloadPressed() {
    _webViewController.loadRequest(Uri.parse(widget.logUrl));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Center(
        child: _showWebView
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _onReloadPressed,
                        child: const Text('Reload Log List'),
                      ),
                      const SizedBox(width: 10), // 버튼 사이 간격
                      ElevatedButton(
                        onPressed: _downloadHtml,
                        child: const Text('Download Log'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: WebViewWidget(controller: _webViewController),
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: _onShowWebViewPressed,
                child: const Text('Show Log List'),
              ),
      ),
    );
  }
}
