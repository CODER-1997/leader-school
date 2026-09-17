import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// XATO TUZATILDI: bu fayl views/school/ papkasida joylashgani
// aniqlandi (subject_students_view.dart bilan bir joyda), shuning
// uchun student_profil.dart'ga yo'l '../school/...' EMAS — u allaqachon
// shu papkaning ichida.
import 'package:leader_school/views/school/student_profil/student_profil.dart';
import '../../controllers/crm_controller.dart';
// XATO TUZATILDI: endi controller turi ANIQ — SubjectStudentsController.
import '../../controllers/subject_student_controller.dart';

/// YANGI: "Yangi o'quvchi" endi BOTTOM SHEET EMAS — ALOHIDA, TO'LIQ
/// SCREEN sifatida ochiladi (Get.to orqali). AppBar'dagi orqaga
/// qaytish tugmasi avtomatik chiqadi — qo'lda "X" tugmasi kerak emas.
///
/// Ichidagi mantiq (maydonlar, Saqlash tugmasi, dublikat qidiruv)
/// avvalgi bottom sheet bilan BIR XIL — faqat konteyner
/// Get.bottomSheet() emas, endi Scaffold + Get.to().
class AddSubjectStudentScreen extends StatefulWidget {
  final String subjectName;
  // XATO TUZATILDI: dynamic o'rniga endi ANIQ tur — SubjectStudentsController.
  final SubjectStudentsController controller;

  const AddSubjectStudentScreen({
    super.key,
    required this.subjectName,
    required this.controller,
  });

  @override
  State<AddSubjectStudentScreen> createState() => _AddSubjectStudentScreenState();
}

class _AddSubjectStudentScreenState extends State<AddSubjectStudentScreen> {
  final MaskTextInputFormatter _phoneFormatter = MaskTextInputFormatter(
    mask: '+998 (##) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // YANGI: joriy qidiruv natijalari.
  List<Map<String, dynamic>> _matches = [];

  // YANGI: ism/familiya maydoni o'zgarganda chaqiriladi — CrmController.
  // allStudents keshidan (YANGI Firestore so'rovi YO'Q) qidiradi.
  void _searchDuplicates() {
    final first = widget.controller.studentFirstNameController.text.trim().toLowerCase();
    final last = widget.controller.studentLastNameController.text.trim().toLowerCase();

    if (first.isEmpty && last.isEmpty) {
      setState(() => _matches = []);
      return;
    }
    if (!Get.isRegistered<CrmController>()) return;

    final all = Get.find<CrmController>().allStudents;
    final found = all.where((s) {
      if (s['isArchived'] == true) return false;
      final sFirst = (s['firstName'] ?? '').toString().toLowerCase();
      final sLast = (s['lastName'] ?? '').toString().toLowerCase();
      final firstOk = first.isEmpty || sFirst.contains(first);
      final lastOk = last.isEmpty || sLast.contains(last);
      return firstOk && lastOk;
    }).toList();

    setState(() => _matches = found.take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Text(
          "${widget.subjectName} - Yangi o'quvchi",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller.studentFirstNameController,
                      onChanged: (_) => _searchDuplicates(),
                      decoration: InputDecoration(
                        labelText: "Ismi",
                        hintText: "Anvar",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: widget.controller.studentLastNameController,
                      onChanged: (_) => _searchDuplicates(),
                      decoration: InputDecoration(
                        labelText: "Familiyasi",
                        hintText: "Aliyev",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // YANGI: agar o'xshash ismli/familiyali o'quvchi(lar)
              // topilsa — shu yerda ogohlantirish chiqadi.
              if (_matches.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDuplicateWarning(_matches),
              ],

              const SizedBox(height: 16),
              TextField(
                controller: widget.controller.studentPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneFormatter],
                decoration: InputDecoration(
                  labelText: "O'quvchi telefoni",
                  hintText: "+998 (90) 123-45-67",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: widget.controller.parentPhoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneFormatter],
                decoration: InputDecoration(
                  labelText: "Ota-ona telefoni",
                  hintText: "+998 (91) 987-65-43",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
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
                    const Text(
                      "Imtiyozli (To'lovdan ozod)",
                      style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A), fontSize: 14),
                    ),
                    // YANGI: Obx bilan o'raldi — bottom sheet versiyasida
                    // bu yo'q edi, shuning uchun switch bosilganda
                    // ko'rinishi darhol yangilanmasligi mumkin edi.
                    Obx(() => Switch.adaptive(
                      value: widget.controller.isPrivileged.value,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => widget.controller.isPrivileged.value = val,
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => InkWell(
                onTap: () => widget.controller.pickJoinedDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      Text("Kelgan sana: ${DateFormat('dd.MM.yyyy').format(widget.controller.joinedDate.value)}"),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => widget.controller.addStudent(),
                  child: const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // YANGI: topilgan o'xshash o'quvchi(lar)ni ko'rsatuvchi ogohlantirish
  // qutisi. Har bir qator bosilsa — ushbu screen yopilib, "Umumiy
  // talabalar" tabidagi bilan BIR XIL StudentProfileView ekrani
  // ochiladi.
  Widget _buildDuplicateWarning(List<Map<String, dynamic>> matches) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Diqqat: shunga o'xshash ${matches.length} ta o'quvchi allaqachon bazada bor:",
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...matches.map((m) {
            final last = (m['lastName'] ?? '').toString();
            final first = (m['firstName'] ?? '').toString();
            final name = "$last $first".trim();
            final phone = (m['phone'] ?? m['parentPhone'] ?? '').toString();
            final studentId = m['id'] as String;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Get.back(); // shu "Yangi o'quvchi" screen'ini yopamiz
                  Get.to(() => StudentProfileView(studentId: studentId, subjectId: '', studentName: name));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 14, color: Color(0xFF92400E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phone.isNotEmpty ? "$name — $phone" : name,
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFB45309)),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          const Text(
            "Profilni ko'rish uchun ustiga bosing. Agar shu odam bo'lsa — uni qaytadan qo'shmang, mavjud profiliga shu fan/guruhni qo'shing.",
            style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
          ),
        ],
      ),
    );
  }
}