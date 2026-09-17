import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Arxivlangan (o'chirilgan) o'quvchilar bo'yicha statistika + ro'yxat.
/// 'students' collection'idan 'isArchived == true' bo'lganlarni oladi —
/// bitta oddiy tenglik so'rovi, index talab qilmaydi.
class AdminArchivedStudentsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = true.obs;
  var archivedStudents = <Map<String, dynamic>>[].obs;
  var countsByReason = <String, int>{}.obs;
  var errorMessage = RxnString();

  int get totalArchived => archivedStudents.length;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final snap = await _db.collection('students').where('isArchived', isEqualTo: true).get();

      final list = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'name': data['name'] ?? '',
          'archivedReason': data['archivedReason'] ?? 'unknown',
          'archivedAt': (data['archivedAt'] as Timestamp?)?.toDate(),
        };
      }).toList();

      // Eng yangi arxivlanganlar tepada.
      list.sort((a, b) {
        final da = a['archivedAt'] as DateTime?;
        final dbb = b['archivedAt'] as DateTime?;
        if (da == null || dbb == null) return 0;
        return dbb.compareTo(da);
      });

      final Map<String, int> counts = {};
      for (final s in list) {
        final reason = s['archivedReason'] as String;
        counts[reason] = (counts[reason] ?? 0) + 1;
      }

      archivedStudents.value = list;
      countsByReason.value = counts;
    } catch (e) {
      debugPrint("Arxivni yuklashda xato: $e");
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _load();
}