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
  @override
  Future<void> refresh() async {
    final synced = await _cacheService.syncPayments(studentId, forceFull: true);
    // VAQTINCHA DEBUG — muammoni aniqlagach o'chirib tashlang:
    debugPrint("🔍 REFRESH: studentId=$studentId, Firestore/kesh'dan qaytgan to'lovlar soni=${synced.length}");
    payments.value = synced;
    debugPrint("🔍 REFRESH: payments.value yangilandi, hozirgi uzunlik=${payments.length}");
  }

  String get currentMonthKey => PaymentStatsService.monthKeyFor(DateTime.now());

  // MUHIM: endi TO'LOV SANASI emas, balki "QAYSI OY UCHUN" (forMonth)
  // maydoni tekshiriladi — chunki sentabrda avgust uchun to'lov qilingan
  // bo'lishi mumkin, va bu holda "joriy oy to'langan" degan xulosa
  // FAQAT forMonth == joriy_oy bo'lgandagina to'g'ri bo'ladi.
  bool get hasSchoolPaymentThisMonth {
    final key = currentMonthKey;
    return payments.any((p) => p['source'] == 'school' && p['forMonth'] == key);
  }

  double get totalPaidThisMonth {
    final key = currentMonthKey;
    return payments.where((p) => p['forMonth'] == key).fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  // =======================================================================
  // QO'SHISH — 1 ta atomik WriteBatch: (1) asosiy hujjat, (2) feed nusxasi,
  // (3) statistika increment (forMonth bo'yicha). 0 Read.
  // =======================================================================
  Future<Map<String, dynamic>?> addPayment({
    required double amount,
    required DateTime date,
    required String method,
    required String studentName,
    required String forMonthKey, // "YYYY-MM" — qaysi oy uchun to'lov
  }) async {
    isSaving.value = true;
    try {
      final docRef = _paymentsRef.doc();
      final batch = _db.batch();

      final data = {
        'amount': amount,
        'method': method,
        'source': 'school',
        'studentName': studentName,
        'studentId': studentId,
        'isLocked': false,
        'forMonth': forMonthKey,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(docRef, data);
      batch.set(_feedRef(docRef.id), data);

      PaymentStatsService.applyDelta(batch, amountDelta: amount, countDelta: 1, source: 'school', monthKey: forMonthKey);

      await batch.commit();

      final localEntry = {
        'id': docRef.id,
        'amount': amount,
        'method': method,
        'source': 'school',
        'note': '',
        'isLocked': false,
        'forMonth': forMonthKey,
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

    isSaving.value = true;
    try {
      final batch = _db.batch();
      final updateData = {
        'amount': newAmount,
        'method': newMethod,
        'forMonth': newForMonthKey,
        'date': Timestamp.fromDate(newDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.update(_paymentsRef.doc(paymentId), updateData);
      batch.update(_feedRef(paymentId), updateData);

      if (oldForMonth == newForMonthKey) {
        PaymentStatsService.applyDelta(batch, amountDelta: newAmount - oldAmount, countDelta: 0, source: 'school', monthKey: newForMonthKey);
      } else {
        PaymentStatsService.applyDelta(batch, amountDelta: -oldAmount, countDelta: -1, source: 'school', monthKey: oldForMonth);
        PaymentStatsService.applyDelta(batch, amountDelta: newAmount, countDelta: 1, source: 'school', monthKey: newForMonthKey);
      }

      await batch.commit();

      final updated = {...old, 'amount': newAmount, 'method': newMethod, 'forMonth': newForMonthKey, 'dateMs': newDate.millisecondsSinceEpoch};
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

    try {
      final batch = _db.batch();
      batch.delete(_paymentsRef.doc(paymentId));
      batch.delete(_feedRef(paymentId));

      PaymentStatsService.applyDelta(batch, amountDelta: -amount, countDelta: -1, source: 'school', monthKey: forMonth);

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