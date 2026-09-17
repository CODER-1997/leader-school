import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

/// Hozir tizimga kirgan foydalanuvchining ruxsatlarini o'qiydi.
///
/// IKKI XIL "admin" borligini eslatib o'taman:
///   1. ILOVA DARAJASIDAGI admin — Bosh sahifadagi Maxsus Kod orqali
///      kiradi (AccessCodeService). Bu — maktab/markaz EGASI, Admin
///      panelining o'ziga kiradi. Bunday kirishda GetStorage'da
///      'userRole' == 'admin' bo'ladi va 'teacherId' YO'Q (olib
///      tashlangan). BARCHA ruxsatlarga ega deb hisoblanadi.
///   2. O'QITUVCHI hujjatidagi 'role' maydoni — Admin -> O'qituvchilar
///      bo'limida bir o'qituvchiga "Admin" rolini berish mumkin, lekin
///      bu FAQAT vizual/tashkiliy belgi — ular ham, oddiy o'qituvchi
///      kabi, FAQAT o'zlarining 'permissions' xaritasidagi aniq
///      ruxsatlarga ega (TeacherSummary'dagi izohda ta'kidlangan).
///
/// Shu sababli: 'userRole' == 'admin' (1-holat) => hammasi TRUE.
/// 'userRole' == 'teacher' (2-holat, hatto ularning Firestore roli
/// "admin" bo'lsa ham) => 'teachers/{teacherId}'dagi 'permissions'
/// xaritasidan o'qiladi.
class CurrentUserPermissions {
  static final GetStorage _box = GetStorage();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool get isAppAdmin => _box.read('userRole') == 'admin';
  static String? get currentTeacherId =>
      _box.read('userRole') == 'teacher' ? _box.read('teacherId') as String? : null;

  /// Barcha ruxsatlarni HAR SAFAR YANGI so'rov bilan oladi (keshsiz).
  ///
  /// MUHIM: avval bu yerda static kesh bor edi (bir marta o'qib,
  /// butun sessiya davomida saqlanardi) — lekin bu XATOGA olib keldi:
  /// agar admin o'qituvchining ruxsatini o'zgartirsa-yu, o'qituvchi
  /// ilovani QAYTA ISHGA TUSHIRMASA, eski (noto'g'ri) qiymat keshda
  /// qolib, admin bergan yangi ruxsat KO'RINMASDI. Ruxsat tekshiruvi
  /// xavfsizlik bilan bog'liq bo'lgani uchun — TO'G'RILIK tezlikdan
  /// USTUN: kesh olib tashlandi, har safar Firestore'dan YANGI
  /// o'qiladi (bu — arzon, chunki bitta hujjat, va faqat profil
  /// ochilganda bir marta chaqiriladi).
  static Future<Map<String, bool>> _fetchPermissions() async {
    if (isAppAdmin) {
      // 1-holat: ilova darajasidagi admin — hammasi ruxsat etilgan.
      return {'viewPayments': true, 'editPayments': true, 'sendSms': true};
    }

    final id = currentTeacherId;
    if (id == null || id.isEmpty) return {};

    try {
      final doc = await _db.collection('teachers').doc(id).get();
      return Map<String, bool>.from(doc.data()?['permissions'] ?? {});
    } catch (e) {
      debugPrint("Ruxsatlarni yuklashda xato: $e");
      return {};
    }
  }

  static Future<bool> canViewPayments() async => (await _fetchPermissions())['viewPayments'] ?? false;
  static Future<bool> canEditPayments() async => (await _fetchPermissions())['editPayments'] ?? false;
  static Future<bool> canSendSms() async => (await _fetchPermissions())['sendSms'] ?? false;
}