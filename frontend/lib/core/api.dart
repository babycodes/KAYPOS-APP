// KAYPOS — API Client (matches Svelte api.ts exactly)
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Api {
  static String _authToken = '';
  
  static String getApiBase() {
    // For Flutter web, use the same host as the page
    if (kIsWeb) {
      // In web, we always call localhost:3000 for dev
      return 'http://localhost:3000/api';
    }
    // For mobile/desktop, point to local backend
    return 'http://localhost:3000/api';
  }

  static void setToken(String token) { _authToken = token; }
  static String getToken() => _authToken;

  static Future<dynamic> _request(String method, String path, {dynamic body}) async {
    final url = Uri.parse('${getApiBase()}$path');
    final headers = <String, String>{
      'Authorization': 'Bearer $_authToken',
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        response = await http.put(url, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Unknown method: $method');
    }

    if (response.statusCode == 401 && !path.contains('/auth/login') && !path.contains('/auth/verify-pin')) {
      throw Exception('Sesi habis, silakan login kembali');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  static Future<dynamic> get(String path) => _request('GET', path);
  static Future<dynamic> post(String path, {dynamic body}) => _request('POST', path, body: body);
  static Future<dynamic> put(String path, {dynamic body}) => _request('PUT', path, body: body);
  static Future<dynamic> delete(String path) => _request('DELETE', path);
}
