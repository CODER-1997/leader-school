import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/school/exam_controller.dart';
import '../../controllers/subject_student_controller.dart';

class ExamsTabScreen extends StatelessWidget {
  final ExamController examController;
  final SubjectStudentsController studentsController;

  const ExamsTabScreen({super.key, required this.examController, required this.studentsController});

  /// Bitta dialog: yaratish HAM tahrirlash uchun ishlatiladi.
  /// existingExam berilsa -> tahrirlash rejimi, aks holda -> yaratish rejimi.
  void _showExamDialog(BuildContext context, {Map<String, dynamic>? existingExam}) {
    final bool isEdit = existingExam != null;

    final TextEditingController nameController = TextEditingController(text: existingExam?['name'] ?? '');
    final TextEditingController countController = TextEditingController(
      text: (existingExam != null && (existingExam['questionCount'] ?? 0) > 0)
          ? existingExam['questionCount'].toString()
          : '',
    );
    String examType = existingExam?['type'] ?? 'foizlik';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          // MUHIM: butun dialog balandligi ekrandan oshib ketmasligi uchun
          // maksimal balandlik cheklanadi va BUTUN kontent (header + maydonlar
          // + tugmalar) bitta SingleChildScrollView'ga o'raladi. Shu bilan
          // "sonlik" tanlanib qo'shimcha maydon chiqqanda ham, klaviatura
          // ochilganda ham overflow bo'lmaydi — dialogning o'zi scroll bo'ladi.
          final double maxDialogHeight = MediaQuery.of(context).size.height * 0.85;
          final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: keyboardHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(isEdit ? Icons.edit_note_rounded : Icons.post_add_rounded, color: const Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              isEdit ? "Imtihonni tahrirlash" : "Yangi imtihon yaratish",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: nameController,
                        autofocus: !isEdit,
                        decoration: InputDecoration(
                          hintText: "Imtihon nomi (masalan: 1-Chorak)",
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Imtihon turi",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ExamTypeChip(
                              label: "Foizlik",
                              subtitle: "0–100%",
                              icon: Icons.percent_rounded,
                              selected: examType == 'foizlik',
                              onTap: () => setState(() => examType = 'foizlik'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ExamTypeChip(
                              label: "Sonlik",
                              subtitle: "Ball asosida",
                              icon: Icons.pin_rounded,
                              selected: examType == 'sonlik',
                              onTap: () => setState(() => examType = 'sonlik'),
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.topCenter,
                        child: examType == 'sonlik'
                            ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: TextField(
                            controller: countController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              hintText: "Savollar soni (masalan: 25)",
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                              ),
                            ),
                          ),
                        )
                            : const SizedBox(width: double.infinity, height: 0),
                      ),
                      const SizedBox(height: 24),
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
                                onPressed: () => Get.back(),
                                child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  final String name = nameController.text.trim();
                                  int qCount = int.tryParse(countController.text) ?? 0;

                                  if (name.isEmpty) {
                                    Get.snackbar(
                                      "Diqqat",
                                      "Imtihon nomini kiriting",
                                      backgroundColor: Colors.orange,
                                      colorText: Colors.white,
                                      snackPosition: SnackPosition.TOP,
                                      margin: const EdgeInsets.all(12),
                                      borderRadius: 12,
                                    );
                                    return;
                                  }
                                  if (examType == 'sonlik' && qCount <= 0) {
                                    Get.snackbar(
                                      "Diqqat",
                                      "Savollar sonini to'g'ri kiriting",
                                      backgroundColor: Colors.orange,
                                      colorText: Colors.white,
                                      snackPosition: SnackPosition.TOP,
                                      margin: const EdgeInsets.all(12),
                                      borderRadius: 12,
                                    );
                                    return;
                                  }

                                  final int finalCount = examType == 'sonlik' ? qCount : 0;

                                  // MUHIM: avval dialogni YOPAMIZ, keyin Firestore'ga
                                  // yozishni fonda (await'siz) boshlaymiz. Real-time
                                  // listener natijani baribir avtomatik ko'rsatadi —
                                  // shuning uchun tugma tarmoq javobini kutib turishi
                                  // shart emas, dialog darhol yopiladi.
                                  Navigator.pop(context);

                                  if (isEdit) {
                                    examController.editExam(existingExam['id'], name, examType, finalCount);
                                  } else {
                                    examController.createExam(name, examType, finalCount);
                                  }
                                },
                                child: Text(isEdit ? "Saqlash" : "Yaratish", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteExam(BuildContext context, Map<String, dynamic> exam, String examName) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Imtihonni o'chirish",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "\"$examName\" imtihonini o'chirmoqchimisiz? Barcha natijalar ham butunlay o'chib ketadi.",
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Get.back(),
                      child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await examController.deleteExam(exam['id']);
                        Get.back();
                      },
                      child: const Text("O'chirish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Expanded(
            // StreamBuilder O'RNIGA Obx — ExamController ichida real-time
            // listener bor, u classExams'ni yangilaydi, bu yerda esa faqat
            // shu observable'ga qarab UI qayta chiziladi.
            child: Obx(() {
              if (examController.isLoading.value && examController.classExams.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
              }

              final exams = examController.classExams;

              // RefreshIndicator — qo'shimcha kafolat sifatida (real-time
              // listener normal holatda o'zi push qiladi, pastga tortish
              // shart emas, lekin uzoq fonda turgandan keyin ulanishni
              // yangilash uchun qulay).
              return RefreshIndicator(
                color: const Color(0xFF10B981),
                onRefresh: examController.refresh,
                child: exams.isEmpty
                    ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assignment_outlined, size: 40, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Hozircha imtihonlar yo'q",
                              style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Pastdagi tugma orqali birinchi imtihonni yarating",
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
                  itemCount: exams.length,
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    final examId = exam['id'] as String;
                    final examName = exam['name'] ?? 'Nomsiz imtihon';
                    final examType = exam['type'] ?? 'foizlik';
                    final questionCount = exam['questionCount'] ?? 0;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Get.to(() => ExamScoresScreen(
                            examId: examId,
                            examName: examName,
                            examType: examType,
                            questionCount: questionCount,
                            examController: examController,
                            studentsController: studentsController,
                          ));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFEEF2F6)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981).withOpacity(0.06)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF10B981), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      examName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15.5),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: examType == 'sonlik' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        examType == 'sonlik' ? "Sonlik · $questionCount ta savol" : "Foizlik",
                                        style: TextStyle(
                                          color: examType == 'sonlik' ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showExamDialog(context, existingExam: exam);
                                  } else if (value == 'delete') {
                                    _confirmDeleteExam(context, exam, examName);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)),
                                        SizedBox(width: 10),
                                        Text("Tahrirlash"),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                        SizedBox(width: 10),
                                        Text("O'chirish", style: TextStyle(color: Color(0xFFDC2626))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => _showExamDialog(context),
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                label: const Text("Yangi imtihon qo'shish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imtihon turini tanlash uchun chiroyli chip komponenti (faqat dizayn uchun)
class _ExamTypeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ExamTypeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: selected ? const Color(0xFF10B981) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kiritilgan qiymatni maksimal ruxsat etilgan sondan oshirmaydi va
/// keraksiz yetakchi nollarni ("036" -> "36") avtomatik tozalaydi.
class _MaxValueInputFormatter extends TextInputFormatter {
  final int max;
  _MaxValueInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;

    // Yetakchi nollarni olib tashlaymiz, lekin yagona "0" bo'lsa saqlab qolamiz.
    if (text.length > 1 && text.startsWith('0')) {
      text = text.replaceFirst(RegExp(r'^0+'), '');
      if (text.isEmpty) text = '0';
    }

    final int? value = int.tryParse(text);
    if (value == null) return oldValue;
    if (max > 0 && value > max) return oldValue;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// =====================================================================
// NATIJALAR EKRANI — Firestore'dan hech qanday qo'shimcha read qilmaydi:
// boshlang'ich ballar controller cache'idan olinadi (0 Read), saqlashda
// esa BARCHA o'zgarishlar bitta write bilan yuboriladi.
// =====================================================================
class ExamScoresScreen extends StatefulWidget {
  final String examId;
  final String examName;
  final String examType;
  final int questionCount;
  final ExamController examController;
  final SubjectStudentsController studentsController;

  const ExamScoresScreen({
    super.key,
    required this.examId,
    required this.examName,
    required this.examType,
    required this.questionCount,
    required this.examController,
    required this.studentsController,
  });

  @override
  State<ExamScoresScreen> createState() => _ExamScoresScreenState();
}

class _ExamScoresScreenState extends State<ExamScoresScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _originalScores = {};
  final Set<String> _dirtyIds = {};

  bool _isSaving = false;

  int get _maxValue => widget.examType == 'sonlik' ? widget.questionCount : 100;

  @override
  void initState() {
    super.initState();
    _loadScores(); // Firestore'ga tegmaydi — controller cache'idan darhol
  }

  void _loadScores() {
    final exam = widget.examController.getExam(widget.examId);
    final Map<String, dynamic> scores = Map<String, dynamic>.from(exam?['scores'] ?? {});

    for (final student in widget.studentsController.classStudents) {
      final String studentId = student['id'];
      final String value = scores[studentId]?.toString() ?? '';
      _originalScores[studentId] = value;
      _controllers[studentId] = TextEditingController(text: value);

      // MUHIM: maydonga bosilganda mavjud qiymat AVTOMATIK tanlanadi —
      // shunda foydalanuvchi yozganda eski raqam ustiga QO'SHILMAY,
      // TO'LIQ ALMASHTIRILADI. Buning yo'qligi "036", "9600" kabi
      // buzuq/qo'shilib ketgan raqamlar kiritilishiga sabab bo'lgan edi.
      final focusNode = FocusNode();
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          final ctrl = _controllers[studentId];
          if (ctrl != null) {
            ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
          }
        }
      });
      _focusNodes[studentId] = focusNode;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Color _scoreColor(String value) {
    if (value.isEmpty) return const Color(0xFF94A3B8);
    final double? parsed = double.tryParse(value);
    if (parsed == null || _maxValue <= 0) return const Color(0xFF94A3B8);
    final double ratio = parsed / _maxValue;
    if (ratio >= 0.8) return const Color(0xFF10B981);
    if (ratio >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _onScoreChanged(String studentId, String value) {
    setState(() {
      if (value != (_originalScores[studentId] ?? '')) {
        _dirtyIds.add(studentId);
      } else {
        _dirtyIds.remove(studentId);
      }
    });
  }

  // Barcha o'quvchilarning JORIY ballarini yig'ib, BITTA write bilan yuboradi.
  Future<void> _saveAll() async {
    if (_dirtyIds.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final Map<String, dynamic> fullScores = {};
    for (final entry in _controllers.entries) {
      final value = entry.value.text;
      if (value.isNotEmpty) {
        fullScores[entry.key] = double.tryParse(value) ?? 0.0;
      }
    }

    try {
      await widget.examController.saveScores(widget.examId, fullScores);

      for (final studentId in _dirtyIds) {
        _originalScores[studentId] = _controllers[studentId]?.text ?? '';
      }

      if (!mounted) return;
      setState(() {
        _dirtyIds.clear();
        _isSaving = false;
      });

      Get.snackbar(
        "Saqlandi",
        "Natijalar muvaffaqiyatli saqlandi",
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (_dirtyIds.isEmpty) return true;

    final bool? shouldLeave = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Saqlanmagan o'zgarishlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: const Text(
          "Ba'zi natijalar hali saqlanmagan. Saqlamasdan chiqishni xohlaysizmi?",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("Bekor qilish")),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text("Chiqish", style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cachedStudents = widget.studentsController.classStudents;

    return PopScope(
      canPop: _dirtyIds.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool leave = await _confirmLeaveIfDirty();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.examName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
              const SizedBox(height: 2),
              Text(
                widget.examType == 'sonlik' ? "Maksimal: ${widget.questionCount} ball" : "Maksimal: 100%",
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            if (_dirtyIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)),
                  )
                      : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                    label: Text(
                      "Saqlash (${_dirtyIds.length})",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: cachedStudents.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text("Sinfda o'quvchilar yo'q", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: cachedStudents.length,
          itemBuilder: (context, index) {
            final student = cachedStudents[index];
            final String studentId = student['id'];
            final String lastName = _capitalize(student['lastName'] ?? '');
            final String firstName = _capitalize(student['firstName'] ?? '');
            final studentName = lastName.isNotEmpty && firstName.isNotEmpty
                ? "$lastName $firstName"
                : _capitalize(student['name'] ?? 'Nomaʼlum');

            final TextEditingController? controller = _controllers[studentId];
            final String currentValue = controller?.text ?? '';
            final Color color = _scoreColor(currentValue);
            final bool isDirty = _dirtyIds.contains(studentId);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDirty ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFFEEF2F6), width: isDirty ? 1.4 : 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: color.withOpacity(0.12),
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                        if (isDirty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    height: 42,
                    child: TextField(
                      controller: controller,
                      focusNode: _focusNodes[studentId],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _MaxValueInputFormatter(_maxValue),
                      ],
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                      decoration: InputDecoration(
                        hintText: widget.examType == 'sonlik' ? "Ball" : "%",
                        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.normal),
                        filled: true,
                        fillColor: color.withOpacity(0.06),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color.withOpacity(0.25)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color.withOpacity(0.25)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: color, width: 1.5),
                        ),
                      ),
                      onChanged: (value) => _onScoreChanged(studentId, value),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}