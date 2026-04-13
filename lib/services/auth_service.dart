import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: 'https://example.com',
  );

  // Set to false when real API is ready
  static const bool useDummyOtp = true;

  static final RegExp emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#\$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  static bool isValidEmail(String email) {
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> sendOtp({required String phone, required String loanId}) async {
    if (useDummyOtp) {
      // Dummy mode: simulate sending OTP
      await Future.delayed(const Duration(seconds: 1));
      print('Dummy OTP sent: 123456'); // For testing, print the OTP
      return;
    }

    final uri = Uri.parse('$baseUrl/api/auth/send-otp');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'loanId': loanId}),
      );

      if (response.statusCode != 200) {
        final message = _parseErrorMessage(response.body);
        throw Exception(
          message ??
              'Unable to send OTP. Please check your network and backend configuration.',
        );
      }
    } on SocketException {
      throw Exception('Unable to send OTP. No network connection.');
    } on FormatException {
      throw Exception('Unable to send OTP. Backend returned unexpected response.');
    }
  }

  Future<bool> verifyOtp({required String phone, required String otp}) async {
    if (useDummyOtp) {
      // Dummy mode: verify against hardcoded OTP
      await Future.delayed(const Duration(seconds: 1));
      return otp == '123456';
    }

    final uri = Uri.parse('$baseUrl/api/auth/verify-otp');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );

      if (response.statusCode != 200) {
        final message = _parseErrorMessage(response.body);
        throw Exception(message ?? 'OTP verification failed.');
      }

      final body = jsonDecode(response.body);
      return body['verified'] == true;
    } on SocketException {
      throw Exception('Unable to verify OTP. No network connection.');
    } on FormatException {
      throw Exception('Unable to verify OTP. Backend returned unexpected response.');
    }
  }

  String? _parseErrorMessage(String rawBody) {
    try {
      final body = jsonDecode(rawBody);
      if (body is Map<String, dynamic>) {
        return body['message']?.toString();
      }
    } catch (_) {
      // Ignore parse errors.
    }
    return null;
  }
}
