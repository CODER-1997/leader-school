import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/admin_controller/admin_settings_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
import '../../services/sms_service.dart'; // MUHIM: shu ham

/// O'QUV MARKAZ uchun Davomat SMS + TANLASH holati — BIR joyda.
/// Uzoq bosish -> tanlash rejimi yoqiladi (raqamli doira ✓ belgiga
/// aylanadi), keyin xohlagan o'quvchilarni qo'shib/olib tashlash mumkin.
/// "Hammasini tanlash" va "Kelmaganlarni tanlash" tezkor tugmalari ham
/// shu tanlovni to'ldiradi — qo'lda tanlash bilan ARALASHTIRIB
/// ishlatsa ham bo'ladi.
class CenterSmsService extends GetxController {
  var selectionMode = false.obs;
  var selectedIds = <String>{}.obs;
  var isSending = false.obs;


  void enterSelectionMode(String firstId) {
    selectionMode.value = true;
    selectedIds.add(firstId);
  }

  void toggle(String studentId) {
    if (selectedIds.contains(studentId)) {
      selectedIds.remove(studentId);
    } else {
      selectedIds.add(studentId);
    }
    if (selectedIds.isEmpty) selectionMode.value = false;
  }

  /// Tezkor: BARCHA o'quvchilarni tanlaydi (qo'shimcha, mavjud tanlovga
  /// QO'SHILADI — almashtirmaydi).
  void selectAll(List<String> allIds) {
    selectedIds.addAll(allIds);
    selectionMode.value = true;
  }

  /// YANGI, tezkor: faqat BUGUN KELMAGANLARNI tanlaydi.
  void selectAbsent(List<String> absentIds) {
    selectedIds.addAll(absentIds);
    selectionMode.value = true;
  }

  void cancel() {
    selectionMode.value = false;
    selectedIds.clear();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _fullName(Map<String, dynamic> s) {
    final last = _capitalize(s['lastName'] ?? '');
    final first = _capitalize(s['firstName'] ?? '');
    return (last.isNotEmpty && first.isNotEmpty) ? "$last $first" : _capitalize(s['name'] ?? 'Nomsiz');
  }

  // YANGI: endi Maktabning 'attendance'/'attendancePresent' maydonlarini
  // EMAS, balki alohida 'centerAttendance'/'centerAttendancePresent'
  // maydonlarini o'qiydi — chunki bir xil matnning ikkalasiga ham
  // ketishi mantiqsiz edi (Markazga "guruh"ga oid matn kerak).
  Future<Map<String, String>> _fetchBothAttendanceTemplates() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      final data = doc.data() ?? {};
      return {
        'absent': data['centerAttendance'] ?? AdminSettingsController.defaultCenterAttendanceTemplate,
        'present': data['centerAttendancePresent'] ?? AdminSettingsController.defaultCenterAttendancePresentTemplate,
      };
    } catch (e) {
      return {
        'absent': AdminSettingsController.defaultCenterAttendanceTemplate,
        'present': AdminSettingsController.defaultCenterAttendancePresentTemplate,
      };
    }
  }

  List<Map<String, dynamic>> _resolveSelected(List<Map<String, dynamic>> allStudents) {
    return allStudents.where((s) => selectedIds.contains(s['id'])).toList();
  }

  /// HAR BIR o'quvchining O'Z holatiga (kelgan/kelmagan) qarab TO'G'RI
  /// shablon tanlanadi — shu bilan "Hammaga" tanlansa ham, kelganga
  /// "kelmadi" deb noto'g'ri xabar ketmaydi. Hali davomat BELGILANMAGAN
  /// (null) o'quvchilar — o'tkazib yuboriladi (na "keldi", na "kelmadi"
  /// deyish noto'g'ri bo'lardi).
  Future<void> sendAttendanceSms({
    required List<Map<String, dynamic>> allStudents,
    required Map<String, bool?> attendanceMap, // YANGI
    required String groupName,
  }) async {
    final recipients = _resolveSelected(allStudents);
    if (recipients.isEmpty || isSending.value) return;
    isSending.value = true;

    final templates = await _fetchBothAttendanceTemplates();
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final smsService = SMSService();

    int successCount = 0;
    int failCount = 0;
    int skippedCount = 0;

    for (final student in recipients) {
      final studentId = student['id'];
      final bool? isPresent = attendanceMap[studentId];

      if (isPresent == null) {
        skippedCount++;
        continue; // hali belgilanmagan — o'tkazib yuboramiz
      }

      final fullName = _fullName(student);
      final template = isPresent ? templates['present']! : templates['absent']!;
      final message = template
          .replaceAll('{ism}', fullName)
          .replaceAll('{guruh}', groupName)
          .replaceAll('{sana}', today);

      // TEST REJIMI — real ishga tushirishda
      // (student['parentPhone'] ?? '').toString() ga almashtiring.
      final parentPhone = (student['parentPhone'] ?? '').toString().trim();
      final recipient = parentPhone.isNotEmpty ? parentPhone : (student['phone'] ?? '').toString().trim();
      try {
        await smsService.sendSMS(recipient, message);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint("SMS yuborishda xato ($fullName): $e");
      }
    }

    _finish(successCount, failCount, skippedCount: skippedCount);
  }

  /// Shaxsiy (erkin) matnli SMS — {ism} joy-belgisi qo'llab-quvvatlanadi.
  Future<void> sendCustomSms({
    required List<Map<String, dynamic>> allStudents,
    required String customText,
  }) async {
    final recipients = _resolveSelected(allStudents);
    if (recipients.isEmpty || isSending.value || customText.trim().isEmpty) return;
    isSending.value = true;

    final smsService = SMSService();
    int successCount = 0;
    int failCount = 0;

    for (final student in recipients) {
      final fullName = _fullName(student);
      final message = customText.replaceAll('{ism}', fullName);

      final parentPhone = (student['parentPhone'] ?? '').toString().trim();
      final recipient = parentPhone.isNotEmpty ? parentPhone : (student['phone'] ?? '').toString().trim();
      try {
        await smsService.sendSMS(recipient, message);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint("Shaxsiy SMS yuborishda xato ($fullName): $e");
      }
    }

    _finish(successCount, failCount);
  }

  void _finish(int successCount, int failCount, {int skippedCount = 0}) {
    isSending.value = false;
    selectionMode.value = false;
    selectedIds.clear();

    final parts = <String>[];
    if (successCount > 0) parts.add("$successCount ta yuborildi");
    if (failCount > 0) parts.add("$failCount ta xato");
    if (skippedCount > 0) parts.add("$skippedCount ta o'tkazib yuborildi (davomat belgilanmagan)");

    Get.snackbar(
      failCount == 0 ? "Yuborildi" : "Qisman yuborildi",
      parts.isEmpty ? "Hech kimga yuborilmadi" : parts.join(", "),
      backgroundColor: failCount == 0 ? const Color(0xFF10B981) : Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  }
}