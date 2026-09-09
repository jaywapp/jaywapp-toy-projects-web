import 'package:http/http.dart' as http;

class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;

  GoogleHttpClient(this._headers);

  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
