import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PatientService {
  static const String baseUrl = 'https://medical-app-api-32d01213819a.herokuapp.com';

  static Future<List<dynamic>> getPatients() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/patients'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }
}