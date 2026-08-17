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

  String? _todayDocId;

  SubjectStudentsController({required this.subjectId, required this.classId});

  @override
  void onInit() {
    super.onInit();
    _loadStudentsFromCache();   // 0 read
    _loadTodayAttendanceOnce(); // 1 read (yoki 0, agar hali hujjat yo'q bo'lsa)
  }

  // ============================================================
  // 1. O'QUVCHILAR — allaqachon CrmController'da yuklangan cache'dan olamiz
  // ============================================================
  void _loadStudentsFromCache() {
    try {
      if (!Get.isRegistered<CrmController>()) {
        // Agar biror sabab bilan hali yaratilmagan bo'lsa, xato bermaymiz,
        // shunchaki bo'sh ro'yxat bilan boshlaymiz
        classStudents.value = [];
        return;
      }

      final crm = Get.find<CrmController>();

      if (crm.allStudents.isEmpty) {
        // Cache hali yuklanmagan bo'lishi mumkin (masalan ilova endi ochilgan)
        // Xavfsizlik uchun 1 martalik server so'rovi bilan zaxira variant
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

  // Faqat CrmController cache bo'sh bo'lgan holatlar uchun zaxira — bitta filtrlangan so'rov
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
  // 2. DAVOMAT — bugungi hujjatni FAQAT 1 marta o'qiymiz (real-time emas)
  // ============================================================
  Future<void> _loadTodayAttendanceOnce() async {
    try {
      isLoading.value = true;
      final today = DateTime.now().toIso8601String().split('T')[0];
      _todayDocId = '${subjectId}_$today';

      final doc = await _db.collection('attendance').doc(_todayDocId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['records'] is Map) {
          final records = data['records'] as Map<String, dynamic>;
          attendanceMap.value = records.map(
                (key, value) => MapEntry(key, value == true),
          );
        }
      } else {
        attendanceMap.clear();
      }
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

  // Faqat "Saqlash" tugmasi bosilganda — bitta yagona write
  Future<void> saveAttendance() async {
    if (!hasUnsavedChanges.value) {
      Get.snackbar("Diqqat", "Hech narsa o'zgarmagan", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    try {
      isSaving.value = true;
      final today = DateTime.now().toIso8601String().split('T')[0];
      _todayDocId = '${subjectId}_$today';

      await _db.collection('attendance').doc(_todayDocId).set({
        'subjectId': subjectId,
        'classId': classId,
        'date': today,
        'records': attendanceMap, // butun map bitta marta yoziladi
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

      // Yangi o'quvchini asosiy cache'ga ham qo'shamiz — qayta fetch qilmaslik uchun
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
// Test uchun demo o'quvchilar qo'shish funksiyasi
  Future<void> addDemoStudents() async {
    try {
      isLoading.value = true;

      // Test uchun ismlar va familiyalar ro'yxati
      List<Map<String, dynamic>> demoData = [
        {'firstName': 'Anvar', 'lastName': 'Aliyev', 'isPrivileged': true},
        {'firstName': 'Jasur', 'lastName': 'Karimov', 'isPrivileged': false},
        {'firstName': 'Madina', 'lastName': 'Saidova', 'isPrivileged': true},
        {'firstName': 'Bobur', 'lastName': 'Tohirov', 'isPrivileged': false},
        {'firstName': 'Zuxra', 'lastName': 'Valiyeva', 'isPrivileged': false},
        {'firstName': 'Sardor', 'lastName': 'Nazarov', 'isPrivileged': true},
        {'firstName': 'Dilnoza', 'lastName': 'Ergasheva', 'isPrivileged': false},
        {'firstName': 'Shohruh', 'lastName': 'Rustamov', 'isPrivileged': false},
        {'firstName': 'Malika', 'lastName': 'Yusupova', 'isPrivileged': true},
        {'firstName': 'Otabek', 'lastName': 'Hakimov', 'isPrivileged': false},
      ];

      for (var item in demoData) {
        final firstName = item['firstName'];
        final lastName = item['lastName'];
        final isPriv = item['isPrivileged'];

        final docRef = await _db.collection('students').add({
          'classId': classId,
          'firstName': firstName,
          'lastName': lastName,
          'name': "$firstName $lastName",
          'phone': "+998 (90) 123-45-67",
          'parentPhone': "+998 (91) 987-65-43",
          'isPrivileged': isPriv,
          'joinedDate': Timestamp.fromDate(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final newStudent = {
          'id': docRef.id,
          'classId': classId,
          'firstName': firstName,
          'lastName': lastName,
          'name': "$firstName $lastName",
          'phone': "+998 (90) 123-45-67",
          'parentPhone': "+998 (91) 987-65-43",
          'isPrivileged': isPriv,
        };

        classStudents.add(newStudent);
      }

      isLoading.value = false;
      Get.snackbar(
          "Muvaffaqiyatli",
          "10 ta demo o'quvchi qo'shildi!",
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white
      );
    } catch (e) {
      isLoading.value = false;
      debugPrint("Demo o'quvchi qo'shish xatosi: $e");
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