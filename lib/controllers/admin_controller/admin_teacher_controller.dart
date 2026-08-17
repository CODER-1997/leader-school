import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// O'qituvchi/admin roli.
class TeacherRole {
  static const String teacher = 'teacher';
  static const String admin = 'admin';
}

/// O'qituvchi yoki admin haqidagi to'liq ma'lumot.
class TeacherSummary {
  final String id; // Firestore doc ID = sanitized telefon raqami (unikal)
  final String firstName;
  final String lastName;
  final String phone; // ko'rsatish uchun formatlangan
  final String role; // TeacherRole.teacher | TeacherRole.admin
  final bool isActive;
  final Map<String, bool> permissions; // masalan {'viewPayments': true, ...}
  final DateTime? lastLoginAt; // shaxsiy telefon kodi orqali oxirgi kirgan vaqti
  final int loginCount; // jami necha marta kirgan

  TeacherSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.permissions,
    this.lastLoginAt,
    this.loginCount = 0,
  });

  String get fullName {
    final full = "$lastName $firstName".trim();
    return full.isEmpty ? "Nomsiz" : full;
  }

  bool get isAdmin => role == TeacherRole.admin;

  // MUHIM: admin ENDI avtomatik barcha ruxsatlarga ega EMAS — u ham
  // boshqa har qanday hisob kabi faqat aniq belgilangan (permissions
  // xaritasida saqlangan) ruxsatlarga ega. Rol faqat vizual/tashkiliy
  // farqlash uchun, huquq darajasi uchun emas.
  bool get canViewPayments => permissions['viewPayments'] ?? false;
  bool get canEditPayments => permissions['editPayments'] ?? false;
  bool get canSendSms => permissions['sendSms'] ?? false;

  factory TeacherSummary.fromDoc(String id, Map<String, dynamic> data) {
    return TeacherSummary(
      id: id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? TeacherRole.teacher,
      isActive: data['isActive'] ?? true,
      permissions: Map<String, bool>.from(data['permissions'] ?? {}),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      loginCount: data['loginCount'] ?? 0,
    );
  }
}

/// Barcha o'qituvchi/adminlarni boshqaradi. Collection kichik bo'lgani
/// uchun (odatda bir necha o'nlab kishi) real-time listener xavfsiz —
/// index ham kerak emas, chunki faqat bitta tartiblash (orderBy) ishlatiladi.
class AdminTeacherController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = true.obs;
  var teachers = <TeacherSummary>[].obs;

  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void onInit() {
    super.onInit();
    _attachListener();
  }

  void _attachListener() {
    _sub?.cancel();
    _sub = _db
        .collection('teachers')
        .orderBy('lastName')
        .snapshots()
        .listen(_onSnapshot, onError: (e) {
      debugPrint("O'qituvchilar listeneri xatosi: $e");
      isLoading.value = false;
    });
  }

  void _onSnapshot(QuerySnapshot snap) {
    teachers.value = snap.docs
        .map((doc) => TeacherSummary.fromDoc(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
    isLoading.value = false;
  }

  Future<void> refresh() async => _attachListener();

  TeacherSummary? getTeacher(String id) => teachers.firstWhereOrNull((t) => t.id == id);

  /// Telefon raqamini Firestore doc ID sifatida ishlatish uchun tozalaydi
  /// (faqat raqamlar qoladi) — shu bilan bir xil odam ikki marta turli
  /// formatda ("+998901234567" va "998 90 123 45 67") kiritilib, ikkita
  /// alohida hujjat sifatida saqlanib qolishining oldi olinadi.
  String _sanitizePhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// Yangi o'qituvchi/admin qo'shadi. Telefon raqami band bo'lsa xato
  /// qaytaradi (Firestore hujjat ID darajasida unikallik kafolatlanadi).
  Future<bool> addTeacher({
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
    required Map<String, bool> permissions,
  }) async {
    final docId = _sanitizePhone(phone);
    if (docId.isEmpty) {
      Get.snackbar("Xatolik", "Telefon raqami noto'g'ri", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }

    try {
      final docRef = _db.collection('teachers').doc(docId);
      final existing = await docRef.get();
      if (existing.exists) {
        Get.snackbar("Xatolik", "Bu telefon raqami bilan allaqachon ro'yxatdan o'tilgan",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }

      await docRef.set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'role': role,
        'isActive': true,
        'permissions': permissions,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar("Muvaffaqiyatli", "${role == TeacherRole.admin ? 'Admin' : "O'qituvchi"} qo'shildi",
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "Qo'shishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  /// Mavjud o'qituvchini tahrirlaydi. TELEFON RAQAMI (hujjat ID'si)
  /// O'ZGARTIRILMAYDI — chunki u unikal identifikator sifatida ishlatiladi.
  /// Raqamni almashtirish kerak bo'lsa, eskisini o'chirib yangisini
  /// qo'shish to'g'riroq (bu funksiya buni ataylab cheklaydi).
  Future<bool> updateTeacher({
    required String id,
    required String firstName,
    required String lastName,
    required String role,
    required Map<String, bool> permissions,
  }) async {
    try {
      await _db.collection('teachers').doc(id).update({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'role': role,
        'permissions': permissions,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar("Saqlandi", "Ma'lumotlar yangilandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "Yangilashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<void> setActive(String id, bool active) async {
    try {
      await _db.collection('teachers').doc(id).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "Holatni o'zgartirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> setPermission(String id, String key, bool value) async {
    try {
      await _db.collection('teachers').doc(id).update({
        'permissions.$key': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "Ruxsatni o'zgartirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<bool> deleteTeacher(String id) async {
    try {
      await _db.collection('teachers').doc(id).delete();
      Get.snackbar("O'chirildi", "Ma'lumot bazadan olib tashlandi", backgroundColor: const Color(0xFF64748B), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "O'chirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}