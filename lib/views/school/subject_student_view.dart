import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:leader_school/views/school/school_exams.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:leader_school/views/school/student_profil/student_profil.dart';
import '../../controllers/subject_student_controller.dart';
import '../../controllers/school/exam_controller.dart';
import '../../controllers/admin_controller/admin_settings_controller.dart';
import '../../services/sms_service.dart'; // MUHIM: agar sizda boshqa yo'lda bo'lsa, shu qatorni to'g'irlang

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
// o'quvchilar ro'yxati (bola widget) o'rtasida BAHAM KO'RILADI. Shu sababli
// alohida, kichik GetX controller sifatida chiqarildi — mavjud
// SubjectStudentsController yoki ExamController ICHIGA HECH NARSA
// qo'shilmadi, ular butunlay o'zgarishsiz qoldi.
// =========================================================================
class AttendanceSelectionController extends GetxController {
  var selectionMode = false.obs;
  var selectedIds = <String>{}.obs;
  var isSending = false.obs;

  static const String _testSmsOverrideRecipient = '+998909050317';

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
    selectedIds.value = allIds.toSet();
    selectionMode.value = true;
  }

  void cancel() {
    selectionMode.value = false;
    selectedIds.clear();
  }

  Future<String> _fetchAttendanceTemplate() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      return doc.data()?['attendance'] ?? AdminSettingsController.defaultAttendanceTemplate;
    } catch (e) {
      return AdminSettingsController.defaultAttendanceTemplate;
    }
  }

  /// Tanlangan o'quvchilarning HAR BIRIGA SMS yuboradi.
  /// SMSService.dart'ga TEGILMAYDI — faqat chaqiradi.
  Future<void> sendSms({
    required List<Map<String, dynamic>> students,
    required String subjectName,
  }) async {
    if (selectedIds.isEmpty || isSending.value) return;
    isSending.value = true;

    final template = await _fetchAttendanceTemplate();
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    final smsService = SMSService();

    int successCount = 0;
    int failCount = 0;

    for (final studentId in selectedIds) {
      final student = students.firstWhereOrNull((s) => s['id'] == studentId);
      if (student == null) continue;

      final fullName = _studentFullName(student);
      final message = template
          .replaceAll('{ism}', fullName)
          .replaceAll('{sinf}', subjectName)
          .replaceAll('{sana}', today);

      // TEST REJIMI: hozircha BARCHA SMS shu raqamga yuboriladi. Test
      // tugagach, quyidagi qatorni o'chirib, shart bo'yicha
      // `student['parentPhone']`ni ishlating — u allaqachon shu yerda tayyor.
      final recipient = _testSmsOverrideRecipient;
      // final recipient = (student['parentPhone'] ?? '').toString();

      try {
        await smsService.sendSMS(recipient, message);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint("SMS yuborishda xato ($fullName): $e");
      }
    }

    isSending.value = false;
    selectionMode.value = false;
    selectedIds.clear();

    Get.snackbar(
      failCount == 0 ? "Yuborildi" : "Qisman yuborildi",
      failCount == 0
          ? "$successCount ta SMS muvaffaqiyatli yuborildi"
          : "$successCount ta yuborildi, $failCount ta xato",
      backgroundColor: failCount == 0 ? const Color(0xFF10B981) : Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
  }
}

// =========================================================================
// SOF VIZUAL — hech qanday holat/logika saqlamaydi. Tanlash mantig'i
// (toggle/enterSelectionMode) faqat qatorning o'zidagi InkWell orqali
// ishlaydi; bu widget faqat isSelected holatini chizadi.
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
  late AttendanceSelectionController _selectionController; // YANGI

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

    // YANGI: tanlash controlleri shu ekranga bog'liq (subjectId bo'yicha tag).
    _selectionController = Get.put(AttendanceSelectionController(), tag: widget.subjectId);
  }

  @override
  void dispose() {
    _tabController.dispose();

    Get.delete<SubjectStudentsController>(tag: widget.subjectId);
    if (_examController.releaseRef()) {
      Get.delete<ExamController>(tag: widget.classId);
    }
    Get.delete<AttendanceSelectionController>(tag: widget.subjectId); // YANGI

    super.dispose();
  }

  void _showAddStudentBottomSheet() {
    var phoneFormatter = MaskTextInputFormatter(
      mask: '+998 (##) ###-##-##',
      filter: { "#": RegExp(r'[0-9]') },
      type: MaskAutoCompletionType.lazy,
    );

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          top: 24, left: 24, right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${widget.subjectName} - Yangi o'quvchi",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subjectController.studentFirstNameController,
                      decoration: InputDecoration(
                        labelText: "Ismi", hintText: "Anvar",
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _subjectController.studentLastNameController,
                      decoration: InputDecoration(
                        labelText: "Familiyasi", hintText: "Aliyev",
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController.studentPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [phoneFormatter],
                decoration: InputDecoration(
                  labelText: "O'quvchi telefoni", hintText: "+998 (90) 123-45-67",
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController.parentPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [phoneFormatter],
                decoration: InputDecoration(
                  labelText: "Ota-ona telefoni", hintText: "+998 (91) 987-65-43",
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Imtiyozli (To'lovdan ozod)", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A), fontSize: 14)),
                    Switch.adaptive(
                      value: _subjectController.isPrivileged.value,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => _subjectController.isPrivileged.value = val,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => InkWell(
                onTap: () => _subjectController.pickJoinedDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      Text("Kelgan sana: ${DateFormat('dd.MM.yyyy').format(_subjectController.joinedDate.value)}"),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () => _subjectController.addStudent(),
                  child: const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // YANGI: FAB bosilganda — avval tasdiqlash dialogi, faqat "Ha" bosilsa yuboradi.
  Future<void> _confirmAndSendSms() async {
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
      await _selectionController.sendSms(
        students: _subjectController.classStudents,
        subjectName: widget.subjectName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // YANGI: tanlash rejimida orqaga strelkasi o'rniga "X" (bekor qilish)
        leading: Obx(() => _selectionController.selectionMode.value
            ? IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
          onPressed: _selectionController.cancel,
        )
            : const BackButton(color: Color(0xFF0F172A))),
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
            // YANGI: tanlash rejimida — "Hammasini tanlash"
            if (_selectionController.selectionMode.value) {
              return TextButton.icon(
                onPressed: () => _selectionController.selectAll(
                  _subjectController.classStudents.map((s) => s['id'] as String).toList(),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF10B981)),
                label: const Text("Hammasini tanlash", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
              );
            }
            // Aks holda — eski "Saqlash" (davomat) tugmasi, o'zgarishsiz
            return _subjectController.hasUnsavedChanges.value
                ? Padding(
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _subjectController.isSaving.value ? null : () => _subjectController.saveAttendance(),
                icon: _subjectController.isSaving.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18, color: Colors.white),
                label: const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
                : const SizedBox.shrink();
          }),
        ],
      ),

      floatingActionButton: _currentTabIndex == 0
          ? Obx(() => _subjectController.hasUnsavedChanges.value
          ? const SizedBox.shrink()
          : FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => _subjectController.addDemoStudents(),
        child: const Icon(Icons.add, color: Colors.white),
      ))
          : const SizedBox.shrink(),

      // YANGI: SMS yuborish tugmasi endi FAB emas — pastdan TO'LIQ KENGLIKDA,
      // ANIMATSIYA bilan "qalqib chiquvchi" panel. Faqat Davomat tabida va
      // kamida bitta o'quvchi tanlanganda ko'rinadi.
      bottomNavigationBar: Obx(() {
        final bool visible = _currentTabIndex == 0 &&
            _selectionController.selectionMode.value &&
            _selectionController.selectedIds.isNotEmpty;

        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter, // pastdan "o'sib" chiqadi — qalqib chiqish effekti
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
                  shape: const StadiumBorder(), // uzunchoq (pill) shakl
                  elevation: 0,
                ),
                onPressed: _selectionController.isSending.value ? null : _confirmAndSendSms,
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

      body: TabBarView(
        controller: _tabController,
        children: [
          // 1-OYNA: Davomat
          AttendanceTabScreen(
            controller: _subjectController,
            subjectId: widget.subjectId,
            selectionController: _selectionController, // YANGI
          ),

          // 2-OYNA: Imtihonlar
          ExamsTabScreen(
              examController: _examController,
              studentsController: _subjectController
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 1 - OYNA (WIDGET): DAVOMAT TABI
// =========================================================================
class AttendanceTabScreen extends StatelessWidget {
  final SubjectStudentsController controller;
  final String subjectId;
  final AttendanceSelectionController selectionController; // YANGI

  const AttendanceTabScreen({
    super.key,
    required this.controller,
    required this.subjectId,
    required this.selectionController,
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

      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final studentId = student['id'];
          final displayName = _studentFullName(student);
          final bool isPrivileged = student['isPrivileged'] == true;

          return Obx(() {
            final bool inSelectionMode = selectionController.selectionMode.value;
            final bool isSelected = selectionController.selectedIds.contains(studentId);

            return GestureDetector(
              // YANGI: istalgan o'quvchini LONG-PRESS qilsa — tanlash rejimi yoqiladi.
              onLongPress: () {
                if (!inSelectionMode) selectionController.enterSelectionMode(studentId);
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
                      // YANGI: tanlash rejimida jilolangan doira-belgi, aks
                      // holda ESKI tartib-raqam/yulduzcha — TOGGLE FUNKSIYASI
                      // o'zgarishsiz (qatorning o'zi InkWell orqali bosiladi,
                      // shu yerda faqat vizual ko'rsatkich chizilyapti).
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