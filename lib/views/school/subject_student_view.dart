import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:leader_school/views/school/school_exams.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:leader_school/views/school/student_profil/student_profil.dart';
import '../../controllers/crm_controller.dart';
import '../../controllers/subject_student_controller.dart';
import '../../controllers/school/exam_controller.dart';
import '../../controllers/admin_controller/admin_settings_controller.dart';
import '../../services/sms_service.dart'; // MUHIM: agar sizda boshqa yo'lda bo'lsa, shu qatorni to'g'irlang

// YANGI (XATO TUZATILDI): "Yangi o'quvchi" endi ALOHIDA SCREEN sifatida
// ochiladi — quyidagi _showAddStudentBottomSheet shu ekranni chaqiradi.
// MUHIM: agar add_subject_student_screen.dart faylini boshqa papkaga
// qo'ysangiz, shu import yo'lini moslang.

import '../../widgets/add_new_student_to_school.dart';

String _capitalizeName(String text) {
  if (text.isEmpty) return '';
  return text.trim().split(' ').map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

String _studentFullName(Map<String, dynamic> student) {
  final lastName = _capitalizeName(student['lastName'] ?? '');
  final firstName = _capitalizeName(student['firstName'] ?? '');
  return lastName.isNotEmpty && firstName.isNotEmpty
      ? "$lastName $firstName"
      : _capitalizeName(student['name'] ?? 'Nomaʼlum');
}

// =========================================================================
// YANGI: Davomat tabidagi "tanlash rejimi" holati — AppBar (parent) va
// o'quvchilar ro'yxati (bola widget) o'rtasida BAHAM KO'RILADI.
// =========================================================================
class AttendanceSelectionController extends GetxController {
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

  void selectAll(List<String> allIds) {
    selectedIds.addAll(allIds);
    selectionMode.value = true;
  }

  void selectAbsent(List<String> absentIds) {
    selectedIds.addAll(absentIds);
    selectionMode.value = true;
  }

  void cancel() {
    selectionMode.value = false;
    selectedIds.clear();
  }

  Future<Map<String, String>> _fetchBothAttendanceTemplates() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      final data = doc.data() ?? {};
      return {
        'absent': data['attendance'] ?? AdminSettingsController.defaultAttendanceTemplate,
        'present': data['attendancePresent'] ?? AdminSettingsController.defaultAttendancePresentTemplate,
      };
    } catch (e) {
      return {
        'absent': AdminSettingsController.defaultAttendanceTemplate,
        'present': AdminSettingsController.defaultAttendancePresentTemplate,
      };
    }
  }

  List<Map<String, dynamic>> _resolveSelected(List<Map<String, dynamic>> allStudents) {
    return allStudents.where((s) => selectedIds.contains(s['id'])).toList();
  }

  Future<void> sendAttendanceSms({
    required List<Map<String, dynamic>> allStudents,
    required Map<String, bool?> attendanceMap,
    required String subjectName,
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
        continue;
      }

      final fullName = _studentFullName(student);
      final template = isPresent ? templates['present']! : templates['absent']!;
      final message = template
          .replaceAll('{ism}', fullName)
          .replaceAll('{sinf}', subjectName)
          .replaceAll('{sana}', today);

      final recipient = (student['parentPhone'] ?? '').toString();

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
      final fullName = _studentFullName(student);
      final message = customText.replaceAll('{ism}', fullName);
      final recipient = (student['parentPhone'] ?? '').toString();

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

// =========================================================================
// SOF VIZUAL — o'zgarishsiz.
// =========================================================================
class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  const _SelectionIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? const Color(0xFF10B981) : Colors.white,
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          width: 2,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: AnimatedScale(
        scale: isSelected ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}

class SubjectStudentsView extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String classId;

  const SubjectStudentsView({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
  });

  @override
  State<SubjectStudentsView> createState() => _SubjectStudentsViewState();
}

class _SubjectStudentsViewState extends State<SubjectStudentsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  late SubjectStudentsController _subjectController;
  late ExamController _examController;
  late AttendanceSelectionController _selectionController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    _subjectController = Get.put(
      SubjectStudentsController(subjectId: widget.subjectId, classId: widget.classId),
      tag: widget.subjectId,
    );

    if (Get.isRegistered<ExamController>(tag: widget.classId)) {
      _examController = Get.find<ExamController>(tag: widget.classId);
    } else {
      _examController = Get.put(ExamController(classId: widget.classId), tag: widget.classId);
    }
    _examController.addRef();

    _selectionController = Get.put(AttendanceSelectionController(), tag: widget.subjectId);
  }

  @override
  void dispose() {
    _tabController.dispose();

    Get.delete<SubjectStudentsController>(tag: widget.subjectId);
    if (_examController.releaseRef()) {
      Get.delete<ExamController>(tag: widget.classId);
    }
    Get.delete<AttendanceSelectionController>(tag: widget.subjectId);

    super.dispose();
  }

  // =======================================================================
  // YANGI: orqaga chiqishdan OLDIN — saqlanmagan davomat o'zgarishlari
  // bo'lsa, AVTOMATIK saqlaydi. AppBar orqaga tugmasi VA qurilma tizim
  // orqaga tugmasi/harakati uchun BIR XIL ishlatiladi.
  // =======================================================================
  Future<void> _saveIfNeededAndPop() async {
    if (_subjectController.hasUnsavedChanges.value) {
      await _subjectController.saveAttendance();
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  // YANGI (XATO TUZATILDI): bu getter avval YO'Q edi — "Kelmaganlarni
  // tanlash" tugmasi va audience tanlash varag'i shuni chaqirar edi,
  // lekin ta'rif yo'qligi sabab "getter isn't defined" xatosi berardi.
  // Joriy ko'rilayotgan sana (_subjectController.selectedDate) bo'yicha
  // "Yo'q" deb belgilangan o'quvchilar ro'yxatini qaytaradi.
  List<String> get _absentStudentIds {
    return _subjectController.classStudents
        .where((s) => _subjectController.attendanceMap[s['id']] == false)
        .map<String>((s) => s['id'] as String)
        .toList();
  }

  // YANGI (XATO TUZATILDI): bu metod avval YO'Q edi — pastdagi FAB
  // (`onPressed: _showAddStudentBottomSheet`) shuni chaqirar edi, lekin
  // ta'rif yo'qligi sabab "method isn't defined" xatosi berardi. Endi
  // "Yangi o'quvchi" ALOHIDA SCREEN (AddSubjectStudentScreen) sifatida
  // ochiladi — bottom sheet emas.
  void _showAddStudentBottomSheet() {
    Get.to(() => AddSubjectStudentScreen(
      subjectName: widget.subjectName,
      controller: _subjectController,
    ));
  }

  void _onLongPressStudent(Map<String, dynamic> student) {
    _selectionController.enterSelectionMode(student['id']);
    _showSmsTypeSheet();
  }

  void _showSmsTypeSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("SMS turini tanlang", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Obx(() => Text("${_selectionController.selectedIds.length} ta o'quvchi tanlandi", style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fact_check_rounded, color: Color(0xFF3B82F6)),
              ),
              title: const Text("Davomat haqida SMS", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Tayyor shablon bo'yicha", style: TextStyle(fontSize: 12)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _pickAudienceForAttendance();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
              ),
              title: const Text("Shaxsiy SMS", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("O'zingiz matn yozasiz", style: TextStyle(fontSize: 12)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _showCustomSmsDialog();
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _pickAudienceForAttendance() {
    final all = _subjectController.classStudents;
    final absentIds = _absentStudentIds;
    final int currentlyChecked = _selectionController.selectedIds.length;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("Kimlarga yuborilsin?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text(
              "Har bir o'quvchiga o'z holatiga mos matn (kelgan/kelmagan) ketadi.",
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.checklist_rounded, color: Color(0xFF8B5CF6)),
              ),
              title: Text("Faqat tanlanganlarga ($currentlyChecked)", style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Belgilagan (✓) o'quvchilaringiz", style: TextStyle(fontSize: 11.5)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _confirmAndSendAttendanceSms();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: absentIds.isNotEmpty,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626)),
              ),
              title: Text(
                "Faqat kelmaganlarga (${absentIds.length})",
                style: TextStyle(fontWeight: FontWeight.w600, color: absentIds.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A)),
              ),
              subtitle: absentIds.isEmpty ? const Text("Bugun hali belgilanmagan yoki hammasi keldi", style: TextStyle(fontSize: 11.5)) : null,
              onTap: absentIds.isEmpty
                  ? null
                  : () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _selectionController.selectedIds.value = absentIds.toSet();
                _confirmAndSendAttendanceSms();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF10B981)),
              ),
              title: Text("Hammaga (${all.length})", style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Get.back();
                await Future.delayed(const Duration(milliseconds: 150));
                _selectionController.selectedIds.value = all.map((s) => s['id'] as String).toSet();
                _confirmAndSendAttendanceSms();
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _confirmAndSendAttendanceSms() async {
    final selectedCount = _selectionController.selectedIds.length;

    final confirmed = await Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981).withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF10B981), size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                "SMS yuborish",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                  children: [
                    const TextSpan(text: "Tanlangan "),
                    TextSpan(
                      text: "$selectedCount ta o'quvchi",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    const TextSpan(text: "ning ota-onasiga davomat haqida SMS yuboriladi. Davom etasizmi?"),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Get.back(result: false),
                        child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => Get.back(result: true),
                        icon: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                        label: const Text("Yuborish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _selectionController.sendAttendanceSms(
        allStudents: _subjectController.classStudents,
        attendanceMap: _subjectController.attendanceMap,
        subjectName: widget.subjectName,
      );
    }
  }

  void _showCustomSmsDialog() {
    final textController = TextEditingController();

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Text("Shaxsiy SMS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)))),
                ],
              ),
              const SizedBox(height: 6),
              Obx(() => Text(
                "${_selectionController.selectedIds.length} ta ota-onaga yuboriladi. {ism} yozsangiz, har birining ismi bilan almashadi.",
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              )),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 5,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Masalan: Assalomu alaykum, {ism}ning ertagi darsi bekor qilindi.",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Get.back(),
                        child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                        onPressed: () {
                          final text = textController.text.trim();
                          if (text.isEmpty) {
                            Get.snackbar("Diqqat", "SMS matnini kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
                            return;
                          }
                          Get.back();
                          _selectionController.sendCustomSms(allStudents: _subjectController.classStudents, customText: text);
                        },
                        icon: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                        label: const Text("Yuborish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // YANGI: kalendar orqali ISTALGAN sanani tanlash.
  Future<void> _pickAttendanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _subjectController.selectedDate.value,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      await _subjectController.changeDate(picked);
    }
  }

  // YANGI: AppBar action qismidagi ixcham sana navigatsiyasi — kalendar
  // + chap/o'ng strelkalar, kattaroq teginish maydoni bilan.
  Widget _buildCompactDateNavRow() {
    return Obx(() {
      final date = _subjectController.selectedDate.value;
      final bool isToday = _subjectController.isViewingToday;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 24, color: Color(0xFF64748B)),
            onPressed: () => _subjectController.goToPreviousDay(),
            tooltip: "Oldingi kun",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickAttendanceDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    isToday ? "Bugun" : DateFormat('dd.MM.yyyy').format(date),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, size: 24, color: isToday ? const Color(0xFFE2E8F0) : const Color(0xFF64748B)),
            onPressed: isToday ? null : () => _subjectController.goToNextDay(),
            tooltip: "Keyingi kun",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          ),
          const SizedBox(width: 6),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // YANGI: qurilmaning tizim ORQAGA tugmasi/harakati ham AVVAL
    // saqlaydi, keyin chiqadi.
    return WillPopScope(
      onWillPop: () async {
        if (_subjectController.hasUnsavedChanges.value) {
          await _subjectController.saveAttendance();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Obx(() => _selectionController.selectionMode.value
              ? IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
            onPressed: _selectionController.cancel,
          )
              : IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: _saveIfNeededAndPop,
          )),
          title: Obx(() => Text(
            _selectionController.selectionMode.value
                ? "${_selectionController.selectedIds.length} ta tanlandi"
                : "${widget.subjectName} - Boshqaruv",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          )),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "Davomat"),
              Tab(text: "Imtihonlar"),
            ],
          ),
          actions: [
            Obx(() {
              if (_selectionController.selectionMode.value) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Kelmaganlarni tanlash",
                      icon: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626), size: 21),
                      onPressed: () => _selectionController.selectAbsent(_absentStudentIds),
                    ),
                    IconButton(
                      tooltip: "Hammasini tanlash",
                      icon: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981)),
                      onPressed: () => _selectionController.selectAll(
                        _subjectController.classStudents.map((s) => s['id'] as String).toList(),
                      ),
                    ),
                  ],
                );
              }
              if (_currentTabIndex == 0) {
                return _buildCompactDateNavRow();
              }
              return const SizedBox.shrink();
            }),
          ],
        ),

        floatingActionButton: _currentTabIndex == 0
            ? Obx(() => _selectionController.selectionMode.value
            ? const SizedBox.shrink()
            : FloatingActionButton(
          backgroundColor: const Color(0xFF10B981),
          onPressed: _showAddStudentBottomSheet,
          child: const Icon(Icons.add, color: Colors.white),
        ))
            : const SizedBox.shrink(),

        bottomNavigationBar: Obx(() {
          final bool visible = _currentTabIndex == 0 &&
              _selectionController.selectionMode.value &&
              _selectionController.selectedIds.isNotEmpty;

          return AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: !visible
                ? const SizedBox(width: double.infinity, height: 0)
                : Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -6)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: _selectionController.isSending.value ? null : _showSmsTypeSheet,
                  icon: _selectionController.isSending.value
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sms_rounded, color: Colors.white),
                  label: Text(
                    _selectionController.isSending.value
                        ? "Yuborilmoqda..."
                        : "SMS yuborish (${_selectionController.selectedIds.length})",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5),
                  ),
                ),
              ),
            ),
          );
        }),

        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                AttendanceTabScreen(
                  controller: _subjectController,
                  subjectId: widget.subjectId,
                  selectionController: _selectionController,
                  onLongPressStudent: _onLongPressStudent,
                ),
                ExamsTabScreen(
                  examController: _examController,
                  studentsController: _subjectController,
                ),
              ],
            ),
            Obx(() {
              if (!_subjectController.isSaving.value) return const SizedBox.shrink();
              return Container(
                color: Colors.black.withOpacity(0.15),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF10B981)),
                        ),
                        SizedBox(height: 16),
                        Text("Saqlanmoqda...", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155), fontSize: 14.5)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 1 - OYNA (WIDGET): DAVOMAT TABI — o'zgarishsiz.
// =========================================================================



class AttendanceTabScreen extends StatelessWidget {
  final SubjectStudentsController controller;
  final String subjectId;
  final AttendanceSelectionController selectionController;
  final void Function(Map<String, dynamic> student) onLongPressStudent;

  const AttendanceTabScreen({
    super.key,
    required this.controller,
    required this.subjectId,
    required this.selectionController,
    required this.onLongPressStudent,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final students = controller.classStudents;

      if (students.isEmpty) {
        return const Center(child: Text("O'quvchilar yo'q."));
      }

      // 1. Alifbo bo'yicha to'g'ri saralangan nusxa olish
      final sortedStudents = List<Map<String, dynamic>>.from(students)..sort((a, b) {
        final nameA = _studentFullName(a).trim().toLowerCase();
        final nameB = _studentFullName(b).trim().toLowerCase();
        return nameA.compareTo(nameB);
      });

      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: sortedStudents.length,
        itemBuilder: (context, index) {
          // 2. Elementlarni saralangan ro'yxatdan olish
          final student = sortedStudents[index];
          final studentId = student['id'];
          final displayName = _studentFullName(student);
          final bool isPrivileged = student['isPrivileged'] == true;

          return Obx(() {
            final bool inSelectionMode = selectionController.selectionMode.value;
            final bool isSelected = selectionController.selectedIds.contains(studentId);

            return GestureDetector(
              onLongPress: () {
                if (!inSelectionMode) {
                  onLongPressStudent(student);
                } else {
                  selectionController.toggle(studentId);
                }
              },
              child: InkWell(
                onTap: inSelectionMode
                    ? () => selectionController.toggle(studentId)
                    : () => Get.to(() => StudentProfileView(
                  studentId: studentId,
                  subjectId: subjectId,
                  studentName: displayName,
                )),
                child: Container(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981).withOpacity(0.07) : Colors.white,
                    border: Border(
                      bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      left: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.transparent, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: inSelectionMode
                            ? Center(child: _SelectionIndicator(isSelected: isSelected))
                            : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              backgroundColor: isPrivileged ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: isPrivileged ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isPrivileged)
                              const Positioned(
                                top: -4, right: -4,
                                child: Icon(Icons.star_rounded, size: 18, color: Color(0xFFD97706)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      ),
                      Obx(() {
                        bool? isPresent = controller.attendanceMap[studentId];
                        return Row(
                          children: [
                            _buildAttendanceButton(
                              "Bor", isPresent == true, const Color(0xFF15803D),
                                  () => controller.toggleAttendance(studentId, true),
                            ),
                            const SizedBox(width: 8),
                            _buildAttendanceButton(
                              "Yo'q", isPresent == false, const Color(0xFFB91C1C),
                                  () => controller.toggleAttendance(studentId, false),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          });
        },
      );
    });
  }

  Widget _buildAttendanceButton(String label, bool isSelected, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}