import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MapService {
  static String clientKey = 'y69xv97lky';
  static String secretKey = '26ws0oYwhh3R7XjEYiY4QsT74HAsWwhG25KBkypy';

  static Future<Map<String, dynamic>?> getLatLngFromAddress(String address) async {
    // Geocoding API 요청 URL
    final url = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=$address');

    // 네이버 클라우드 플랫폼에서 발급받은 Client ID와 Secret Key
    final headers = {
      'X-NCP-APIGW-API-KEY-ID': clientKey, // 발급받은 Client ID
      'X-NCP-APIGW-API-KEY': secretKey, // 발급받은 Client Secret Key
    };

    // GET 요청 보내기
    final response = await http.get(url, headers: headers);

    // 요청이 성공적이면 응답 데이터 처리
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // 주소 정보가 존재하면 위도와 경도를 반환
      if (data['addresses'] != null && data['addresses'].isNotEmpty) {
        final lat = data['addresses'][0]['y']; // 위도
        final lng = data['addresses'][0]['x']; // 경도
        return {'lat': lat, 'lng': lng};
      } else {
        print('주소를 찾을 수 없습니다.');
      }
    } else {
      print('Geocoding API 요청 실패: ${response.statusCode}');
    }
    return null;
  }
}
