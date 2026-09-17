import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../controllers/center/center_student_controller.dart';

/// O'quvchi qo'shish oqimi — IKKI BOSQICHLI:
///   1. Avval ISM/FAMILIYA bo'yicha QIDIRADI — agar bu odam allaqachon
///      MAKTABDA (yoki boshqa guruhda) ro'yxatdan o'tgan bo'lsa, uni
///      TOPIB, faqat shu GURUHGA BIRIKTIRADI (yangi dublikat yaratmasdan).
///   2. Qidiruvda topilmasa — "Yangi o'quvchi qo'shish" tugmasi orqali
///      to'liq forma ochiladi.
///
/// MUHIM: avval BOTTOM SHEET edi va TextField bosilganda klaviatura bilan
/// to'qnashib, "tepaga ko'tarilib ketish" xatosini berardi (xuddi
/// teacher_form_screen'da bo'lgan muammo). Endi TO'LIQ EKRAN — Scaffold'ning
/// standart resizeToAvoidBottomInset xususiyati klaviaturani avtomatik,
/// muammosiz boshqaradi. Hech qanday qo'lda balandlik/padding hisob-kitobi
/// kerak emas.
void showAddGroupStudentSheet(BuildContext context, GroupStudentsController controller) {
  Get.to(() => _AddGroupStudentScreen(controller: controller));
}

class _AddGroupStudentScreen extends StatefulWidget {
  final GroupStudentsController controller;
  const _AddGroupStudentScreen({required this.controller});

  @override
  State<_AddGroupStudentScreen> createState() => _AddGroupStudentScreenState();
}

class _AddGroupStudentScreenState extends State<_AddGroupStudentScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _showNewForm = false;
  Timer? _debounce;
  String? _linkingId; // YANGI: hozir qaysi o'quvchi biriktirilayotgani (loader uchun)
  bool _isSavingNew = false; // YANGI: yangi o'quvchi saqlanayotgani (loader uchun)

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _isSearching = true);
      final results = await widget.controller.searchExistingStudents(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // =======================================================================
  // YANGI (QO'SHILDI, boshqa hech narsaga tegilmadi): "Yangi o'quvchi
  // qo'shish" formasida saqlashdan OLDIN — bir xil ISM+FAMILIYAli
  // o'quvchi allaqachon 'students' collection'ida bor-yo'qligini
  // tekshiradi. Bo'lsa — ogohlantiradi va SAQLAMAYDI (dublikat
  // yaratilmaydi).
  // =======================================================================
  Future<bool> _duplicateNameExists() async {
    final firstName = widget.controller.studentFirstNameController.text.trim();
    final lastName = widget.controller.studentLastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) return false;

    final snap = await FirebaseFirestore.instance
        .collection('students')
        .where('firstName', isEqualTo: firstName)
        .where('lastName', isEqualTo: lastName)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          _showNewForm ? "Yangi o'quvchi" : "O'quvchini qidirish",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17),
        ),
        leading: _showNewForm
            ? IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _showNewForm = false),
        )
            : null,
      ),
      // resizeToAvoidBottomInset DEFAULT TRUE — klaviatura ochilganda
      // Scaffold body avtomatik, muammosiz qisqaradi.
      body: SafeArea(
        child: _showNewForm
            ? _buildNewForm(context)
            : _buildSearch(context),
      ),
      // YANGI: endi ikkala holatda ham (qidiruv VA forma) tegishli tugma
      // EKRAN OSTIGA MAHKAMLANGAN — ro'yxat ichida "suzib yurmaydi".
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: _showNewForm
            ? SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _isSavingNew ? null : () async {
              setState(() => _isSavingNew = true);

              // YANGI: saqlashdan oldin bir xil ism+familiyali o'quvchi
              // bor-yo'qligini tekshiramiz — bo'lsa, dublikat
              // yaratmasdan to'xtaymiz.
              final isDuplicate = await _duplicateNameExists();
              if (isDuplicate) {
                if (!mounted) return;
                setState(() => _isSavingNew = false);
                Get.snackbar(
                  "Diqqat",
                  "Bunday ism-familiyali o'quvchi allaqachon mavjud",
                  backgroundColor: Colors.orange,
                  colorText: Colors.white,
                );
                return;
              }

              final success = await widget.controller.addNewStudent();
              debugPrint("🔍 addNewStudent natijasi: success=$success, mounted=$mounted");
              if (!mounted) return;
              if (success) {
                debugPrint("🔍 ekran yopilmoqda...");
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Get.back();
                }
              } else {
                setState(() => _isSavingNew = false);
              }
            },
            child: _isSavingNew
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        )
            : SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: () => setState(() => _showNewForm = true),
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981)),
            label: const Text("Yangi o'quvchi qo'shish", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Agar bu o'quvchi maktabda yoki boshqa guruhda ro'yxatdan o'tgan bo'lsa, uni shu yerdan topib biriktirasiz",
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Ism yoki familiya...",
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
            )
          else if (_searchController.text.trim().isNotEmpty && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text("\"${_searchController.text.trim()}\" bo'yicha hech kim topilmadi", style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            )
          else
            ..._results.map((s) {
              final alreadyIn = s['alreadyInThisGroup'] == true;
              final bool isLinking = _linkingId == s['id'];
              final fullName = "${s['lastName']} ${s['firstName']}".trim();
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: (alreadyIn || _linkingId != null) ? null : () async {
                  setState(() => _linkingId = s['id']);
                  final ok = await widget.controller.linkExistingStudent(s['id']);
                  debugPrint("🔍 linkExistingStudent natijasi: ok=$ok, mounted=$mounted");
                  if (!mounted) return;
                  if (ok) {
                    debugPrint("🔍 Get.back() chaqirilmoqda...");
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Get.back();
                    }
                  } else {
                    // Xato bo'lsa — loaderni to'xtatib, qayta urinishga ruxsat beramiz
                    setState(() => _linkingId = null);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: alreadyIn ? const Color(0xFFF1F5F9) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.12),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName.isEmpty ? "Nomsiz" : fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                            if ((s['phone'] as String).isNotEmpty)
                              Text(s['phone'], style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      if (isLinking)
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF10B981)),
                        )
                      else if (alreadyIn)
                        const Text("Guruhda", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))
                      else
                        const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNewForm(BuildContext context) {
    final phoneFormatter = MaskTextInputFormatter(
      mask: '+998 (##) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller.studentFirstNameController,
                  decoration: InputDecoration(
                    labelText: "Ismi", hintText: "Anvar",
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller.studentLastNameController,
                  decoration: InputDecoration(
                    labelText: "Familiyasi", hintText: "Aliyev",
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller.studentPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [phoneFormatter],
            decoration: InputDecoration(
              labelText: "O'quvchi telefoni", hintText: "+998 (90) 123-45-67",
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller.parentPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [phoneFormatter],
            decoration: InputDecoration(
              labelText: "Ota-ona telefoni", hintText: "+998 (91) 987-65-43",
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Imtiyozli (To'lovdan ozod)", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A), fontSize: 14)),
                Switch.adaptive(
                  value: widget.controller.isPrivileged.value,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) => widget.controller.isPrivileged.value = val,
                ),
              ],
            )),
          ),
          const SizedBox(height: 16),
          Obx(() => InkWell(
            onTap: () => widget.controller.pickJoinedDate(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
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
        ],
      ),
    );
  }
}