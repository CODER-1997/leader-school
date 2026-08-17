import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ADMIN STATISTIKASI UCHUN DENORMALIZED HUJJAT.
///
/// Har bir to'lov QO'SHILGANDA/TAHRIRLANGANDA/O'CHIRILGANDA, 'stats/payments'
/// hujjati FieldValue.increment() bilan yangilanadi (musbat yoki manfiy
/// qiymat bilan — Firestore increment manfiy sonlarni ham qo'llab-quvvatlaydi,
/// shuning uchun DELETE/EDIT uchun ham xuddi shu mexanizm ishlatiladi).
///
/// Natijada admin statistika ekrani DOIM faqat 1 ta hujjat o'qiydi.
class PaymentStatsService {
  PaymentStatsService._();

  static const String _docPath = 'stats';
  static const String _docId = 'payments';

  static String monthKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}";

  /// Umumiy metod — QO'SHISH (musbat delta), O'CHIRISH (manfiy delta) va
  /// TAHRIRLASH (farq/delta) uchun BIR XIL ishlatiladi.
  static void applyDelta(
      WriteBatch batch, {
        required double amountDelta,
        required int countDelta,
        required String source, // 'school' | 'tutoring'
        required DateTime date,
      }) {
    if (amountDelta == 0 && countDelta == 0) return; // hech narsa o'zgarmagan

    final docRef = FirebaseFirestore.instance.collection(_docPath).doc(_docId);
    final mKey = monthKey(date);

    batch.set(docRef, {
      'totalAmount': FieldValue.increment(amountDelta),
      'totalCount': FieldValue.increment(countDelta),
      'monthly': {
        mKey: {
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
    final mKey = monthKey(DateTime.now());
    final monthly = data['monthly'] as Map<String, dynamic>?;
    final thisMonth = monthly?[mKey] as Map<String, dynamic>?;
    return (thisMonth?['amount'] ?? 0).toDouble();
  }
}