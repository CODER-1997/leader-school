import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/payment_cache_service.dart';
import '../../services/payment_stats_service.dart';


class StudentPaymentController extends GetxController {
  final String studentId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PaymentCacheService _cacheService = PaymentCacheService();

  StudentPaymentController({required this.studentId});

  var payments = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isSaving = false.obs;

  CollectionReference get _paymentsRef =>
      _db.collection('students').doc(studentId).collection('payments');

  DocumentReference _feedRef(String paymentId) =>
      _db.collection('payments_feed').doc(paymentId);

  @override
  void onInit() {
    super.onInit();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    payments.value = _cacheService.getCachedPayments(studentId);
    isLoading.value = payments.isEmpty;
    try {
      final synced = await _cacheService.syncPayments(studentId);
      payments.value = synced;
    } catch (e) {
      debugPrint("To'lovlarni sync qilishda xato: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// MUHIM: bu FULL (delta emas) sync ishlatadi — foydalanuvchi "Yangilash"
  /// tugmasini bosganda, u aynan "ma'lumot serverda o'zgargan bo'lishi
  /// mumkin, hammasini qayta tekshir" deb signal beryapti. Shu sababli
  /// delta-cursor'ga ishonib o'tirmaymiz.
  Future<void> refresh() async {
    final synced = await _cacheService.syncPayments(studentId, forceFull: true);
    payments.value = synced;
  }

  String get currentMonthKey => PaymentStatsService.monthKeyFor(DateTime.now());

  // MUHIM: TO'LOV SANASI emas, "QAYSI OY UCHUN" (forMonth) tekshiriladi.
  bool get hasSchoolPaymentThisMonth {
    final key = currentMonthKey;
    return payments.any((p) => p['source'] == 'school' && p['forMonth'] == key);
  }

  // YANGI: O'QUV MARKAZ uchun — FAN darajasida tekshiradi. Bitta fanga
  // to'lansa, o'sha fandagi BARCHA guruhlar (nechta bo'lishidan qat'i
  // nazar) "to'langan" hisoblanadi, chunki to'lov guruhga emas, FANGA
  // biriktiriladi (forSubjectId).
  bool hasSubjectPaymentThisMonth(String subjectId) {
    final key = currentMonthKey;
    return payments.any((p) =>
    p['source'] == 'tutoring' &&
        p['forSubjectId'] == subjectId &&
        p['forMonth'] == key);
  }

  double get totalPaidThisMonth {
    final key = currentMonthKey;
    return payments.where((p) => p['forMonth'] == key).fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  // =======================================================================
  // QO'SHISH — 1 ta atomik WriteBatch: (1) asosiy hujjat, (2) feed nusxasi,
  // (3) statistika increment (forMonth bo'yicha). 0 Read.
  //
  // YANGI: 'source' endi PARAMETR ('school' yoki 'tutoring'). Agar
  // 'tutoring' bo'lsa, 'forSubjectId' MAJBURIY — bu orqali to'lov aynan
  // FANGA (guruhga emas) biriktiriladi.
  // =======================================================================
  Future<Map<String, dynamic>?> addPayment({
    required double amount,
    required DateTime date,
    required String method,
    required String studentName,
    required String forMonthKey, // "YYYY-MM" — qaysi oy uchun to'lov
    String source = 'school', // YANGI
    String? forSubjectId, // YANGI — faqat source=='tutoring' bo'lsa ishlatiladi
  }) async {
    isSaving.value = true;
    try {
      final docRef = _paymentsRef.doc();
      final batch = _db.batch();

      final data = {
        'amount': amount,
        'method': method,
        'source': source,
        'studentName': studentName,
        'studentId': studentId,
        'isLocked': false,
        'forMonth': forMonthKey,
        if (source == 'tutoring' && forSubjectId != null) 'forSubjectId': forSubjectId,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(docRef, data);
      batch.set(_feedRef(docRef.id), data);

      PaymentStatsService.applyDelta(batch, amountDelta: amount, countDelta: 1, source: source, monthKey: forMonthKey);

      await batch.commit();

      final localEntry = {
        'id': docRef.id,
        'amount': amount,
        'method': method,
        'source': source,
        'note': '',
        'isLocked': false,
        'forMonth': forMonthKey,
        if (source == 'tutoring' && forSubjectId != null) 'forSubjectId': forSubjectId,
        'dateMs': date.millisecondsSinceEpoch,
      };

      payments.insert(0, localEntry);
      await _cacheService.addToCache(studentId, localEntry);

      return localEntry;
    } catch (e) {
      Get.snackbar("Xatolik", "To'lovni saqlashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  // =======================================================================
  // TAHRIRLASH
  // =======================================================================
  Future<bool> editPayment({
    required String paymentId,
    required double newAmount,
    required DateTime newDate,
    required String newMethod,
    required String newForMonthKey,
    String? newForSubjectId, // YANGI
  }) async {
    final index = payments.indexWhere((p) => p['id'] == paymentId);
    if (index == -1) return false;

    final old = payments[index];
    if (old['isLocked'] == true) {
      Get.snackbar("Ruxsat yo'q", "Qulflangan to'lovni tahrirlab bo'lmaydi", backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    final oldAmount = old['amount'] as double;
    final oldForMonth = old['forMonth'] as String? ?? '';
    final source = old['source'] as String? ?? 'school';

    isSaving.value = true;
    try {
      final batch = _db.batch();
      final updateData = {
        'amount': newAmount,
        'method': newMethod,
        'forMonth': newForMonthKey,
        if (newForSubjectId != null) 'forSubjectId': newForSubjectId,
        'date': Timestamp.fromDate(newDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.update(_paymentsRef.doc(paymentId), updateData);
      batch.update(_feedRef(paymentId), updateData);

      if (oldForMonth == newForMonthKey) {
        PaymentStatsService.applyDelta(batch, amountDelta: newAmount - oldAmount, countDelta: 0, source: source, monthKey: newForMonthKey);
      } else {
        PaymentStatsService.applyDelta(batch, amountDelta: -oldAmount, countDelta: -1, source: source, monthKey: oldForMonth);
        PaymentStatsService.applyDelta(batch, amountDelta: newAmount, countDelta: 1, source: source, monthKey: newForMonthKey);
      }

      await batch.commit();

      final updated = {
        ...old,
        'amount': newAmount,
        'method': newMethod,
        'forMonth': newForMonthKey,
        if (newForSubjectId != null) 'forSubjectId': newForSubjectId,
        'dateMs': newDate.millisecondsSinceEpoch,
      };
      payments[index] = updated;
      await _cacheService.addToCache(studentId, updated);

      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "Tahrirlashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // =======================================================================
  // O'CHIRISH
  // =======================================================================
  Future<bool> deletePayment(String paymentId) async {
    final index = payments.indexWhere((p) => p['id'] == paymentId);
    if (index == -1) return false;

    final payment = payments[index];
    if (payment['isLocked'] == true) {
      Get.snackbar("Ruxsat yo'q", "Qulflangan to'lovni o'chirib bo'lmaydi", backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    final amount = payment['amount'] as double;
    final forMonth = payment['forMonth'] as String? ?? '';
    final source = payment['source'] as String? ?? 'school';

    try {
      final batch = _db.batch();
      batch.delete(_paymentsRef.doc(paymentId));
      batch.delete(_feedRef(paymentId));

      PaymentStatsService.applyDelta(batch, amountDelta: -amount, countDelta: -1, source: source, monthKey: forMonth);

      await batch.commit();

      payments.removeAt(index);
      await _cacheService.removeFromCache(studentId, paymentId);

      Get.snackbar("O'chirildi", "To'lov o'chirildi", backgroundColor: const Color(0xFF64748B), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "O'chirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  // =======================================================================
  // QULFLASH — QAYTARIB BO'LMAYDI.
  // =======================================================================
  Future<void> lockPayment(String paymentId) async {
    final index = payments.indexWhere((p) => p['id'] == paymentId);
    if (index == -1) return;

    try {
      final batch = _db.batch();
      final lockData = {'isLocked': true, 'updatedAt': FieldValue.serverTimestamp()};

      batch.update(_paymentsRef.doc(paymentId), lockData);
      batch.update(_feedRef(paymentId), lockData);

      await batch.commit();

      final updated = {...payments[index], 'isLocked': true};
      payments[index] = updated;
      await _cacheService.addToCache(studentId, updated);

      Get.snackbar("Qulflandi", "To'lov endi tahrirlanmaydi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Qulflashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}