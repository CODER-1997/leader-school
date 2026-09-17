import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'crm_controller.dart';

class SubjectStudentsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String subjectId;
  final String classId;

  final TextEditingController studentFirstNameController = TextEditingController();
  final TextEditingController studentLastNameController = TextEditingController();
  final TextEditingController studentPhoneController = TextEditingController();
  final TextEditingController parentPhoneController = TextEditingController();

  var isPrivileged = false.obs;
  var joinedDate = DateTime.now().obs;

  // Davomat holatlari: studentId -> bool (isPresent) — faqat LOCAL, saqlanmaguncha serverga bormaydi
  var attendanceMap = <String, bool>{}.obs;

  // Shu sinfga tegishli o'quvchilar — asosiy CrmController cache'idan olinadi, READ = 0
  var classStudents = <Map<String, dynamic>>[].obs;

  var isLoading = false.obs;
  var isSaving = false.obs;
  var hasUnsavedChanges = false.obs;

  // YANGI: hozir qaysi sananing davomati ko'rsatilmoqda/tahrirlanmoqda.
  // Avval bu ekran FAQAT "bugun" bilan ishlar edi.
  var selectedDate = DateTime.now().obs;

  String? _todayDocId; // MUHIM: nomi saqlanib qoldi, endi "tanlangan sana"ning hujjat ID'sini bildiradi

  SubjectStudentsController({required this.subjectId, required this.classId});

  @override
  void onInit() {
    super.onInit();
    _loadStudentsFromCache();   // 0 read
    _loadAttendanceForSelectedDate();
  }

  // ============================================================
  // 1. O'QUVCHILAR — allaqachon CrmController'da yuklangan cache'dan olamiz
  // ============================================================
  void _loadStudentsFromCache() {
    try {
      if (!Get.isRegistered<CrmController>()) {
        classStudents.value = [];
        return;
      }

      final crm = Get.find<CrmController>();

      if (crm.allStudents.isEmpty) {
        _fallbackFetchFromServer();
        return;
      }

      classStudents.value = crm.allStudents
          .where((s) => s['classId'] == classId)
          .toList();
    } catch (e) {
      debugPrint('O\'quvchilarni cache\'dan olishda xato: $e');
      classStudents.value = [];
    }
  }

  Future<void> _fallbackFetchFromServer() async {
    try {
      isLoading.value = true;
      var snapshot = await _db
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      classStudents.value = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      Get.snackbar(
        "Xatolik",
        "O'quvchilarni yuklab bo'lmadi. Internetni tekshiring.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      debugPrint('Fallback fetch xatosi: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // 2. DAVOMAT — endi TANLANGAN SANA uchun (avval faqat "bugun").
  // ============================================================
  String _dateKeyFor(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _loadAttendanceForSelectedDate() async {
    try {
      isLoading.value = true;
      final dateKey = _dateKeyFor(selectedDate.value);
      _todayDocId = '${subjectId}_$dateKey';

      final doc = await _db.collection('attendance').doc(_todayDocId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['records'] is Map) {
          final records = data['records'] as Map<String, dynamic>;
          attendanceMap.value = records.map(
                (key, value) => MapEntry(key, value == true),
          );
        } else {
          attendanceMap.clear();
        }
      } else {
        attendanceMap.clear();
      }
      // YANGI: yangi sana endigina yuklandi — hali hech qanday
      // tahrirlanmagan o'zgarish yo'q.
      hasUnsavedChanges.value = false;
    } catch (e) {
      Get.snackbar(
        "Xatolik",
        "Davomat ma'lumotini yuklab bo'lmadi",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      debugPrint('Davomat yuklash xatosi: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Checkbox bosilganda — FAQAT local state, serverga bormaydi (WRITE = 0)
  void toggleAttendance(String studentId, bool isPresent) {
    attendanceMap[studentId] = isPresent;
    hasUnsavedChanges.value = true;
  }

  // Faqat "Saqlash" chaqirilganda (endi avtomatik, tugma orqali emas) — bitta yagona write
  Future<void> saveAttendance() async {
    if (!hasUnsavedChanges.value) {
      return;
    }

    try {
      isSaving.value = true;
      final dateKey = _dateKeyFor(selectedDate.value);
      _todayDocId = '${subjectId}_$dateKey';

      await _db.collection('attendance').doc(_todayDocId).set({
        'subjectId': subjectId,
        'classId': classId,
        'date': dateKey,
        'records': attendanceMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      hasUnsavedChanges.value = false;

      Get.snackbar(
        "Muvaffaqiyatli",
        "Davomat saqlandi",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Xatolik",
        "Saqlashda muammo yuz berdi. Qayta urinib ko'ring.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      debugPrint('Davomat saqlash xatosi: $e');
    } finally {
      isSaving.value = false;
    }
  }

  // =======================================================================
  // YANGI: SANANI ALMASHTIRISH — joriy sanadagi saqlanmagan o'zgarishlar
  // BOR bo'lsa, AVVAL avtomatik saqlanadi, so'ng yangi sananing davomati
  // yuklanadi.
  // =======================================================================
  Future<void> changeDate(DateTime newDate) async {
    if (hasUnsavedChanges.value) {
      await saveAttendance();
    }
    selectedDate.value = DateTime(newDate.year, newDate.month, newDate.day);
    await _loadAttendanceForSelectedDate();
  }

  Future<void> goToPreviousDay() => changeDate(selectedDate.value.subtract(const Duration(days: 1)));

  /// Kelajakka o'tishga RUXSAT BERILMAYDI.
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

  // ============================================================
  // 3. O'QUVCHI QO'SHISH
  // ============================================================
  Future<void> pickJoinedDate(BuildContext context) async {
    try {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: joinedDate.value,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) joinedDate.value = picked;
    } catch (e) {
      debugPrint('Sana tanlashda xato: $e');
    }
  }

  Future<void> addStudent() async {
    final firstName = studentFirstNameController.text.trim();
    final lastName = studentLastNameController.text.trim();
    final phone = studentPhoneController.text.trim();
    final parentPhone = parentPhoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ism va familiyani kiriting!", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    Get.back();

    try {
      final docRef = await _db.collection('students').add({
        'classId': classId,
        'firstName': firstName,
        'lastName': lastName,
        'name': "$firstName $lastName",
        'phone': phone.isNotEmpty ? phone : "Kiritilmagan",
        'parentPhone': parentPhone.isNotEmpty ? parentPhone : "Kiritilmagan",
        'isPrivileged': isPrivileged.value,
        'joinedDate': Timestamp.fromDate(joinedDate.value),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final newStudent = {
        'id': docRef.id,
        'classId': classId,
        'firstName': firstName,
        'lastName': lastName,
        'name': "$firstName $lastName",
        'phone': phone.isNotEmpty ? phone : "Kiritilmagan",
        'parentPhone': parentPhone.isNotEmpty ? parentPhone : "Kiritilmagan",
        'isPrivileged': isPrivileged.value,
      };

      classStudents.add(newStudent);
      if (Get.isRegistered<CrmController>()) {
        Get.find<CrmController>().allStudents.add(newStudent);
      }

      studentFirstNameController.clear();
      studentLastNameController.clear();
      studentPhoneController.clear();
      parentPhoneController.clear();
      isPrivileged.value = false;
      joinedDate.value = DateTime.now();

      Get.snackbar("Muvaffaqiyatli", "$firstName qo'shildi!", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xato", "Xatolik yuz berdi. Qayta urinib ko'ring.", backgroundColor: Colors.red, colorText: Colors.white);
      debugPrint('O\'quvchi qo\'shish xatosi: $e');
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