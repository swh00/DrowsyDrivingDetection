/*
  goose server에서 배포한 인증서를 사용하기 위한 함수입니다.
  이처럼 통신할 시, https로 통신하게 됩니다.

  import 'package:dku_capstone/utils/ssl_ioclient.dart';
*/

//dku_capstone/utils/ssl_ioclient.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/io_client.dart';

Future<IOClient> createSecureIOClient() async {
  final ByteData data = await rootBundle.load('assets/auths/goose_cert.pem');
  final List<int> bytes = data.buffer.asUint8List();

  SecurityContext sContext = SecurityContext.defaultContext;
  sContext.setTrustedCertificatesBytes(bytes);

  HttpClient httpClient = HttpClient(context: sContext);
  return IOClient(httpClient);
}
