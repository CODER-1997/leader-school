import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class StudentProfileController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String studentId;
  final String subjectId;

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController phoneController;
  late TextEditingController parentPhoneController;

  var isPrivileged = false.obs;
  var isLoading = true.obs;
  var subjectName = "".obs;

  // Kalendar uchun: "YYYY-MM-DD" -> true/false
  var attendanceHistory = <String, bool>{}.obs;

  StudentProfileController({required this.studentId, required this.subjectId});

  /// YANGI: avval bu controller faqat onInit()da BIR MARTA ma'lumot
  /// olardi, uni qayta yuklaydigan hech qanday yo'l yo'q edi — shuning
  /// uchun "Ma'lumotlar" va "Davomat" ekranlari, server tomonda
  /// o'zgargan bo'lsa ham, HECH QACHON yangilanmasdi. Endi bu public
  /// metod orqali "Yangilash" tugmasi istalgan vaqtda qayta so'rov
  /// yuborishi mumkin.
  Future<void> refresh() => fetchStudentProfileData();

  @override
  void onInit() {
    super.onInit();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    phoneController = TextEditingController();
    parentPhoneController = TextEditingController();
    fetchStudentProfileData();
  }

  Future<void> fetchStudentProfileData() async {
    try {
      isLoading.value = true;

      // 1. O'quvchi ma'lumotlarini olish
      var studentDoc = await _db.collection('students').doc(studentId).get();
      if (studentDoc.exists) {
        var data = studentDoc.data()!;
        firstNameController.text = data['firstName'] ?? '';
        lastNameController.text = data['lastName'] ?? '';
        phoneController.text = data['phone'] ?? '';
        parentPhoneController.text = data['parentPhone'] ?? '';
        isPrivileged.value = data['isPrivileged'] ?? false;
      }

      // 2. Fan nomini olish
      var subjectDoc = await _db.collection('subjects').doc(subjectId).get();
      if (subjectDoc.exists) {
        subjectName.value = subjectDoc.data()?['name'] ?? '';
      }

      // 3. Shu fanga tegishli barcha kunlik davomat hujjatlarini olish (Yangi arxitektura bo'yicha)
      var attendanceQuery = await _db.collection('attendance')
          .where('subjectId', isEqualTo: subjectId)
          .get();

      Map<String, bool> history = {};
      for (var doc in attendanceQuery.docs) {
        var data = doc.data();
        String dateStr = data['date']; // "YYYY-MM-DD" formatida

        if (data['records'] is Map) {
          var records = data['records'] as Map<String, dynamic>;
          // Agar shu kunlik records ichida bizning o'quvchimiz bo'lsa
          if (records.containsKey(studentId)) {
            history[dateStr] = records[studentId] == true;
          }
        }
      }
      attendanceHistory.value = history;

    } catch (e) {
      debugPrint("Ma'lumotlarni yuklashda xato: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateStudentProfile() async {
    String firstName = firstNameController.text.trim();
    String lastName = lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ism va familiyani kiriting!", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    try {
      await _db.collection('students').doc(studentId).update({
        'firstName': firstName,
        'lastName': lastName,
        'name': "$firstName $lastName",
        'phone': phoneController.text.trim(),
        'parentPhone': parentPhoneController.text.trim(),
        'isPrivileged': isPrivileged.value,
      });

      Get.snackbar("Muvaffaqiyatli", "O'quvchi ma'lumotlari yangilandi!", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xato", "Xatolik yuz berdi: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    parentPhoneController.dispose();
    super.onClose();
  }
}