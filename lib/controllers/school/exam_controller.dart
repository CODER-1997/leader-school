import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/exam_cache_servise.dart';

class ExamController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String classId;
  final ExamCacheService _cacheService = ExamCacheService();

  ExamController({required this.classId});

  var classExams = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;    // birinchi (bo'sh cache) yuklanish uchun
  var isRefreshing = false.obs; // pull-to-refresh uchun

  StreamSubscription<QuerySnapshot>? _sub;

  // Reference counting: bitta sinfda bir nechta fan (subject) bo'lishi
  // mumkin, va har biri o'z ekranida shu classId uchun ExamController'ni
  // so'raydi. Agar 2 ta ekran bir vaqtda shu controller'dan foydalansa,
  // BIRINCHISI dispose bo'lganda controller o'chirilib QOLMASLIGI kerak —
  // aks holda ikkinchi ekran o'lik (listener'i bekor qilingan) controllerga
  // qarab qolib ketadi. _refCount shuni nazorat qiladi.
  int _refCount = 0;

  void addRef() => _refCount++;

  /// true qaytarsa — endi hech kim foydalanmayapti, controller'ni
  /// Get.delete() bilan xavfsiz o'chirish mumkin.
  bool releaseRef() {
    _refCount--;
    return _refCount <= 0;
  }

  @override
  void onInit() {
    super.onInit();
    // 1. AVVAL CACHE'DAN DARHOL KO'RSATISH — 0 Read
    classExams.value = _cacheService.getCachedExams(classId);
    isLoading.value = classExams.isEmpty;

    // 2. REAL-TIME LISTENER — faqat shu sinfga (classId) tegishli exam'lar.
    // Bitta equality filtr (where classId ==) uchun Firestore composite
    // index TALAB QILMAYDI — shuning uchun bu yechim index sozlashsiz ishlaydi.
    // Boshqa o'qituvchi exam yaratsa/o'zgartirsa/o'chirsa — Firestore buni
    // avtomatik push qiladi, foydalanuvchi ekranni tortishi shart emas.
    _attachListener();
  }

  void _attachListener() {
    _sub?.cancel();
    _sub = _db
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .listen(_onSnapshot, onError: (e) {
      debugPrint("Exam listener xatosi: $e");
      isLoading.value = false;
    });
  }

  void _onSnapshot(QuerySnapshot snap) {
    final List<Map<String, dynamic>> list = [];

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isDeleted'] == true) continue; // soft-delete qilinganlarni yashiramiz

      list.add({
        'id': doc.id,
        'classId': classId,
        'name': data['name'],
        'type': data['type'],
        'questionCount': data['questionCount'],
        'createdAt': (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        'scores': Map<String, dynamic>.from(data['scores'] ?? {}),
        // YANGI: SMS yuborilgan holatini ham o'tkazamiz — aks holda
        // Firestore'ga yozilsa ham UI'da (getExam() orqali) ko'rinmasdi,
        // chunki bu yerda faqat ANIQ ro'yxatlangan maydonlar saqlanadi.
        'smsStatus': data['smsStatus'],
      });
    }

    list.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));

    classExams.value = list;
    isLoading.value = false;
    isRefreshing.value = false;

    // Keyingi ilova ochilishida darhol ko'rsatish uchun diskka yozamiz.
    _cacheService.saveSnapshot(classId, list);
  }

  /// Pull-to-refresh: listener'ni qayta ulaydi (masalan uzoq fonda turgandan
  /// keyin ulanishni yangilash uchun). Real-time listener normal holatda
  /// o'zi qayta ulanadi — bu funksiya faqat qo'shimcha kafolat sifatida.
  Future<void> refresh() async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    _attachListener();
    // UI'da spinner bir zumga ko'rinishi uchun minimal kutish
    await Future.delayed(const Duration(milliseconds: 400));
    isRefreshing.value = false;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  // Cache'dan bitta examni olish — 0 Read
  Map<String, dynamic>? getExam(String examId) {
    return classExams.firstWhereOrNull((e) => e['id'] == examId);
  }

  // =======================================================================
  // CREATE — Firestore'ga yozamiz, UI'ni QO'LDA yangilashimiz shart emas:
  // snapshots() listener local pending-write'ni ham darhol qaytaradi
  // (optimistic UI Firestore SDK tomonidan avtomatik ta'minlanadi), xato
  // bo'lsa esa Firestore local cache'dan o'zi olib tashlaydi va listener
  // qayta chaqiriladi — demak qo'lda rollback kerak emas.
  // =======================================================================
  Future<void> createExam(String examName, String type, int questionCount) async {
    final name = examName.trim();
    if (name.isEmpty) return;

    try {
      await _db.collection('exams').doc().set({
        'classId': classId,
        'name': name,
        'type': type,
        'questionCount': questionCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'scores': {},
        'isDeleted': false,
      });

      Get.snackbar("Muvaffaqiyatli", "Imtihon yaratildi",
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Imtihon qo'shishda xato: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> editExam(String examId, String name, String type, int questionCount) async {
    try {
      await _db.collection('exams').doc(examId).update({
        'name': name,
        'type': type,
        'questionCount': questionCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "Tahrirlashda xato: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // SOFT DELETE — hard delete emas, isDeleted:true. Shunda boshqa
  // o'qituvchilarning listener'i ham buni "o'zgarish" sifatida oladi va
  // ro'yxatidan olib tashlaydi. Hard delete qilingan hujjat listener'ga
  // umuman signal bermay, faqat local snapshot diff orqali chiqib ketadi —
  // amalda ishlaydi, lekin soft delete tarix/audit uchun ham qulayroq.
  Future<void> deleteExam(String examId) async {
    try {
      await _db.collection('exams').doc(examId).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "O'chirishda xato: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> saveScores(String examId, Map<String, dynamic> scores) async {
    try {
      await _db.collection('exams').doc(examId).update({
        'scores': scores,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "Saqlashda xato yuz berdi: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
      rethrow;
    }
  }

  /// YANGI: SMS yuborilgan vaqtni HUJJATNING O'ZIDA saqlaydi — shu bilan
  /// boshqa o'qituvchi/admin ham "SMS allaqachon yuborilgan" ekanini
  /// ko'radi, va ota-onani qayta-qayta bezovta qilishning oldi olinadi.
  /// Nuqta-yo'l (dot notation) ishlatiladi — shunda 'sentCount' haqiqiy
  /// OLDINGI qiymatga nisbatan oshiriladi.
  Future<void> markSmsSent(String examId) async {
    await _db.collection('exams').doc(examId).update({
      'smsStatus.sentAt': FieldValue.serverTimestamp(),
      'smsStatus.sentCount': FieldValue.increment(1),
    });
  }
}