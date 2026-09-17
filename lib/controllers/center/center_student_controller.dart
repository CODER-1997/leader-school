import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Bitta GURUHNING o'quvchilar ro'yxati, davomati va o'quvchi qo'shish
/// oqimini boshqaradi.
///
/// MUHIM ARXITEKTURA: 'students' — Maktab bilan BAHAM KO'RILADIGAN yagona
/// collection (yangi collection YARATILMAYDI). Har bir o'quvchiga
/// 'centerGroupIds' (massiv) maydoni qo'shiladi — shu orqali "kim qaysi
/// guruh(lar)ga tegishli" biriktiriladi.
///
/// 'centerSubjectJoinDates' (xarita: {subjectId: Timestamp}) —
/// o'quvchi HAR BIR FANGA aynan QACHON qo'shilganini saqlaydi.
///
/// Davomat 'attendance' collection'ida — Maktab BILAN BIR XIL tuzilishda
/// ('subjectId', 'date', 'records'), faqat 'subjectId' o'rniga GURUH ID'si
/// yoziladi.
///
/// YANGI: Davomat endi faqat BUGUNGI kun bilan CHEKLANMAGAN — 'selectedDate'
/// orqali ISTALGAN o'tgan sanaga o'tib, o'sha kunning davomatini ko'rish/
/// tahrirlash mumkin. Sana almashtirilganda, joriy sanadagi SAQLANMAGAN
/// o'zgarishlar AVTOMATIK saqlanadi — hech narsa yo'qolib ketmaydi.
class GroupStudentsController extends GetxController {
  final String groupId;
  final String subjectId; // bu guruh qaysi FANGA tegishli

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  GroupStudentsController({required this.groupId, required this.subjectId});

  var classStudents = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var isSaving = false.obs;

  // YANGI: hozir qaysi sananing davomati ko'rsatilmoqda/tahrirlanmoqda.
  var selectedDate = DateTime.now().obs;

  // Tanlangan sanadagi davomat: studentId -> true/false (null = hali belgilanmagan)
  var attendanceMap = <String, bool?>{}.obs;
  Map<String, bool> _originalAttendance = {};
  String? _todayDocId; // MUHIM: nomi saqlanib qoldi, lekin endi "tanlangan sana"ning hujjat ID'sini bildiradi

  bool get hasUnsavedChanges {
    for (final entry in attendanceMap.entries) {
      final orig = _originalAttendance[entry.key];
      if (entry.value != orig) return true;
    }
    return false;
  }

  // --- Yangi o'quvchi formasi uchun ---
  final TextEditingController studentFirstNameController = TextEditingController();
  final TextEditingController studentLastNameController = TextEditingController();
  final TextEditingController studentPhoneController = TextEditingController();
  final TextEditingController parentPhoneController = TextEditingController();
  var isPrivileged = false.obs;
  var joinedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    _loadStudents();
    _loadAttendanceForSelectedDate();
  }

  Future<void> _loadStudents() async {
    isLoading.value = true;
    try {
      final snap = await _db.collection('students').where('centerGroupIds', arrayContains: groupId).get();
      classStudents.value = snap.docs.map((doc) {
        final data = doc.data();
        final joinDates = Map<String, dynamic>.from(data['centerSubjectJoinDates'] ?? {});
        final subjectJoinedTs = joinDates[subjectId] as Timestamp?;
        return {
          'id': doc.id,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'name': data['name'] ?? '',
          'phone': data['phone'] ?? '',
          'parentPhone': data['parentPhone'] ?? '',
          'isPrivileged': data['isPrivileged'] ?? false,
          'classId': data['classId'],
          'subjectJoinedAtMs': subjectJoinedTs?.millisecondsSinceEpoch,
        };
      }).toList();
    } catch (e) {
      debugPrint("Guruh o'quvchilarini yuklashda xato: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _loadStudents();

  // YANGI: berilgan sanani "YYYY-MM-DD" kalitiga aylantiradi.
  String _dateKeyFor(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // MUHIM: nomi saqlanib qoldi (kodning boshqa joylarida ishlatilgan
  // bo'lishi mumkin), lekin endi "bugun" emas, "TANLANGAN SANA"ni
  // bildiradi.
  String get _todayKey => _dateKeyFor(selectedDate.value);

  Future<void> _loadAttendanceForSelectedDate() async {
    try {
      final snap = await _db
          .collection('attendance')
          .where('subjectId', isEqualTo: groupId)
          .where('date', isEqualTo: _todayKey)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        _todayDocId = doc.id;
        final records = Map<String, dynamic>.from(doc.data()['records'] ?? {});
        final Map<String, bool> parsed = {};
        records.forEach((k, v) => parsed[k] = v == true);
        _originalAttendance = parsed;
        attendanceMap.value = Map<String, bool?>.from(parsed);
      } else {
        _todayDocId = null;
        _originalAttendance = {};
        attendanceMap.value = {};
      }
    } catch (e) {
      debugPrint("Davomatni yuklashda xato: $e");
    }
  }

  void toggleAttendance(String studentId, bool present) {
    attendanceMap[studentId] = present;
    attendanceMap.refresh();
  }

  Future<void> saveAttendance() async {
    if (!hasUnsavedChanges) return;
    isSaving.value = true;
    try {
      final Map<String, dynamic> records = {};
      attendanceMap.forEach((k, v) {
        if (v != null) records[k] = v;
      });

      if (_todayDocId != null) {
        await _db.collection('attendance').doc(_todayDocId).update({
          'records': records,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final docRef = await _db.collection('attendance').add({
          'subjectId': groupId,
          'date': _todayKey,
          'records': records,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _todayDocId = docRef.id;
      }

      _originalAttendance = Map<String, bool>.from(records.map((k, v) => MapEntry(k, v == true)));

      Get.snackbar("Saqlandi", "Davomat saqlandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Saqlashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSaving.value = false;
    }
  }

  // =======================================================================
  // YANGI: SANANI ALMASHTIRISH — joriy sanadagi saqlanmagan o'zgarishlar
  // BOR bo'lsa, AVVAL avtomatik saqlanadi (hech narsa yo'qolmasin), so'ng
  // yangi sananing davomati yuklanadi.
  // =======================================================================
  Future<void> changeDate(DateTime newDate) async {
    if (hasUnsavedChanges) {
      await saveAttendance();
    }
    selectedDate.value = DateTime(newDate.year, newDate.month, newDate.day);
    _todayDocId = null;
    _originalAttendance = {};
    attendanceMap.value = {};
    await _loadAttendanceForSelectedDate();
  }

  Future<void> goToPreviousDay() => changeDate(selectedDate.value.subtract(const Duration(days: 1)));

  /// Kelajakka o'tishga RUXSAT BERILMAYDI — bugungi kundan keyingi
  /// sanaga o'tib bo'lmaydi.
  Future<void> goToNextDay() async {
    final nextDay = selectedDate.value.add(const Duration(days: 1));
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    if (nextDay.isAfter(todayDateOnly)) return;
    await changeDate(nextDay);
  }

  bool get isViewingToday {
    final today = DateTime.now();
    final d = selectedDate.value;
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }

  // =======================================================================
  // QIDIRISH — mavjud o'quvchini ism/familiya bo'yicha topish.
  // =======================================================================
  Future<List<Map<String, dynamic>>> searchExistingStudents(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final byLast = await _db
          .collection('students')
          .where('lastName', isGreaterThanOrEqualTo: q)
          .where('lastName', isLessThan: '$q\uf8ff')
          .limit(10)
          .get();

      final byFirst = await _db
          .collection('students')
          .where('firstName', isGreaterThanOrEqualTo: q)
          .where('firstName', isLessThan: '$q\uf8ff')
          .limit(10)
          .get();

      final Map<String, Map<String, dynamic>> merged = {};
      for (final doc in [...byLast.docs, ...byFirst.docs]) {
        final data = doc.data();
        final groupIds = List<dynamic>.from(data['centerGroupIds'] ?? []);
        merged[doc.id] = {
          'id': doc.id,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'phone': data['phone'] ?? '',
          'parentPhone': data['parentPhone'] ?? '',
          'alreadyInThisGroup': groupIds.contains(groupId),
        };
      }
      return merged.values.toList();
    } catch (e) {
      debugPrint("Qidirishda xato: $e");
      return [];
    }
  }

  Future<bool> linkExistingStudent(String studentId) async {
    try {
      final docRef = _db.collection('students').doc(studentId);
      final doc = await docRef.get();
      final data = doc.data() ?? {};
      final joinDates = Map<String, dynamic>.from(data['centerSubjectJoinDates'] ?? {});
      final bool alreadyHasSubjectDate = joinDates.containsKey(subjectId);

      final Map<String, dynamic> updateData = {
        'centerGroupIds': FieldValue.arrayUnion([groupId]),
      };
      if (!alreadyHasSubjectDate) {
        updateData['centerSubjectJoinDates.$subjectId'] = Timestamp.fromDate(DateTime.now());
      }

      await docRef.update(updateData);
      await _loadStudents();
      Get.snackbar("Qo'shildi", "O'quvchi guruhga biriktirildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "Biriktirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<bool> addNewStudent() async {
    final firstName = studentFirstNameController.text.trim();
    final lastName = studentLastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ism va familiyani kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    try {
      await _db.collection('students').add({
        'firstName': firstName,
        'lastName': lastName,
        'name': "$firstName $lastName",
        'phone': studentPhoneController.text.trim(),
        'parentPhone': parentPhoneController.text.trim(),
        'isPrivileged': isPrivileged.value,
        'centerGroupIds': [groupId],
        'centerSubjectJoinDates': {subjectId: Timestamp.fromDate(joinedDate.value)},
        'joinedDate': Timestamp.fromDate(joinedDate.value),
        'createdAt': FieldValue.serverTimestamp(),
      });

      studentFirstNameController.clear();
      studentLastNameController.clear();
      studentPhoneController.clear();
      parentPhoneController.clear();
      isPrivileged.value = false;

      await _loadStudents();
      Get.snackbar("Muvaffaqiyatli", "Yangi o'quvchi qo'shildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar("Xatolik", "Qo'shishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<void> pickJoinedDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: joinedDate.value,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) joinedDate.value = picked;
  }

  Future<void> removeStudentFromGroup(String studentId) async {
    try {
      await _db.collection('students').doc(studentId).update({
        'centerGroupIds': FieldValue.arrayRemove([groupId]),
      });
      classStudents.removeWhere((s) => s['id'] == studentId);
      Get.snackbar("Olib tashlandi", "O'quvchi guruhdan chiqarildi", backgroundColor: const Color(0xFF64748B), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  void onClose() {
    studentFirstNameController.dispose();
    studentLastNameController.dispose();
    studentPhoneController.dispose();
    parentPhoneController.dispose();
    super.onClose();
  }
}