import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../services/password_hasher.dart';

/// MUHIM: bu fayl ishlashi uchun pubspec.yaml'ga qo'shing (agar hali yo'q bo'lsa):
///   crypto: ^3.0.3
///   get_storage: ^2.1.1

/// Qurilmani device_info_plus paketisiz yengil aniqlash: platform nomi
/// (dart:io) + GetStorage'da doimiy saqlanadigan tasodifiy ID (bir marta
/// yaratiladi, shu qurilma uchun doim bir xil qoladi).
class AdminDeviceInfo {
  final String deviceId;
  final String platform;
  final String osVersion;

  AdminDeviceInfo({required this.deviceId, required this.platform, required this.osVersion});

  static Future<AdminDeviceInfo> current() async {
    final box = GetStorage();
    String? id = box.read<String>('admin_device_id');
    if (id == null) {
      final rand = Random();
      final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
      id = base64Url.encode(bytes).replaceAll('=', '');
      await box.write('admin_device_id', id);
    }

    String platform = 'unknown';
    String osVersion = '';
    if (kIsWeb) {
      platform = 'web';
    } else {
      try {
        platform = Platform.operatingSystem; // 'android' | 'ios' | ...
        osVersion = Platform.operatingSystemVersion;
      } catch (_) {}
    }

    return AdminDeviceInfo(deviceId: id, platform: platform, osVersion: osVersion);
  }
}

class AdminLoginLog {
  final String deviceId;
  final String platform;
  final String osVersion;
  final bool success;
  final DateTime? timestamp;

  AdminLoginLog({
    required this.deviceId,
    required this.platform,
    required this.osVersion,
    required this.success,
    required this.timestamp,
  });

  factory AdminLoginLog.fromMap(Map<String, dynamic> data) {
    return AdminLoginLog(
      deviceId: data['deviceId'] ?? 'noma\'lum',
      platform: data['platform'] ?? 'noma\'lum',
      osVersion: data['osVersion'] ?? '',
      success: data['success'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

/// Admin panelga kirish parolini boshqaradi va kirish tarixini (qaysi
/// qurilmadan, qachon, muvaffaqiyatli/muvaffaqiyatsiz) Firestore'da
/// 'admin_login_logs' collection'ida saqlaydi.
///
/// Parol: Firestore'da 'settings/security' hujjatida — FAQAT hash+salt.
/// Bu sozlama kamdan-kam o'zgaradi, shuning uchun real-time listener
/// shart emas — bir martalik .get()/.set() yetarli.
class AdminSecurityController extends GetxController {
  static const String _docPath = 'settings';
  static const String _docId = 'security';
  static const String _logsCollection = 'admin_login_logs';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = true.obs;
  var hasPasswordSet = false.obs;
  var isSaving = false.obs;

  var loginLogs = <AdminLoginLog>[].obs;
  var isLoadingLogs = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSecurityState();
    _loadLoginLogs();
  }

  Future<void> _loadSecurityState() async {
    isLoading.value = true;
    try {
      final doc = await _db.collection(_docPath).doc(_docId).get();
      hasPasswordSet.value = doc.exists && doc.data()?['passwordHash'] != null;
    } catch (e) {
      debugPrint("Xavfsizlik holatini yuklashda xato: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadLoginLogs() async {
    isLoadingLogs.value = true;
    try {
      final snap = await _db
          .collection(_logsCollection)
          .orderBy('timestamp', descending: true)
      // MUHIM: avval 30 ta hujjat o'qilardi, garchi UI dastlab faqat
      // 5 tasini ko'rsatsa ham (qolgani "Barchasini ko'rish" bosilsagina
      // ko'rinadi). Admin panelga har safar kirib-chiqishda (controllerlar
      // tozalanib, qayta yaratilganda) bu 30 o'qish qaytadan sodir bo'lib,
      // login qilish/panelni tekshirish odatiy holatiga nisbatan
      // nomutanosib ko'p read hosil qilardi. 15 ga tushirildi — hali ham
      // yetarlicha tarix beradi, lekin xarajat ikki baravardan ko'proq kamaydi.
          .limit(15)
          .get();
      loginLogs.value = snap.docs.map((d) => AdminLoginLog.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint("Kirish tarixini yuklashda xato: $e");
    } finally {
      isLoadingLogs.value = false;
    }
  }

  Future<void> refreshLogs() => _loadLoginLogs();

  /// Yangi parol o'rnatish yoki mavjudini almashtirish.
  /// Parol allaqachon o'rnatilgan bo'lsa, [currentPassword] TO'G'RI bo'lishi
  /// shart — aks holda almashtirilmaydi (buzg'unchi parolni o'zgartirib
  /// qo'yishining oldini oladi).
  Future<bool> setPassword({required String newPassword, String? currentPassword}) async {
    if (newPassword.trim().length < 4) {
      Get.snackbar("Diqqat", "Parol kamida 4 ta belgidan iborat bo'lishi kerak",
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    isSaving.value = true;
    try {
      if (hasPasswordSet.value) {
        if (currentPassword == null || currentPassword.isEmpty) {
          Get.snackbar("Diqqat", "Joriy parolni kiriting",
              backgroundColor: Colors.orange, colorText: Colors.white);
          return false;
        }
        final doc = await _db.collection(_docPath).doc(_docId).get();
        final data = doc.data();
        final storedHash = data?['passwordHash'];
        final storedSalt = data?['passwordSalt'];
        if (storedHash == null || storedSalt == null ||
            PasswordHasher.hash(currentPassword, storedSalt) != storedHash) {
          Get.snackbar("Xatolik", "Joriy parol noto'g'ri",
              backgroundColor: Colors.red, colorText: Colors.white);
          return false;
        }
      }

      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(newPassword.trim(), salt);

      await _db.collection(_docPath).doc(_docId).set({
        'passwordHash': hash,
        'passwordSalt': salt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      hasPasswordSet.value = true;

      Get.snackbar("Saqlandi", "Admin paroli yangilandi",
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "Parolni saqlashda xato: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// AdminAuthGate tomonidan chaqiriladi: kiritilgan parolni Firestore'dagi
  /// hash bilan solishtiradi VA natijani (muvaffaqiyatli yoki yo'q) qurilma
  /// ma'lumotlari bilan birga 'admin_login_logs'ga yozadi.
  static Future<bool> verifyAndLog(String password) async {
    final db = FirebaseFirestore.instance;
    bool success = false;

    try {
      final doc = await db.collection(_docPath).doc(_docId).get();
      final data = doc.data();
      if (data != null && data['passwordHash'] != null && data['passwordSalt'] != null) {
        success = PasswordHasher.hash(password, data['passwordSalt']) == data['passwordHash'];
      }
    } catch (e) {
      debugPrint("Kirishni tekshirishda xato: $e");
    }

    try {
      final deviceInfo = await AdminDeviceInfo.current();
      await db.collection(_logsCollection).add({
        'deviceId': deviceInfo.deviceId,
        'platform': deviceInfo.platform,
        'osVersion': deviceInfo.osVersion,
        'success': success,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Kirish urinishini yozishda xato: $e");
    }

    return success;
  }

  /// Parol umuman o'rnatilmaganmi — shuni tez tekshirish uchun (AdminAuthGate
  /// controller yaratmasdan turib bilishi kerak bo'lganda ishlatiladi).
  static Future<bool> isPasswordRequired() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_docPath).doc(_docId).get();
      return doc.exists && doc.data()?['passwordHash'] != null;
    } catch (e) {
      debugPrint("Parol holatini tekshirishda xato: $e");
      return false;
    }
  }
}