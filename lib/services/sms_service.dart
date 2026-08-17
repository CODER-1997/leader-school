import 'package:flutter/services.dart';

class SMSService {
  static const MethodChannel _channel = MethodChannel('sms_service');

  Future<void> sendSMS(String recipient, String message) async {
    try {
      final cleanedRecipient = recipient
          .replaceAll(' ', '')
          .replaceAll('-', '')
          .replaceAll('(', '')
          .replaceAll(')', '');

      await _channel.invokeMethod('sendSMS', {
        'recipient': cleanedRecipient,
        'message': message,
      });
    } on PlatformException catch (e) {
      throw Exception("SMS yuborilmadi: ${e.message}");
    } catch (e) {
      throw Exception("Noma'lum xatolik: $e");
    }
  }
}