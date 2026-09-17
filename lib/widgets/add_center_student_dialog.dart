import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

/// O'quvchi qo'shish — UMUMIY ro'yxatdan (CenterAllStudentsTab) chaqiriladi.
///
/// YANGI TARTIB (qayta qurildi — avvalgi versiyada guruh tanlash ENG
/// TEPADA, ma'lumot kiritishdan OLDIN edi — bu chalkash edi):
///   1-QADAM: O'quvchini QIDIRISH (mavjudmi) YOKI "Yangi o'quvchi"
///            formasida ISM/FAMILIYA/TELEFON kiritish.
///   2-QADAM ("Keyingi" tugmasi orqali): GURUH(LAR)NI TANLASH —
///            faqat SHU BOSQICHDA ko'rinadi, ma'lumot allaqachon
///            kiritilgan/tanlangandan KEYIN.
///   Yakuniy "Saqlash" — shu 2-qadamda.
void showAddCenterStudentScreen(BuildContext context, {VoidCallback? onSaved}) {
  Get.to(() => _AddCenterStudentScreen(onSaved: onSaved));
}

class _AddCenterStudentScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const _AddCenterStudentScreen({this.onSaved});

  @override
  State<_AddCenterStudentScreen> createState() => _AddCenterStudentScreenState();
}

class _AddCenterStudentScreenState extends State<_AddCenterStudentScreen> {
  final _db = FirebaseFirestore.instance;

  // Qidirish bosqichi
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Yangi forma bosqichi
  bool _showNewForm = false;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  bool _isPrivileged = false;
  DateTime _joinedDate = DateTime.now();

  // YANGI: 2-QADAM holati — guruh tanlash. Bu ENDI oxirgi bosqich.
  bool _showGroupPick = false;
  Map<String, dynamic>? _pendingLinkStudent; // qidiruvdan tanlangan (mavjud) o'quvchi
  bool _isCheckingBeforeNext = false; // "Keyingi" bosilganda dublikat tekshiruvi uchun
  bool _isSaving = false; // yakuniy saqlash/biriktirish uchun

  bool _isLoadingGroups = true;
  List<Map<String, String>> _groups = []; // [{id, name, subjectId}]
  List<Map<String, String>> _subjects = []; // YANGI: [{id, name}] — faqat guruhi bor fanlar
  String? _selectedSubjectTab; // YANGI: hozir qaysi fan tabi ochiq
  final Set<String> _selectedGroupIds = {};

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groupsSnap = await _db.collection('groups').orderBy('name').get();
      final groups = groupsSnap.docs.map((d) => {
        'id': d.id,
        'name': (d.data()['name'] ?? 'Nomsiz guruh').toString(),
        'subjectId': (d.data()['subjectId'] ?? '').toString(),
      }).toList();

      // YANGI: guruhlarni fan bo'yicha "tab"larga ajratish uchun —
      // guruhlarda ISHTIROK ETGAN fanlarning nomlarini olamiz.
      final usedSubjectIds = groups.map((g) => g['subjectId']!).where((id) => id.isNotEmpty).toSet();
      final Map<String, String> subjectNames = {};
      if (usedSubjectIds.isNotEmpty) {
        final idsList = usedSubjectIds.toList();
        for (var i = 0; i < idsList.length; i += 10) {
          final end = (i + 10 > idsList.length) ? idsList.length : i + 10;
          final chunk = idsList.sublist(i, end);
          final subSnap = await _db.collection('center_subjects').where(FieldPath.documentId, whereIn: chunk).get();
          for (var doc in subSnap.docs) {
            subjectNames[doc.id] = (doc.data()['name'] ?? 'Nomsiz fan').toString();
          }
        }
      }

      final subjects = usedSubjectIds.map((id) => {'id': id, 'name': subjectNames[id] ?? 'Nomsiz fan'}).toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));

      setState(() {
        _groups = groups;
        _subjects = subjects;
        _selectedSubjectTab = subjects.isNotEmpty ? subjects.first['id'] : null; // birinchi fan avtomatik ochiladi
        _isLoadingGroups = false;
      });
    } catch (e) {
      setState(() => _isLoadingGroups = false);
    }
  }

  // YANGI: guruh ID'sidan nomini topadi — qidiruv natijalarida "allaqachon
  // qaysi guruh(lar)da" degan belgini ko'rsatish uchun kerak.
  String? _groupNameById(String id) {
    for (final g in _groups) {
      if (g['id'] == id) return g['name'];
    }
    return null;
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _isSearching = true);
      try {
        final snap = await _db.collection('students').get();
        final matches = snap.docs.where((doc) {
          final data = doc.data();
          if (data['isArchived'] == true) return false;
          final fullName = "${data['lastName'] ?? ''} ${data['firstName'] ?? ''}".toLowerCase();
          return fullName.contains(q);
        }).map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'firstName': (data['firstName'] ?? '').toString(),
            'lastName': (data['lastName'] ?? '').toString(),
            'phone': (data['phone'] ?? '').toString(),
            'centerGroupIds': List<String>.from(data['centerGroupIds'] ?? []),
          };
        }).toList();

        if (!mounted) return;
        setState(() {
          _results = matches;
          _isSearching = false;
        });
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<bool> _duplicateNameExists() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) return false;

    final snap = await _db
        .collection('students')
        .where('firstName', isEqualTo: firstName)
        .where('lastName', isEqualTo: lastName)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Map<String, dynamic> _buildJoinDatesForSelectedGroups() {
    final Map<String, dynamic> result = {};
    for (final groupId in _selectedGroupIds) {
      final group = _groups.firstWhere((g) => g['id'] == groupId, orElse: () => {});
      final subjectId = group['subjectId'];
      if (subjectId != null && subjectId.isNotEmpty) {
        result[subjectId] = Timestamp.fromDate(_joinedDate);
      }
    }
    return result;
  }

  // YANGI: qidiruvdan bir o'quvchi tanlansa — DARHOL biriktirmaymiz,
  // avval GURUH TANLASH bosqichiga o'tamiz.
  void _selectStudentForLinking(Map<String, dynamic> student) {
    setState(() {
      _pendingLinkStudent = student;
      _showGroupPick = true;
    });
  }

  // YANGI: "Yangi o'quvchi" formasida "Keyingi" bosilganda — avval
  // ism/familiya to'ldirilganini va dublikat emasligini tekshiradi,
  // shundan KEYINGINA guruh tanlash bosqichiga o'tkazadi.
  Future<void> _proceedToGroupPickFromNewForm() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      Get.snackbar("Diqqat", "Ismi va familiyasini kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    setState(() => _isCheckingBeforeNext = true);
    final isDuplicate = await _duplicateNameExists();
    if (!mounted) return;
    setState(() => _isCheckingBeforeNext = false);

    if (isDuplicate) {
      Get.snackbar("Diqqat", "Bunday ism-familiyali o'quvchi allaqachon mavjud", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    setState(() => _showGroupPick = true);
  }

  // YANGI: yakuniy "Saqlash" — ikkala yo'l uchun ham shu yerda hal
  // qilinadi: agar qidiruvdan kelingan bo'lsa -> biriktirish, aks
  // holda -> yangi hujjat yaratish.
  Future<void> _handleFinalSave() async {
    if (_selectedGroupIds.isEmpty) {
      Get.snackbar("Diqqat", "Kamida bitta guruh tanlang", backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    setState(() => _isSaving = true);

    if (_pendingLinkStudent != null) {
      await _linkExisting(_pendingLinkStudent!);
    } else {
      await _saveNewStudent();
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _linkExisting(Map<String, dynamic> student) async {
    try {
      final existingGroupIds = List<String>.from(student['centerGroupIds'] ?? []);
      final newGroupIds = {...existingGroupIds, ..._selectedGroupIds}.toList();

      final updateData = <String, dynamic>{'centerGroupIds': newGroupIds};
      final joinDates = _buildJoinDatesForSelectedGroups();
      for (final entry in joinDates.entries) {
        updateData['centerSubjectJoinDates.${entry.key}'] = entry.value;
      }

      await _db.collection('students').doc(student['id']).update(updateData);

      if (!mounted) return;
      Get.snackbar("Bajarildi", "O'quvchi tanlangan guruh(lar)ga biriktirildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      widget.onSaved?.call();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar("Xatolik", "Biriktirishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
  }

  Future<void> _saveNewStudent() async {
    try {
      await _db.collection('students').add({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'parentPhone': _parentPhoneController.text.trim(),
        'isPrivileged': _isPrivileged,
        'centerGroupIds': _selectedGroupIds.toList(),
        'centerSubjectJoinDates': _buildJoinDatesForSelectedGroups(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Get.snackbar("Bajarildi", "Yangi o'quvchi qo'shildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      widget.onSaved?.call();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar("Xatolik", "Saqlashda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
  }

  // YANGI: orqaga — guruh tanlash bosqichidan chiqsa, avvalgi
  // bosqichga (qidiruv yoki forma) qaytadi, ekranni yopmaydi.
  void _goBack() {
    if (_showGroupPick) {
      setState(() {
        _showGroupPick = false;
        _pendingLinkStudent = null;
      });
    } else if (_showNewForm) {
      setState(() => _showNewForm = false);
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Get.back();
      }
    }
  }

  Widget _buildGroupPicker() {
    if (_isLoadingGroups) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981))),
      );
    }
    if (_groups.isEmpty) {
      return const Text("Guruhlar topilmadi", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13));
    }

    // YANGI: tanlangan fan tabiga tegishli guruhlarni filtrlaymiz.
    final groupsForSelectedSubject = _groups.where((g) => g['subjectId'] == _selectedSubjectTab).toList();
    final selectedCountInThisSubject = groupsForSelectedSubject.where((g) => _selectedGroupIds.contains(g['id'])).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- FAN TABLARI ---
        if (_subjects.length > 1)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _subjects.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final subj = _subjects[i];
                final isActive = subj['id'] == _selectedSubjectTab;
                final countInSubj = _groups.where((g) => g['subjectId'] == subj['id'] && _selectedGroupIds.contains(g['id'])).length;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedSubjectTab = subj['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(subj['name']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF334155))),
                        if (countInSubj > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: isActive ? Colors.white.withOpacity(0.25) : const Color(0xFF10B981).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text("$countInSubj", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF10B981))),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_subjects.length > 1) const SizedBox(height: 14),

        // --- TANLANGAN FANNING GURUHLARI ---
        if (selectedCountInThisSubject > 0) ...[
          Text("$selectedCountInThisSubject ta guruh tanlandi", style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        if (groupsForSelectedSubject.isEmpty)
          const Text("Bu fanda guruh topilmadi", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groupsForSelectedSubject.map((g) {
              final selected = _selectedGroupIds.contains(g['id']);
              // YANGI: agar qidiruvdan kelingan (mavjud) o'quvchi
              // ALLAQACHON shu guruhda bo'lsa — buni belgilaymiz.
              final existingGroupIds = _pendingLinkStudent != null
                  ? List<String>.from(_pendingLinkStudent!['centerGroupIds'] ?? [])
                  : <String>[];
              final alreadyMember = existingGroupIds.contains(g['id']);

              return InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: alreadyMember
                    ? null // allaqachon a'zo bo'lsa — qayta tanlash shart emas
                    : () => setState(() {
                  if (selected) {
                    _selectedGroupIds.remove(g['id']);
                  } else {
                    _selectedGroupIds.add(g['id']!);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: alreadyMember
                        ? const Color(0xFFF1F5F9)
                        : (selected ? const Color(0xFF10B981) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: alreadyMember ? const Color(0xFFCBD5E1) : (selected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected && !alreadyMember) ...[
                        const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        g['name']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: alreadyMember ? const Color(0xFF94A3B8) : (selected ? Colors.white : const Color(0xFF334155)),
                        ),
                      ),
                      // YANGI: "A'zo" belgisi — allaqachon shu guruhda bo'lsa.
                      if (alreadyMember) ...[
                        const SizedBox(width: 5),
                        const Text("(a'zo)", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = _showGroupPick
        ? "Guruh(lar)ni tanlang"
        : (_showNewForm ? "Yangi o'quvchi" : "O'quvchini qidirish");

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 17)),
        leading: (_showGroupPick || _showNewForm)
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _goBack)
            : null,
      ),
      body: SafeArea(
        child: _showGroupPick
            ? _buildGroupPickStep()
            : (_showNewForm ? _buildNewForm() : _buildSearch()),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))]),
        child: _buildBottomButton(),
      ),
    );
  }

  Widget _buildBottomButton() {
    if (_showGroupPick) {
      // 2-QADAM: yakuniy "Saqlash".
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isSaving ? null : _handleFinalSave,
          child: _isSaving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Text("Saqlash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
    if (_showNewForm) {
      // 1-QADAM (yangi forma): "Keyingi" — guruh tanlashga o'tkazadi.
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _isCheckingBeforeNext ? null : _proceedToGroupPickFromNewForm,
          child: _isCheckingBeforeNext
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Text("Keyingi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
    // 1-QADAM (qidiruv): "Yangi o'quvchi qo'shish" formaga o'tkazadi.
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: () => setState(() => _showNewForm = true),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF10B981)),
        label: const Text("Yangi o'quvchi qo'shish", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
      ),
    );
  }

  // YANGI: 2-QADAM ekrani — kim uchun tanlanayotgani ko'rsatiladi,
  // so'ng guruh chiplar.
  Widget _buildGroupPickStep() {
    final String forWhom = _pendingLinkStudent != null
        ? "${_pendingLinkStudent!['lastName']} ${_pendingLinkStudent!['firstName']}".trim()
        : "${_lastNameController.text.trim()} ${_firstNameController.text.trim()}".trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFA7F3D0))),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(forWhom.isEmpty ? "O'quvchi" : forWhom, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 15)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Qaysi guruh(lar)ga qo'shiladi", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13)),
          const SizedBox(height: 10),
          _buildGroupPicker(),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Agar bu o'quvchi allaqachon ro'yxatdan o'tgan bo'lsa, uni shu yerdan toping",
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
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
              final fullName = "${s['lastName']} ${s['firstName']}".trim();

              // YANGI: shu o'quvchi allaqachon a'zo bo'lgan guruhlar
              // nomlarini yig'amiz — qidiruv natijasida ko'rsatish uchun.
              final existingGroupIds = List<String>.from(s['centerGroupIds'] ?? []);
              final existingGroupNames = existingGroupIds
                  .map((id) => _groupNameById(id))
                  .whereType<String>()
                  .toList();

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _selectStudentForLinking(s),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: const Color(0xFF10B981).withOpacity(0.12), child: const Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName.isEmpty ? "Nomsiz" : fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B))),
                            if ((s['phone'] as String).isNotEmpty) Text(s['phone'], style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                            // YANGI: "Allaqachon: Matematika-1, Fizika-2" —
                            // agar bu o'quvchi biror guruhda bo'lsa.
                            if (existingGroupNames.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  "Allaqachon: ${existingGroupNames.join(', ')}",
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
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

  Widget _buildNewForm() {
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
                  controller: _firstNameController,
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
                  controller: _lastNameController,
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
            controller: _phoneController,
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
            controller: _parentPhoneController,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Imtiyozli (To'lovdan ozod)", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF0F172A), fontSize: 14)),
                Switch.adaptive(
                  value: _isPrivileged,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) => setState(() => _isPrivileged = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _joinedDate, firstDate: DateTime(2023), lastDate: DateTime(2030));
              if (picked != null) setState(() => _joinedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Text("Kelgan sana: ${DateFormat('dd.MM.yyyy').format(_joinedDate)}"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}