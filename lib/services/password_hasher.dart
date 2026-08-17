import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Parol/kodlarni xavfsiz xesh qilish uchun umumiy (Getx'siz) yordamchi.
/// Hech qachon ochiq matn saqlanmaydi — faqat tasodifiy "salt" + SHA-256 xesh.
/// AdminSecurityController (panel paroli) va AccessCodeService (kirish
/// kodi) ikkalasi ham shu bitta implementatsiyani ishlatadi.
class PasswordHasher {
  PasswordHasher._();

  static String generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hash(String value, String salt) {
    final bytes = utf8.encode(salt + value);
    return sha256.convert(bytes).toString();
  }
}