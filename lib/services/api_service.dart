import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Your real live Heroku backend
  static const String baseUrl = 
      'https://medical-app-api-32d01213819a.herokuapp.com';

  static Future<List<dynamic>> getPatients() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/patients'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error: $e');
    }
    return []; // fallback empty list
  }
}