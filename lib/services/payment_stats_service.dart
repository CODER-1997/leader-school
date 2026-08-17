import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ADMIN STATISTIKASI UCHUN DENORMALIZED HUJJAT.
///
/// MUHIM: oylik statistika endi TO'LOV SANASI emas, balki "QAYSI OY
/// UCHUN" (forMonth) bo'yicha guruhlanadi. Sabab: o'quvchi sentabrda
/// avgust oyi to'lovini qilishi mumkin — bu holda admin statistikasida
/// bu to'lov AVGUST oyiga hisoblanishi kerak, sentabrga emas (aks holda
/// "avgust uchun kim to'lagan" savoliga noto'g'ri javob chiqadi).
class PaymentStatsService {
  PaymentStatsService._();

  static const String _docPath = 'stats';
  static const String _docId = 'payments';

  static String monthKeyFor(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}";

  /// Umumiy metod — QO'SHISH (musbat delta), O'CHIRISH (manfiy delta) va
  /// TAHRIRLASH (farq/delta) uchun BIR XIL ishlatiladi.
  /// [monthKey] endi to'g'ridan-to'g'ri "YYYY-MM" satr sifatida beriladi
  /// (odatda to'lov QAYSI OY UCHUN ekanligidan hisoblanadi).
  static void applyDelta(
      WriteBatch batch, {
        required double amountDelta,
        required int countDelta,
        required String source, // 'school' | 'tutoring'
        required String monthKey,
      }) {
    if (amountDelta == 0 && countDelta == 0) return;

    final docRef = FirebaseFirestore.instance.collection(_docPath).doc(_docId);

    batch.set(docRef, {
      'totalAmount': FieldValue.increment(amountDelta),
      'totalCount': FieldValue.increment(countDelta),
      'monthly': {
        monthKey: {
          'amount': FieldValue.increment(amountDelta),
          'count': FieldValue.increment(countDelta),
        },
      },
      'bySource': {
        source: {
          'amount': FieldValue.increment(amountDelta),
          'count': FieldValue.increment(countDelta),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>> fetchSummary() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_docPath).doc(_docId).get();
      return doc.data() ?? {};
    } catch (e) {
      debugPrint("To'lov statistikasini o'qishda xato: $e");
      return {};
    }
  }

  static Future<double> fetchCurrentMonthTotal() async {
    final data = await fetchSummary();
    final mKey = monthKeyFor(DateTime.now());
    final monthly = data['monthly'] as Map<String, dynamic>?;
    final thisMonth = monthly?[mKey] as Map<String, dynamic>?;
    return (thisMonth?['amount'] ?? 0).toDouble();
  }
}