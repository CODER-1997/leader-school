import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/payment_cache_service.dart';
import '../../services/payment_stats_service.dart';

/// MUHIM ARXITEKTURA O'ZGARISHI: avval Admin to'lovlar ro'yxati
/// `collectionGroup('payments')` orqali o'qilardi — bu Firestore'da
/// DOIM qo'lda (Console orqali) yaratiladigan composite index talab
/// qiladi, va bu doimiy ishlash-to'siq (friction) bo'lib qoldi.
///
/// Endi har bir to'lov YOZILGANDA, xuddi shu ID bilan yengil bir
/// nusxasi 'payments_feed' (TOP-LEVEL, oddiy) collection'iga ham
/// yoziladi. Admin endi collectionGroup EMAS, shu oddiy collection'ni
/// o'qiydi — bunday (bitta maydon bo'yicha where+orderBy) so'rovlar
/// uchun Firestore HECH QANDAY qo'lda index talab qilmaydi, avtomatik
/// ishlaydi. Manba (source of truth) hamon
/// students/{studentId}/payments — 'payments_feed' esa faqat admin
/// ro'yxati uchun tez o'qish nusxasi.
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

  Future<void> refresh() async {
    final synced = await _cacheService.syncPayments(studentId);
    payments.value = synced;
  }

  bool get hasSchoolPaymentThisMonth {
    final now = DateTime.now();
    return payments.any((p) {
      if (p['source'] != 'school') return false;
      final date = DateTime.fromMillisecondsSinceEpoch(p['dateMs'] ?? 0);
      return date.year == now.year && date.month == now.month;
    });
  }

  double get totalPaidThisMonth {
    final now = DateTime.now();
    return payments
        .where((p) {
      final date = DateTime.fromMillisecondsSinceEpoch(p['dateMs'] ?? 0);
      return date.year == now.year && date.month == now.month;
    })
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  // =======================================================================
  // QO'SHISH — 1 ta atomik WriteBatch: (1) asosiy hujjat, (2) feed nusxasi,
  // (3) statistika increment. 0 Read.
  // =======================================================================
  Future<Map<String, dynamic>?> addPayment({
    required double amount,
    required DateTime date,
    required String method,
    required String studentName,
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
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(docRef, data);
      batch.set(_feedRef(docRef.id), data); // YANGI: feed nusxasi, bir xil ID

      PaymentStatsService.applyDelta(batch, amountDelta: amount, countDelta: 1, source: 'school', date: date);

      await batch.commit();

      final localEntry = {
        'id': docRef.id,
        'amount': amount,
        'method': method,
        'source': 'school',
        'note': '',
        'isLocked': false,
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
  // TAHRIRLASH — asosiy hujjat VA feed nusxasi bir vaqtda yangilanadi.
  // =======================================================================
  Future<bool> editPayment({
    required String paymentId,
    required double newAmount,
    required DateTime newDate,
    required String newMethod,
  }) async {
    final index = payments.indexWhere((p) => p['id'] == paymentId);
    if (index == -1) return false;

    final old = payments[index];
    if (old['isLocked'] == true) {
      Get.snackbar("Ruxsat yo'q", "Qulflangan to'lovni tahrirlab bo'lmaydi", backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    final oldAmount = old['amount'] as double;
    final oldDate = DateTime.fromMillisecondsSinceEpoch(old['dateMs'] ?? 0);

    isSaving.value = true;
    try {
      final batch = _db.batch();
      final updateData = {
        'amount': newAmount,
        'method': newMethod,
        'date': Timestamp.fromDate(newDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.update(_paymentsRef.doc(paymentId), updateData);
      batch.update(_feedRef(paymentId), updateData); // YANGI: feed ham yangilanadi

      final oldMonth = PaymentStatsService.monthKey(oldDate);
      final newMonth = PaymentStatsService.monthKey(newDate);

      if (oldMonth == newMonth) {
        PaymentStatsService.applyDelta(batch, amountDelta: newAmount - oldAmount, countDelta: 0, source: 'school', date: newDate);
      } else {
        PaymentStatsService.applyDelta(batch, amountDelta: -oldAmount, countDelta: -1, source: 'school', date: oldDate);
        PaymentStatsService.applyDelta(batch, amountDelta: newAmount, countDelta: 1, source: 'school', date: newDate);
      }

      await batch.commit();

      final updated = {...old, 'amount': newAmount, 'method': newMethod, 'dateMs': newDate.millisecondsSinceEpoch};
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
  // O'CHIRISH — asosiy hujjat VA feed nusxasi bir vaqtda o'chiriladi.
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
    final date = DateTime.fromMillisecondsSinceEpoch(payment['dateMs'] ?? 0);

    try {
      final batch = _db.batch();
      batch.delete(_paymentsRef.doc(paymentId));
      batch.delete(_feedRef(paymentId)); // YANGI: feed ham o'chiriladi

      PaymentStatsService.applyDelta(batch, amountDelta: -amount, countDelta: -1, source: 'school', date: date);

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
  // QULFLASH — QAYTARIB BO'LMAYDI. Asosiy hujjat VA feed nusxasi bir
  // vaqtda qulflanadi.
  // =======================================================================
  Future<void> lockPayment(String paymentId) async {
    final index = payments.indexWhere((p) => p['id'] == paymentId);
    if (index == -1) return;

    try {
      final batch = _db.batch();
      final lockData = {'isLocked': true, 'updatedAt': FieldValue.serverTimestamp()};

      batch.update(_paymentsRef.doc(paymentId), lockData);
      batch.update(_feedRef(paymentId), lockData); // YANGI

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