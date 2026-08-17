import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'password_hasher.dart';

/// "Maxsus kod" (Home ekranidan admin/teacher rolini beruvchi kod) —
/// ENDI ILOVA KODI ICHIDA QATTIQ YOZILMAGAN. Avval `if (code == "admin")`
/// kabi kod APK ichida ochiq turardi (decompile qilib topsa bo'lardi).
/// Endi kod Firestore'da FAQAT xesh (SHA-256 + salt) sifatida saqlanadi —
/// xuddi AdminSecurityController'dagi panel paroli kabi.
///
/// Firestore manzili: 'settings/security' hujjatida
///   adminCodeHash, adminCodeSalt
/// (bu — AdminSecurityController ishlatadigan passwordHash/passwordSalt
/// maydonlaridan MUSTAQIL — ikkita alohida himoya qatlami: (1) bu kod rolni
/// beradi, (2) panel paroli esa admin bo'limiga qayta kirishda so'raladi).
///
/// BOOTSTRAP: agar Firestore'da hali kod umuman o'rnatilmagan bo'lsa
/// (ilovani ilk marta sozlayotganda), vaqtinchalik standart kod "admin"
/// ishlaydi — FAQAT shu holatda. Sozlamalar > Xavfsizlik'dan haqiqiy kod
/// o'rnatilishi bilanoq, standart kod butunlay ishlamay qoladi.
class AccessCodeService {
  AccessCodeService._();

  static const String _docPath = 'settings';
  static const String _docId = 'security';
  static const String _bootstrapDefaultCode = 'admin'; // FAQAT ilk sozlashgacha

  static Future<bool> hasAdminCodeSet() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_docPath).doc(_docId).get();
      return doc.exists && doc.data()?['adminCodeHash'] != null;
    } catch (e) {
      debugPrint("Admin kod holatini tekshirishda xato: $e");
      return false;
    }
  }

  /// Kiritilgan kod adminlik huquqini berishi kerakmi.
  static Future<bool> verifyAdminCode(String code) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_docPath).doc(_docId).get();
      final data = doc.data();

      final hash = data?['adminCodeHash'];
      final salt = data?['adminCodeSalt'];

      if (hash == null || salt == null) {
        // Hali hech kim haqiqiy kod o'rnatmagan — vaqtinchalik bootstrap.
        return code == _bootstrapDefaultCode;
      }

      return PasswordHasher.hash(code, salt) == hash;
    } catch (e) {
      debugPrint("Admin kodni tekshirishda xato: $e");
      return false;
    }
  }

  /// Yangi kod o'rnatish/almashtirish. Kod allaqachon o'rnatilgan bo'lsa,
  /// [currentCode] TO'G'RI bo'lishi shart — bu buzg'unchi kodni o'zgartirib
  /// qo'yishining oldini oladi.
  static Future<bool> setAdminCode({required String newCode, String? currentCode}) async {
    final trimmed = newCode.trim();
    if (trimmed.length < 4) return false;

    final alreadySet = await hasAdminCodeSet();
    if (alreadySet) {
      if (currentCode == null || currentCode.isEmpty) return false;
      final isCurrentValid = await verifyAdminCode(currentCode);
      if (!isCurrentValid) return false;
    }

    final salt = PasswordHasher.generateSalt();
    final hash = PasswordHasher.hash(trimmed, salt);

    await FirebaseFirestore.instance.collection(_docPath).doc(_docId).set({
      'adminCodeHash': hash,
      'adminCodeSalt': salt,
      'adminCodeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }
}