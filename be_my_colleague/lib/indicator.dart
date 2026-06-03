import 'package:flutter/material.dart';
import 'package:googleapis/container/v1.dart';

class Indicator {
  static Widget ShowIndicator(String message) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
          crossAxisAlignment: CrossAxisAlignment.center, // 가로 중앙 정렬
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16), // 인디케이터와 메시지 사이의 간격
            Text(message), // 로딩 중 메시지
      ],
    ));
  }
}
