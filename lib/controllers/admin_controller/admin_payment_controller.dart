import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/payment_stats_service.dart';


class PaymentRecord {
  final String id;
  final String studentName;
  final String studentId;
  final double amount;
  final String source; // 'school' | 'tutoring'
  final String method; // 'cash' | 'card' | 'bank_transfer'
  final DateTime? date;
  final bool isLocked;

  PaymentRecord({
    required this.id,
    required this.studentName,
    required this.studentId,
    required this.amount,
    required this.source,
    required this.method,
    required this.date,
    this.isLocked = false,
  });

  factory PaymentRecord.fromDoc(String id, Map<String, dynamic> data) {
    return PaymentRecord(
      id: id,
      studentName: data['studentName'] ?? 'Noma\'lum',
      studentId: data['studentId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      source: data['source'] ?? 'school',
      method: data['method'] ?? 'cash',
      date: (data['date'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp?)?.toDate(),
      isLocked: data['isLocked'] ?? false,
    );
  }
}

/// Admin uchun BARCHA to'lovlarni bir joyda ko'rsatadi.
///
/// MUHIM: avval bu collectionGroup('payments') orqali o'qirdi — bu DOIM
/// qo'lda Firebase Console'da index yaratishni talab qilardi (doimiy
/// friction). Endi oddiy, TOP-LEVEL 'payments_feed' collection'ini
/// o'qiydi (har bir to'lov yozilganda avtomatik nusxalanadi) — bitta
/// maydon bo'yicha where+orderBy so'rovlar uchun Firestore HECH QANDAY
/// qo'lda index talab qilmaydi, har doim avtomatik ishlaydi.
class AdminPaymentsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = true.obs;
  var payments = <PaymentRecord>[].obs;
  var totalAmount = 0.0.obs;
  var isLocking = false.obs;
  var errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final snap = await _db
          .collection('payments_feed') // collectionGroup EMAS — oddiy collection
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      payments.value = snap.docs.map((doc) => PaymentRecord.fromDoc(doc.id, doc.data())).toList();
      totalAmount.value = await PaymentStatsService.fetchCurrentMonthTotal();
    } catch (e) {
      debugPrint("To'lovlarni yuklashda xato: $e");
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
// YANGI METOD — buni AdminPaymentsController klassi ICHIGA qo'shing
// (masalan lockPaymentsInRange metodidan keyin). Butun faylni emas,
// FAQAT shu metodni qo'shing.
// =========================================================================

  /// Excel hisoboti uchun — tanlangan davrdagi BARCHA to'lovlarni
  /// (limit(50) CHEKLOVISIZ) 'payments_feed'dan o'qiydi.
  Future<List<PaymentRecord>> fetchPaymentsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _db
        .collection('payments_feed')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: false)
        .get();

    return snap.docs.map((doc) => PaymentRecord.fromDoc(doc.id, doc.data())).toList();
  }

  Future<void> refresh() => _fetchPayments();

  // =======================================================================
  // OMMAVIY QULFLASH — endi 'payments_feed'dan (oddiy, index'siz) o'qiydi,
  // lekin har bir topilgan hujjat uchun IKKALASINI ham (feed + asosiy
  // students/{id}/payments hujjati) qulflaydi, chunki har birining o'z
  // manbasi bor.
  // =======================================================================
  Future<int> lockPaymentsInRange({required DateTime start, required DateTime end}) async {
    isLocking.value = true;
    try {
      final snap = await _db
          .collection('payments_feed')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final docsToLock = snap.docs.where((d) => (d.data())['isLocked'] != true).toList();
      if (docsToLock.isEmpty) return 0;

      // Har bir to'lov uchun 2 ta yozuv (feed + asosiy) bo'lgani sababli,
      // batch hajmi 200 to'lovga (=400 yozuv) cheklanadi (Firestore limiti 500).
      const chunkSize = 200;
      for (var i = 0; i < docsToLock.length; i += chunkSize) {
        final chunk = docsToLock.skip(i).take(chunkSize);
        final batch = _db.batch();
        for (final doc in chunk) {
          final data = doc.data();
          final studentId = data['studentId'] as String?;
          final lockData = {'isLocked': true, 'updatedAt': FieldValue.serverTimestamp()};

          batch.update(doc.reference, lockData); // feed nusxasi
          if (studentId != null && studentId.isNotEmpty) {
            batch.update(
              _db.collection('students').doc(studentId).collection('payments').doc(doc.id),
              lockData,
            ); // asosiy hujjat
          }
        }
        await batch.commit();
      }

      await _fetchPayments();
      return docsToLock.length;
    } finally {
      isLocking.value = false;
    }
  }
}