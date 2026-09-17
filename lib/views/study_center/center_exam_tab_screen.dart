import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:leader_school/controllers/admin_controller/admin_settings_controller.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
import 'package:leader_school/services/sms_service.dart'; // MUHIM: shu ham

import '../../controllers/center/center_exam_controller.dart';

/// O'QUV MARKAZ uchun Imtihonlar ekrani — Maktabning ExamsTabScreen
/// dizayni bilan BIR XIL, lekin CenterExamController orqali mustaqil
/// 'center_exams' collection bilan ishlaydi (Maktabga aloqasi yo'q).
class CenterExamsTabScreen extends StatelessWidget {
  final CenterExamController examController;
  final List<Map<String, dynamic>> students;

  const CenterExamsTabScreen({super.key, required this.examController, required this.students});

  /// Bitta dialog: yaratish HAM tahrirlash uchun ishlatiladi.
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
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
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("Imtihon turi", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ExamTypeChip(
                              label: "Foizlik", subtitle: "0–100%", icon: Icons.percent_rounded,
                              selected: examType == 'foizlik',
                              onTap: () => setState(() => examType = 'foizlik'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ExamTypeChip(
                              label: "Sonlik", subtitle: "Ball asosida", icon: Icons.pin_rounded,
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
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
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                                onPressed: () async {
                                  final String name = nameController.text.trim();
                                  int qCount = int.tryParse(countController.text) ?? 0;

                                  if (name.isEmpty) {
                                    Get.snackbar("Diqqat", "Imtihon nomini kiriting", backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12), borderRadius: 12);
                                    return;
                                  }
                                  if (examType == 'sonlik' && qCount <= 0) {
                                    Get.snackbar("Diqqat", "Savollar sonini to'g'ri kiriting", backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12), borderRadius: 12);
                                    return;
                                  }

                                  final int finalCount = examType == 'sonlik' ? qCount : 0;

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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text("Imtihonni o'chirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text("\"$examName\" imtihonini o'chirmoqchimisiz? Barcha natijalar ham butunlay o'chib ketadi.", style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
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
            child: Obx(() {
              if (examController.isLoading.value && examController.classExams.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2.5));
              }

              if (examController.errorMessage.value != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            SizedBox(width: 8),
                            Text("Imtihonlarni yuklashda xato", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(examController.errorMessage.value!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                );
              }

              final exams = examController.classExams;

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
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
                              child: const Icon(Icons.assignment_outlined, size: 40, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(height: 16),
                            const Text("Hozircha imtihonlar yo'q", style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text("Pastdagi tugma orqali birinchi imtihonni yarating", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13), textAlign: TextAlign.center),
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
                    final smsStatus = exam['smsStatus'] as Map<String, dynamic>?;
                    final smsSentAt = smsStatus?['sentAt'] as Timestamp?;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Get.to(() => CenterExamScoresScreen(
                            examId: examId,
                            examName: examName,
                            examType: examType,
                            questionCount: questionCount,
                            examController: examController,
                            students: students,
                          ));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFEEF2F6)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 48, width: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981).withOpacity(0.06)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF10B981), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(examName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15.5)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: examType == 'sonlik' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                      child: Text(
                                        examType == 'sonlik' ? "Sonlik · $questionCount ta savol" : "Foizlik",
                                        style: TextStyle(color: examType == 'sonlik' ? const Color(0xFF3B82F6) : const Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    // YANGI: SMS yuborilganini boshqa
                                    // o'qituvchi/admin ham ro'yxatdan
                                    // KO'RSIN — qayta yuborib yubormasin.
                                    if (smsSentAt != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 4),
                                          Text(
                                            "SMS yuborilgan: ${DateFormat('dd.MM.yyyy HH:mm').format(smsSentAt.toDate())}",
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
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
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 10), Text("Tahrirlash")])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text("O'chirish", style: TextStyle(color: Color(0xFFDC2626)))])),
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
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
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

class _ExamTypeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ExamTypeChip({required this.label, required this.subtitle, required this.icon, required this.selected, required this.onTap});

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
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF10B981) : const Color(0xFF334155))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _MaxValueInputFormatter extends TextInputFormatter {
  final int max;
  _MaxValueInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.isEmpty) return newValue;

    if (text.length > 1 && text.startsWith('0')) {
      text = text.replaceFirst(RegExp(r'^0+'), '');
      if (text.isEmpty) text = '0';
    }

    final int? value = int.tryParse(text);
    if (value == null) return oldValue;
    if (max > 0 && value > max) return oldValue;

    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// =====================================================================
// NATIJALAR EKRANI — O'quv Markaz uchun mustaqil, lekin Maktabdagi bilan
// bir xil UX: 0 Read (cache'dan), bitta write bilan saqlash, dirty-state
// ko'rsatkichlari, avtomatik tanlash, chiqishdan oldin ogohlantirish.
// =====================================================================
class CenterExamScoresScreen extends StatefulWidget {
  final String examId;
  final String examName;
  final String examType;
  final int questionCount;
  final CenterExamController examController;
  final List<Map<String, dynamic>> students;

  const CenterExamScoresScreen({
    super.key,
    required this.examId,
    required this.examName,
    required this.examType,
    required this.questionCount,
    required this.examController,
    required this.students,
  });

  @override
  State<CenterExamScoresScreen> createState() => _CenterExamScoresScreenState();
}

class _CenterExamScoresScreenState extends State<CenterExamScoresScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _originalScores = {};
  final Set<String> _dirtyIds = {};
  bool _isSaving = false;
  bool _isSendingSms = false;

  // YANGI: sessiyaga bog'liq emas — agar HOZIR yoki OLDIN (boshqa
  // safar) kamida bitta ball kiritilgan bo'lsa, tugmalar ko'rinadi.
  bool get _hasAnyResults => _controllers.values.any((c) => c.text.trim().isNotEmpty);

  // YANGI: SMS allaqachon yuborilganini imtihon hujjatining o'zidan
  // (real-time) o'qiydi — shu bilan boshqa o'qituvchi yuborgan bo'lsa
  // ham darhol ko'rinadi.
  Map<String, dynamic>? get _smsStatus {
    final exam = widget.examController.getExam(widget.examId);
    return exam?['smsStatus'] as Map<String, dynamic>?;
  }

  // TEST REJIMI: boshqa SMS funksiyalari kabi, hozircha BARCHA SMS shu
  // raqamga yuboriladi. Test tugagach, _sendResultsSms() ichida
  // student['parentPhone']'ga almashtiring.

  int get _maxValue => widget.examType == 'sonlik' ? widget.questionCount : 100;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  void _loadScores() {
    final exam = widget.examController.getExam(widget.examId);
    final Map<String, dynamic> scores = Map<String, dynamic>.from(exam?['scores'] ?? {});

    for (final student in widget.students) {
      final String studentId = student['id'];
      final String value = scores[studentId]?.toString() ?? '';
      _originalScores[studentId] = value;
      _controllers[studentId] = TextEditingController(text: value);

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

      Get.snackbar("Saqlandi", "Natijalar muvaffaqiyatli saqlandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white, snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(12), borderRadius: 12);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _capitalizeWord(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // =======================================================================
  // NATIJALARNI OTA-ONAGA SMS ORQALI YUBORISH — har bir o'quvchining
  // O'ZINING ballini o'zining ota-onasiga alohida SMS qilib yuboradi.
  // MUHIM: agar bu imtihon uchun SMS ALLAQACHON yuborilgan bo'lsa (hatto
  // BOSHQA o'qituvchi tomonidan), avval TASDIQLASH so'raladi — ota-onani
  // qayta-qayta bezovta qilmaslik uchun.
  // =======================================================================
  Future<void> _sendResultsSms() async {
    final existingStatus = _smsStatus;
    if (existingStatus != null) {
      final sentAt = existingStatus['sentAt'] as Timestamp?;
      final sentText = sentAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(sentAt.toDate()) : 'avval';

      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("SMS allaqachon yuborilgan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: Text(
            "Bu imtihon natijalari uchun SMS $sentText yuborilgan (${existingStatus['sentCount'] ?? 1}-marta). Ota-onalarni qayta bezovta qilib, yana yubormoqchimisiz?",
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text("Bekor qilish")),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text("Baribir yuborish", style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isSendingSms = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('sms_templates').get();
      final template = (doc.data()?['examResult'] ?? AdminSettingsController.defaultExamResultTemplate).toString();
      final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
      final smsService = SMSService();

      int successCount = 0;
      int failCount = 0;

      for (final student in widget.students) {
        final studentId = student['id'];
        final scoreText = _controllers[studentId]?.text ?? '';
        if (scoreText.isEmpty) continue; // ball kiritilmagan o'quvchiga yubormaymiz

        final fullName = "${_capitalizeWord(student['lastName'] ?? '')} ${_capitalizeWord(student['firstName'] ?? '')}".trim();
        final resultLabel = widget.examType == 'sonlik' ? "$scoreText/${widget.questionCount}" : "$scoreText%";

        final message = template
            .replaceAll('{ism}', fullName.isEmpty ? (student['name'] ?? '') : fullName)
            .replaceAll('{imtihon}', widget.examName)
            .replaceAll('{ball}', resultLabel)
            .replaceAll('{natija}', resultLabel) // MUHIM: ba'zi shablonlar {natija} ishlatishi mumkin — ikkalasi ham qoplanadi
            .replaceAll('{sana}', today);

        // TEST REJIMI — real ishga tushirishda pastdagi qatorni
        // (student['parentPhone'] ?? '').toString() bilan almashtiring.
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

      // YANGI: yuborilgan holatni imtihon hujjatida BELGILAYMIZ — shu
      // bilan boshqa o'qituvchi ham ro'yxatdan ko'radi.
      if (successCount > 0) {
        await widget.examController.markSmsSent(widget.examId);
      }

      Get.snackbar(
        failCount == 0 ? "Yuborildi" : "Qisman yuborildi",
        failCount == 0 ? "$successCount ta SMS yuborildi" : "$successCount ta yuborildi, $failCount ta xato",
        backgroundColor: failCount == 0 ? const Color(0xFF10B981) : Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Xatolik", "SMS yuborishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  // =======================================================================
  // NATIJALARNI RASM SIFATIDA ULASHISH — xom UI skrinshoti EMAS, balki
  // natijaga qarab SARALANGAN, chiroyli tartibga solingan alohida
  // "Natijalar" posteri ochiladi (o'sha yerdan ulashiladi).
  // =======================================================================
  void _shareResultsAsImage() {
    final List<Map<String, dynamic>> ranked = [];
    for (final student in widget.students) {
      final id = student['id'];
      final text = _controllers[id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final score = double.tryParse(text) ?? 0;
      ranked.add({...student, '_score': score, '_scoreText': text});
    }

    if (ranked.isEmpty) {
      Get.snackbar("Diqqat", "Hali birorta ball kiritilmagan", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    // Yuqoridan pastga — eng yuqori balldan boshlab.
    ranked.sort((a, b) => (b['_score'] as double).compareTo(a['_score'] as double));

    Get.dialog(
      _ResultsPosterDialog(
        examName: widget.examName,
        examType: widget.examType,
        questionCount: widget.questionCount,
        rankedStudents: ranked,
      ),
      barrierDismissible: true,
    );
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (_dirtyIds.isEmpty) return true;

    final bool? shouldLeave = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Saqlanmagan o'zgarishlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: const Text("Ba'zi natijalar hali saqlanmagan. Saqlamasdan chiqishni xohlaysizmi?", style: TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text("Bekor qilish")),
          TextButton(onPressed: () => Get.back(result: true), child: const Text("Chiqish", style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cachedStudents = widget.students;
    cachedStudents.sort((a, b) {
      // Avval familiya bo'yicha solishtiramiz
      String lastNameA = (a['lastName'] ?? '').toLowerCase();
      String lastNameB = (b['lastName'] ?? '').toLowerCase();
      int compareResult = lastNameA.compareTo(lastNameB);

      // Agar familiyalari bir xil bo'lsa, ism bo'yicha solishtiramiz
      if (compareResult == 0) {
        String firstNameA = (a['firstName'] ?? '').toLowerCase();
        String firstNameB = (b['firstName'] ?? '').toLowerCase();
        compareResult = firstNameA.compareTo(firstNameB);
      }
      return compareResult;
    });

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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)))
                      : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    onPressed: _saveAll,
                    icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                    label: Text("Saqlash (${_dirtyIds.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                decoration: BoxDecoration(color: const Color(0xFF94A3B8).withOpacity(0.08), shape: BoxShape.circle),
                child: const Icon(Icons.people_outline_rounded, size: 40, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              const Text("Guruhda o'quvchilar yo'q", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
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
                          child: Text("${index + 1}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(studentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        ),
                        if (isDirty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MaxValueInputFormatter(_maxValue)],
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                      decoration: InputDecoration(
                        hintText: widget.examType == 'sonlik' ? "Ball" : "%",
                        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.normal),
                        filled: true,
                        fillColor: color.withOpacity(0.06),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.25))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withOpacity(0.25))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.5)),
                      ),
                      onChanged: (value) => _onScoreChanged(studentId, value),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: _hasAnyResults
            ? Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // YANGI: SMS allaqachon yuborilgan bo'lsa — buni ANIQ
              // ko'rsatamiz (boshqa o'qituvchi yuborgan bo'lsa ham).
              if (_smsStatus != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SMS yuborilgan: ${_smsStatus!['sentAt'] != null ? DateFormat('dd.MM.yyyy HH:mm').format((_smsStatus!['sentAt'] as Timestamp).toDate()) : ''}",
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: BorderSide(color: _smsStatus != null ? const Color(0xFFCBD5E1) : const Color(0xFF3B82F6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: _isSendingSms ? null : _sendResultsSms,
                        icon: _isSendingSms
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)))
                            : Icon(Icons.sms_rounded, color: _smsStatus != null ? const Color(0xFF64748B) : const Color(0xFF3B82F6), size: 20),
                        label: Text(
                          _isSendingSms ? "..." : (_smsStatus != null ? "Qayta yuborish" : "SMS yuborish"),
                          style: TextStyle(color: _smsStatus != null ? const Color(0xFF64748B) : const Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                        onPressed: _shareResultsAsImage,
                        icon: const Icon(Icons.image_rounded, color: Colors.white, size: 20),
                        label: const Text("Natijalar rasmi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
            : null,
      ),
    );
  }
}

// =========================================================================
// NATIJALAR POSTERI — natijaga qarab SARALANGAN, chiroyli tartibga
// solingan, xom UI skrinshoti EMAS, alohida qurilgan rasm. Shu ekrandan
// to'g'ridan-to'g'ri Telegram/boshqa ilovaga ulashiladi.
// =========================================================================
class _ResultsPosterDialog extends StatefulWidget {
  final String examName;
  final String examType;
  final int questionCount;
  final List<Map<String, dynamic>> rankedStudents; // saralangan, '_score'/'_scoreText' bilan

  const _ResultsPosterDialog({
    required this.examName,
    required this.examType,
    required this.questionCount,
    required this.rankedStudents,
  });

  @override
  State<_ResultsPosterDialog> createState() => _ResultsPosterDialogState();
}

class _ResultsPosterDialogState extends State<_ResultsPosterDialog> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isSharing = false;

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.trim().split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _rankLabel(int position) {
    switch (position) {
      case 1:
        return "🥇";
      case 2:
        return "🥈";
      case 3:
        return "🥉";
      default:
        return "${position}";
    }
  }

  Color _rankColor(int position) {
    switch (position) {
      case 1:
        return const Color(0xFFD97706);
      case 2:
        return const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception("Rasmni olib bo'lmadi");

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Rasmni saqlab bo'lmadi");

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/natijalar_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)], text: "${widget.examName} — natijalar");
    } catch (e) {
      Get.snackbar("Xatolik", "Ulashishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _posterKey,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SARLAVHA ---
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF10B981), size: 28),
                                ),
                                const SizedBox(height: 12),
                                Text(widget.examName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF0F172A)), textAlign: TextAlign.center),
                                const SizedBox(height: 4),
                                Text(
                                  "${DateFormat('dd.MM.yyyy').format(DateTime.now())} · ${widget.rankedStudents.length} ta o'quvchi",
                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(height: 1, color: const Color(0xFFE2E8F0)),
                          const SizedBox(height: 16),

                          // --- SARALANGAN RO'YXAT ---
                          ...widget.rankedStudents.asMap().entries.map((entry) {
                            final position = entry.key + 1;
                            final student = entry.value;
                            final lastName = _capitalize(student['lastName'] ?? '');
                            final firstName = _capitalize(student['firstName'] ?? '');
                            final name = lastName.isNotEmpty && firstName.isNotEmpty ? "$lastName $firstName" : _capitalize(student['name'] ?? 'Nomsiz');
                            final scoreText = student['_scoreText'] as String;
                            final resultLabel = widget.examType == 'sonlik' ? "$scoreText/${widget.questionCount}" : "$scoreText%";

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      _rankLabel(position),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: position <= 3 ? 18 : 13, fontWeight: FontWeight.bold, color: _rankColor(position)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(resultLabel, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: position <= 3 ? _rankColor(position) : const Color(0xFF334155))),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 16),
                          Container(height: 1, color: const Color(0xFFE2E8F0)),
                          const SizedBox(height: 10),
                          const Center(
                            child: Text("Leader School", style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600, letterSpacing: 1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- HARAKAT TUGMALARI (posterning o'zi rasmga olinmaydi) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          onPressed: () => Get.back(),
                          child: const Text("Yopish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          onPressed: _isSharing ? null : _share,
                          icon: _isSharing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.telegram_rounded, color: Colors.white, size: 18),
                          label: Text(_isSharing ? "..." : "Ulashish", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}