import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// O'QUV MARKAZ uchun MUSTAQIL imtihon controlleri.
///
/// MUHIM: bu Maktabning ExamController'iga HECH QANDAY aloqasi yo'q —
/// alohida Firestore collection ('center_exams', Maktabning 'exams'
/// collection'idan BUTUNLAY BOSHQA), alohida real-time listener, alohida
/// GetX klassi. Metod/maydon nomlari Maktabning ExamController'iga
/// ATAYLAB bir xil qilib qo'yilgan (classExams, getExam, createExam,
/// editExam, deleteExam, saveScores, refresh) — shu bilan bir xil UI
/// kodini (CenterExamsTabScreen/CenterExamScoresScreen) qayta ishlatish
/// oson bo'ladi, lekin ma'lumotning o'zi butunlay mustaqil.
class CenterExamController extends GetxController {
  final String groupId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CenterExamController({required this.groupId});

  var classExams = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = RxnString();

  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void onInit() {
    super.onInit();
    _attachListener();
  }

  void _attachListener() {
    _sub = _db
        .collection('center_exams')
        .where('groupId', isEqualTo: groupId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      errorMessage.value = null;
      final list = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
      list.sort((a, b) {
        final ta = a['createdAt'] as Timestamp?;
        final tb = b['createdAt'] as Timestamp?;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
      classExams.value = list;
      isLoading.value = false;
    }, onError: (e) {
      debugPrint("Markaz imtihonlarini yuklashda xato: $e");
      errorMessage.value = e.toString();
      isLoading.value = false;
    });
  }

  /// 0 Read — allaqachon xotiradagi (real-time listener orqali yuklangan)
  /// ro'yxatdan qidiradi.
  Map<String, dynamic>? getExam(String examId) {
    try {
      return classExams.firstWhere((e) => e['id'] == examId);
    } catch (_) {
      return null;
    }
  }

  Future<void> createExam(String name, String type, int questionCount) async {
    try {
      await _db.collection('center_exams').add({
        'groupId': groupId,
        'name': name,
        'type': type,
        'questionCount': questionCount,
        'isDeleted': false,
        'scores': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "Imtihon yaratishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> editExam(String examId, String name, String type, int questionCount) async {
    try {
      await _db.collection('center_exams').doc(examId).update({
        'name': name,
        'type': type,
        'questionCount': questionCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Get.snackbar("Xatolik", "Yangilashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> deleteExam(String examId) async {
    try {
      await _db.collection('center_exams').doc(examId).update({'isDeleted': true});
    } catch (e) {
      Get.snackbar("Xatolik", "O'chirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  /// Barcha o'quvchilar ballarini BITTA write bilan saqlaydi.
  Future<void> saveScores(String examId, Map<String, dynamic> scores) async {
    await _db.collection('center_exams').doc(examId).update({
      'scores': scores,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// YANGI: SMS yuborilgan vaqtni HUJJATNING O'ZIDA saqlaydi — shu bilan
  /// boshqa o'qituvchi/admin ham "SMS allaqachon yuborilgan" ekanini
  /// ko'radi, va ota-onani qayta-qayta bezovta qilishning oldi olinadi.
  /// MUHIM: nuqta-yo'l (dot notation) ishlatiladi — shunda 'sentCount'
  /// haqiqiy OLDINGI qiymatga nisbatan oshiriladi (butun 'smsStatus'
  /// ob'ektini almashtirib yubormaydi).
  Future<void> markSmsSent(String examId) async {
    await _db.collection('center_exams').doc(examId).update({
      'smsStatus.sentAt': FieldValue.serverTimestamp(),
      'smsStatus.sentCount': FieldValue.increment(1),
    });
  }

  Future<void> refresh() async {
    // Real-time listener allaqachon avtomatik yangilaydi — bu faqat
    // RefreshIndicator uchun qulaylik (darhol qayta ulanishni his qildirish).
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}