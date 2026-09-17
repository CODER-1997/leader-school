import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../services/access_code_service.dart';
import '../../services/teacher_login_service.dart';


class HomeViewController extends GetxController {
  final _box = GetStorage();
  final TextEditingController roleIdController = TextEditingController();
  final RxString userRole = "".obs; // "admin", "teacher", yoki ""
  final RxBool isObscured = true.obs;
  final RxBool isChecking = false.obs;  

  @override
  void onInit() {
    super.onInit();
    userRole.value = _box.read('userRole') ?? "";
  }

  @override
  void onClose() {
    roleIdController.dispose();
    super.onClose();
  }

  /// Kiritilgan kodni tekshiradi va GetStorage'ga saqlaydi.
  ///
  /// IKKI BOSQICHLI TEKSHIRUV:
  /// 1. Avval Admin kodi bilan solishtiriladi (Sozlamalar > Xavfsizlikdan
  ///    o'rnatilgan) — mos kelsa "admin" roli beriladi.
  /// 2. Aks holda, kod O'QITUVCHINING SHAXSIY TELEFON RAQAMI sifatida
  ///    tekshiriladi ('teachers' collection'ida ro'yxatdan o'tganmi).
  ///    Mos kelsa "teacher" roli beriladi VA shu aniq o'qituvchining
  ///    kirish tarixi/faolligi Firestore'da yangilanadi.
  ///
  /// MUHIM O'ZGARISH: avval har qanday "admin" bo'lmagan kod "teacher"
  /// sifatida qabul qilinardi (kim ekanini bilmasdan). Endi FAQAT
  /// ro'yxatdan o'tgan (Admin -> O'qituvchilar bo'limida qo'shilgan)
  /// telefon raqami bilan kirish mumkin — shunda tizim aniq KIM
  /// kirganini biladi va faollikni kuzatadi.
  Future<bool> checkAccessCode() async {
    final String code = roleIdController.text.trim();

    if (code.isEmpty) {
      Get.snackbar("Xatolik", "ID raqamni kiriting!", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }

    isChecking.value = true;

    final bool isAdmin = await AccessCodeService.verifyAdminCode(code);
    if (isAdmin) {
      isChecking.value = false;
      userRole.value = "admin";
      _box.write('userRole', 'admin');
      _box.remove('teacherId');
      Get.snackbar("Muvaffaqiyatli", "Admin huquqi berildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      roleIdController.clear();
      return true;
    }

    final result = await TeacherLoginService.attemptLogin(code);
    isChecking.value = false;

    switch (result.status) {
      case TeacherLoginStatus.success:
        userRole.value = "teacher";
        _box.write('userRole', 'teacher');
        _box.write('teacherId', result.teacherId);
        Get.snackbar("Muvaffaqiyatli", "Ustoz sifatida kirildi", backgroundColor: const Color(0xFF3B82F6), colorText: Colors.white);
        roleIdController.clear();
        return true;

      case TeacherLoginStatus.inactive:
        Get.snackbar("Ruxsat yo'q", "Hisobingiz faol emas. Administratorga murojaat qiling.",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;

      case TeacherLoginStatus.notFound:
        Get.snackbar("Xatolik", "Bunday kod yoki telefon raqami topilmadi",
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
    }
  }

  void logout() {
    userRole.value = "";
    _box.remove('userRole');
    _box.remove('teacherId');
    Get.snackbar("Chiqildi", "Tizimdan muvaffaqiyatli chiqildi", backgroundColor: const Color(0xFF64748B), colorText: Colors.white);
  }
}