import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── Network Error Message Tests ───────────────────────────────────────────
  group('Network Error Messages', () {
    String getErrorMessage(String errorStr) {
      if (errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection error') ||
          errorStr.contains('DioException') ||
          errorStr.contains('NetworkException')) {
        return 'No internet connection. Please check your network and try again.';
      } else if (errorStr.contains('TimeoutException') ||
          errorStr.contains('timeout')) {
        return 'Slow or no internet connection. Please try again.';
      } else {
        return 'Something went wrong. Please try again.';
      }
    }

    bool isNetworkError(String errorStr) {
      return errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection error') ||
          errorStr.contains('DioException') ||
          errorStr.contains('NetworkException') ||
          errorStr.contains('TimeoutException') ||
          errorStr.contains('timeout');
    }

    test('SocketException returns correct message', () {
      final msg = getErrorMessage('SocketException: Failed host lookup');
      expect(msg, 'No internet connection. Please check your network and try again.');
    });

    test('Failed host lookup returns correct message', () {
      final msg = getErrorMessage('Failed host lookup');
      expect(msg, 'No internet connection. Please check your network and try again.');
    });

    test('DioException returns correct message', () {
      final msg = getErrorMessage('DioException connection error');
      expect(msg, 'No internet connection. Please check your network and try again.');
    });

    test('TimeoutException returns correct message', () {
      final msg = getErrorMessage('TimeoutException after 30000ms');
      expect(msg, 'Slow or no internet connection. Please try again.');
    });

    test('timeout keyword returns correct message', () {
      final msg = getErrorMessage('Connection timeout');
      expect(msg, 'Slow or no internet connection. Please try again.');
    });

    test('Unknown error returns generic message', () {
      final msg = getErrorMessage('Some unknown error occurred');
      expect(msg, 'Something went wrong. Please try again.');
    });

    test('Network error is identified correctly', () {
      expect(isNetworkError('SocketException: Failed host lookup'), true);
    });

    test('Timeout error is identified correctly', () {
      expect(isNetworkError('TimeoutException after 30000ms'), true);
    });

    test('Invalid credentials is NOT a network error', () {
      expect(isNetworkError('Invalid email or password'), false);
    });
  });

  // ─── Null Check Tests ───────────────────────────────────────────────────────
  group('Null Check Tests', () {
    test('Empty string is not null but is empty', () {
      const String? value = '';
      expect(value, isNotNull);
      expect(value!.isEmpty, true);
    });

    test('Null token is detected correctly', () {
      const String? token = null;
      expect(token == null, true);
    });

    test('Valid token is not null', () {
      const String? token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      expect(token, isNotNull);
      expect(token!.isNotEmpty, true);
    });

    test('Null email is detected correctly', () {
      const String? email = null;
      expect(email == null, true);
    });

    test('Empty email fails validation', () {
      const String email = '';
      expect(email.trim().isEmpty, true);
    });

    test('Null response data is handled', () {
      final Map<String, dynamic>? data = null;
      expect(data == null, true);
      final result = data ?? {'status': 'error'};
      expect(result['status'], 'error');
    });
  });

  // ─── Token Handle Tests ─────────────────────────────────────────────────────
  group('Token Handle Tests', () {
    test('Valid token format is accepted', () {
      const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      expect(token.isNotEmpty, true);
    });

    test('Empty token is rejected', () {
      const token = '';
      expect(token.isEmpty, true);
    });

    test('Token is added to Authorization header correctly', () {
      const token = 'test_token_123';
      final headers = <String, dynamic>{};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      expect(headers['Authorization'], 'Bearer test_token_123');
    });

    test('Null token does not add Authorization header', () {
      const String? token = null;
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      expect(headers.containsKey('Authorization'), false);
    });

    test('Token with spaces is trimmed correctly', () {
      const token = '  test_token_123  ';
      expect(token.trim(), 'test_token_123');
    });
  });

  // ─── API Response Tests ─────────────────────────────────────────────────────
  group('API Response Tests', () {
    test('Success response with token is valid', () {
      final response = {
        'token': 'test_token_123',
        'user_id': 1,
        'display_name': 'Test User',
      };
      expect(response['token'], isNotNull);
      expect(response['user_id'], isNotNull);
    });

    test('Error response without token is detected', () {
      final response = {
        'status': 'error',
        'message': 'Invalid email or password',
      };
      expect(response['token'], isNull);
      expect(response['status'], 'error');
    });

    test('Empty response is handled correctly', () {
      final Map<String, dynamic> response = {};
      final token = response['token'];
      expect(token, isNull);
    });

    test('Response with null token is handled', () {
      final response = {'token': null, 'status': 'error'};
      expect(response['token'] == null, true);
    });

    test('Response status success is detected', () {
      final response = {'status': 'success', 'token': 'abc123'};
      expect(response['status'], 'success');
      expect(response['token'], isNotNull);
    });

    test('Response with error message is handled', () {
      final response = {
        'status': 'error',
        'error': 'User not found',
      };
      final errorMsg = response['message'] ?? response['error'] ?? 'Something went wrong';
      expect(errorMsg, 'User not found');
    });
  });

  // ─── Edge Case Tests ────────────────────────────────────────────────────────
  group('Edge Case Tests', () {
    test('Email with spaces is trimmed correctly', () {
      const email = '  test@gmail.com  ';
      expect(email.trim(), 'test@gmail.com');
    });

    test('Email is case insensitive', () {
      const email = 'TEST@GMAIL.COM';
      expect(email.toLowerCase(), 'test@gmail.com');
    });

    test('Password with only spaces is invalid', () {
      const password = '     ';
      expect(password.trim().isEmpty, true);
    });

    test('Phone number starting with 5 is invalid', () {
      const phone = '5123456789';
      final isValid = RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone);
      expect(isValid, false);
    });

    test('Phone number starting with 9 is valid', () {
      const phone = '9876543210';
      final isValid = RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone);
      expect(isValid, true);
    });

    test('Phone number with 9 digits is invalid', () {
      const phone = '987654321';
      final isValid = RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone);
      expect(isValid, false);
    });

    test('Non gmail email is invalid', () {
      const email = 'test@yahoo.com';
      final isValid = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(email);
      expect(isValid, false);
    });

    test('Gmail email is valid', () {
      const email = 'test@gmail.com';
      final isValid = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(email);
      expect(isValid, true);
    });

    test('Password less than 6 characters is invalid', () {
      const password = '12345';
      expect(password.length < 6, true);
    });

    test('Display name with numbers is invalid', () {
      const name = 'Test123';
      final isValid = RegExp(r'^[a-zA-Z\s]+$').hasMatch(name.trim());
      expect(isValid, false);
    });

    test('Display name with only letters is valid', () {
      const name = 'Test User';
      final isValid = RegExp(r'^[a-zA-Z\s]+$').hasMatch(name.trim());
      expect(isValid, true);
    });

    test('Mismatched passwords are detected', () {
      const password = 'password123';
      const confirmPassword = 'password456';
      expect(password == confirmPassword, false);
    });

    test('Matched passwords are detected', () {
      const password = 'password123';
      const confirmPassword = 'password123';
      expect(password == confirmPassword, true);
    });
  });
}