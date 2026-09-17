import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// BOSQICH-2: bitta sinf/guruhning o'quvchilari — har biriga OXIRGI 30
/// KUNLIK davomat foizi va BUGUNGI holati (kelgan/kelmagan) biriktiriladi.
///
/// MUHIM: foiz faqat SHU sinf/guruh doirasida hisoblanadi (barcha vaqt,
/// barcha sinflar bo'yicha EMAS) — bu ham mazmunan to'g'riroq ("shu
/// darsga qancha kelib turibdi"), ham Firestore uchun ARZON (bir necha
/// o'nlab hujjat, cheksiz tarix emas).
class GroupAbsentDetailController extends GetxController {
  final String id; // classId (maktab) yoki groupId (markaz)
  final bool isSchool;

  GroupAbsentDetailController({required this.id, required this.isSchool});

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var students = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = RxnString();

  String get _todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _keyFor(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      // 1. Ro'yxat (roster).
      final rosterSnap = isSchool
          ? await _db.collection('students').where('classId', isEqualTo: id).get()
          : await _db.collection('students').where('centerGroupIds', arrayContains: id).get();

      final Map<String, Map<String, dynamic>> roster = {
        for (final doc in rosterSnap.docs) doc.id: {'id': doc.id, ...doc.data()},
      };

      // 2. Oxirgi 30 kunlik davomat tarixi.
      final cutoff = _keyFor(DateTime.now().subtract(const Duration(days: 30)));
      final attSnap = isSchool
          ? await _db.collection('attendance').where('classId', isEqualTo: id).where('date', isGreaterThanOrEqualTo: cutoff).get()
          : await _db.collection('attendance').where('subjectId', isEqualTo: id).where('date', isGreaterThanOrEqualTo: cutoff).get();

      final Map<String, int> presentCount = {};
      final Map<String, int> totalCount = {};
      final Set<String> absentToday = {};

      for (final doc in attSnap.docs) {
        final data = doc.data();
        final bool isToday = data['date'] == _todayKey;
        final records = Map<String, dynamic>.from(data['records'] ?? {});

        records.forEach((studentId, present) {
          totalCount[studentId] = (totalCount[studentId] ?? 0) + 1;
          if (present == true) {
            presentCount[studentId] = (presentCount[studentId] ?? 0) + 1;
          } else if (isToday) {
            absentToday.add(studentId);
          }
        });
      }

      final list = roster.values.map((s) {
        final sid = s['id'] as String;
        final total = totalCount[sid] ?? 0;
        final present = presentCount[sid] ?? 0;
        final percent = total > 0 ? (present / total * 100) : 100.0;
        return {
          ...s,
          'attendancePercent': percent,
          'attendanceSampleSize': total,
          'absentToday': absentToday.contains(sid),
        };
      }).toList();

      // Bugun kelmaganlar tepada, keyin foiz o'sish tartibida (eng past foiz birinchi).
      list.sort((a, b) {
        if (a['absentToday'] != b['absentToday']) {
          return (a['absentToday'] as bool) ? -1 : 1;
        }
        return (a['attendancePercent'] as double).compareTo(b['attendancePercent'] as double);
      });

      students.value = list;
    } catch (e) {
      debugPrint("Guruh tafsilotlarini yuklashda xato: $e");
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _load();
}