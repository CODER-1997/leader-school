import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// O'quvchining O'quv Markaz guruh a'zoligini VA Maktab sinfini
/// tahrirlash — ENDI TO'LIQ EKRAN (avval kichik Dialog edi).
///
/// YANGI:
///   1. Endi Get.dialog() emas, Get.to() orqali TO'LIQ EKRAN sifatida
///      ochiladi — kengroq, qulayroq (avvalgi kichik oyna torlik
///      qilardi).
///   2. Ichida ikkita TAB: "Maktab" (sinf tanlash) va "Markaz"
///      (fan/guruhlar) — avval ikkalasi bitta uzun sahifada ustma-ust
///      turardi.
void showStudentGroupsEditScreen({
  required List<String> currentGroupIds,
  required String? currentClassId,
  required Future<bool> Function(
      List<String> newGroupIds,
      Map<String, String> subjectIdByGroupId,
      String? newClassId,
      ) onSave,
}) {
  Get.to(() => _StudentGroupsEditScreen(
    currentGroupIds: currentGroupIds,
    currentClassId: currentClassId,
    onSave: onSave,
  ));
}

class _StudentGroupsEditScreen extends StatefulWidget {
  final List<String> currentGroupIds;
  final String? currentClassId;
  final Future<bool> Function(
      List<String> newGroupIds,
      Map<String, String> subjectIdByGroupId,
      String? newClassId,
      ) onSave;

  const _StudentGroupsEditScreen({
    required this.currentGroupIds,
    required this.currentClassId,
    required this.onSave,
  });

  @override
  State<_StudentGroupsEditScreen> createState() => _StudentGroupsEditScreenState();
}

class _StudentGroupsEditScreenState extends State<_StudentGroupsEditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _subjectsWithGroups = [];
  late Set<String> _selectedGroupIds;
  late Map<String, String> _subjectIdByGroupId;

  List<Map<String, String>> _schoolClasses = [];
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedGroupIds = widget.currentGroupIds.toSet();
    _selectedClassId = widget.currentClassId;
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final subjectsSnap = await db.collection('center_subjects').get();
      final groupsSnap = await db.collection('groups').get();
      final classesSnap = await db.collection('school_classes').orderBy('name').get();

      final Map<String, dynamic> subjectsById = {
        for (final doc in subjectsSnap.docs) doc.id: doc.data(),
      };

      final Map<String, List<Map<String, String>>> groupsBySubject = {};
      final Map<String, String> subjectIdByGroupId = {};

      for (final doc in groupsSnap.docs) {
        final data = doc.data();
        final subjId = data['subjectId'] as String? ?? '';
        final entry = {'id': doc.id, 'name': (data['name'] ?? 'Nomsiz guruh').toString()};
        groupsBySubject.putIfAbsent(subjId, () => []).add(entry);
        subjectIdByGroupId[doc.id] = subjId;
      }

      final List<Map<String, dynamic>> result = subjectsById.entries.map((e) {
        return {
          'subjectId': e.key,
          'subjectName': e.value['name'] ?? 'Nomsiz fan',
          'groups': groupsBySubject[e.key] ?? [],
        };
      }).toList();
      result.sort((a, b) => (a['subjectName'] as String).compareTo(b['subjectName'] as String));

      final classes = classesSnap.docs.map((d) => {
        'id': d.id,
        'name': (d.data()['name'] ?? 'Nomsiz sinf').toString(),
      }).toList();

      if (!mounted) return;
      setState(() {
        _subjectsWithGroups = result;
        _subjectIdByGroupId = subjectIdByGroupId;
        _schoolClasses = classes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.onSave(_selectedGroupIds.toList(), _subjectIdByGroupId, _selectedClassId);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
      Get.snackbar("Saqlandi", "Ma'lumotlar yangilandi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } else {
      Get.snackbar("Xatolik", "Saqlashda xato yuz berdi", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Widget _classChip({required String? id, required String name}) {
    final bool isSelected = _selectedClassId == id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedClassId = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), // YANGI: kattaroq, qulayroq
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }

  // YANGI: "Maktab" tabi — bitta sinf tanlash.
  Widget _buildSchoolTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "O'quvchi qaysi sinfda o'qiydi?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Maktabda o'qimasa, \"Hech qaysi\"ni tanlang.",
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          if (_schoolClasses.isEmpty)
            const Text("Sinflar topilmadi", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _classChip(id: null, name: "Hech qaysi"),
                ..._schoolClasses.map((c) => _classChip(id: c['id'], name: c['name']!)),
              ],
            ),
        ],
      ),
    );
  }

  // YANGI: "Markaz" tabi — fan/guruhlar (checkbox), avvalgi mantiq bilan bir xil.
  Widget _buildCenterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Qaysi guruh(lar)ga a'zo?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Bir nechta fan/guruh tanlash mumkin.",
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          if (_subjectsWithGroups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("Hozircha fanlar yo'q", style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ..._subjectsWithGroups.map((subj) {
              final groups = subj['groups'] as List<Map<String, String>>;
              if (groups.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(subj['subjectName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155))),
                    ),
                    ...groups.map((g) {
                      final isSelected = _selectedGroupIds.contains(g['id']);
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xFF10B981),
                        title: Text(g['name']!, style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B))),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedGroupIds.add(g['id']!);
                            } else {
                              _selectedGroupIds.remove(g['id']!);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text("Sinf va guruhlar", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Maktab"),
            Tab(text: "Markaz"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _error != null
          ? Padding(
        padding: const EdgeInsets.all(20),
        child: Text("Xato: $_error", style: const TextStyle(color: Colors.red, fontSize: 12.5)),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildSchoolTab(),
          _buildCenterTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))]),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            onPressed: (_isLoading || _isSaving) ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}