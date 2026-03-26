import 'package:flutter_test/flutter_test.dart';

void main() {
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

    test('SocketException returns correct message', () {
      final msg = getErrorMessage('SocketException: Failed host lookup');
      expect(msg,
          'No internet connection. Please check your network and try again.');
    });

    test('Failed host lookup returns correct message', () {
      final msg = getErrorMessage('Failed host lookup');
      expect(msg,
          'No internet connection. Please check your network and try again.');
    });

    test('DioException returns correct message', () {
      final msg = getErrorMessage('DioException connection error');
      expect(msg,
          'No internet connection. Please check your network and try again.');
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

    test('Network error is identified as network issue', () {
      final errorStr = 'SocketException: Failed host lookup';
      final isNetwork = errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection error') ||
          errorStr.contains('DioException') ||
          errorStr.contains('NetworkException');
      expect(isNetwork, true);
    });

    test('Timeout error is identified as network issue', () {
      final errorStr = 'TimeoutException after 30000ms';
      final isNetwork = errorStr.contains('TimeoutException') ||
          errorStr.contains('timeout');
      expect(isNetwork, true);
    });

    test('Invalid credentials is NOT a network issue', () {
      final errorStr = 'Invalid email or password';
      final isNetwork = errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('TimeoutException') ||
          errorStr.contains('timeout');
      expect(isNetwork, false);
    });
  });
}