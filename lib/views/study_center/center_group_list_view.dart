import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart'; // YANGI: guruhlar tartibini LOKAL saqlash uchun
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/center/center_group_controller.dart';
import '../../services/get_helper.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang
import 'group_detail_view.dart';

/// BITTA FAN ICHIDAGI guruhlar ro'yxati (masalan "Matematika" fani
/// ichida "Matematika-1", "Matematika-2"). Guruhga bosilsa —
/// GroupDetailView (Davomat/Imtihonlar) ochiladi — bu o'zgarishsiz.
///
/// YANGI: "Fanlar" ro'yxatidagi kabi — UZOQ BOSIB TORTISH orqali
/// guruhlar tartibini o'zgartirish mumkin. Tartib FAQAT LOKAL
/// saqlanadi (GetStorage, har bir FAN uchun ALOHIDA kalit) —
/// Firestore'ga hech narsa yozilmaydi. Guruh qo'shish/tahrirlash/
/// o'chirish mantig'iga HECH NARSA tegilmadi.
///
/// YANA YANGI: AppBar'da "tanlash" tugmasi — bosilganda har bir
/// guruh oldida checkbox chiqadi, bir nechta guruh tanlab, ular
/// bo'yicha Excel hisobot (har bir guruh — alohida sahifa; har bir
/// talaba: F.I.Sh., shu guruhga qo'shilgan sana, to'lagan summasi,
/// qarzdorligi) yaratib, ulashish mumkin.
class CenterGroupListView extends StatefulWidget {
  final String subjectId;
  final String subjectName;

  const CenterGroupListView({super.key, required this.subjectId, required this.subjectName});

  @override
  State<CenterGroupListView> createState() => _CenterGroupListViewState();
}

class _CenterGroupListViewState extends State<CenterGroupListView> {
  // YANGI: guruhlar tartibini lokal saqlash — har bir FAN uchun
  // ALOHIDA kalit (subjectId bilan), shunda turli fanlarning
  // tartiblari aralashmaydi.
  final GetStorage _localBox = GetStorage();
  late final String _orderKey = 'center_groups_local_order_${widget.subjectId}';
  List<String> _localOrder = [];

  // YANGI: guruhlarni tanlash rejimi va tanlangan guruhlar (id -> nomi).
  bool _selectionMode = false;
  final Map<String, String> _selectedGroups = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final saved = _localBox.read<List>(_orderKey);
    if (saved != null) _localOrder = saved.cast<String>();
  }

  List<QueryDocumentSnapshot> _applyLocalOrder(List<QueryDocumentSnapshot> docs) {
    if (_localOrder.isEmpty) return docs;

    final byId = {for (final d in docs) d.id: d};
    final ordered = <QueryDocumentSnapshot>[];

    for (final id in _localOrder) {
      final doc = byId.remove(id);
      if (doc != null) ordered.add(doc);
    }
    ordered.addAll(byId.values);

    return ordered;
  }

  Future<void> _onReorderGroups(List<QueryDocumentSnapshot> currentDocs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final newOrderDocs = List<QueryDocumentSnapshot>.from(currentDocs);
    final moved = newOrderDocs.removeAt(oldIndex);
    newOrderDocs.insert(newIndex, moved);

    final newOrderIds = newOrderDocs.map((d) => d.id).toList();

    setState(() => _localOrder = newOrderIds);
    await _localBox.write(_orderKey, newOrderIds);
  }

  // ===================== YANGI: TANLASH REJIMI =====================

  void _enterSelectionMode() {
    setState(() => _selectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedGroups.clear();
    });
  }

  void _toggleGroupSelection(String groupId, String groupName) {
    setState(() {
      if (_selectedGroups.containsKey(groupId)) {
        _selectedGroups.remove(groupId);
      } else {
        _selectedGroups[groupId] = groupName;
      }
    });
  }

  // ===================== YANGI: EXCEL EKSPORT =====================

  /// Bitta talaba uchun hisobot qatori.
  ///
  /// MUHIM: `joinedAt`, `totalPaid` va `debt` qanday hisoblanishi
  /// sizning Firestore tuzilishingizga bog'liq — pastdagi
  /// `_fetchStudentsReportForGroup` metodidagi TAXMINIY so'rovlarni
  /// o'zingizning haqiqiy to'plam/field nomlaringizga moslang.
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _sanitizeSheetName(String name) {
    // Excel sahifa nomida quyidagi belgilar taqiqlangan: : \ / ? * [ ]
    var sanitized = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), '-').trim();
    if (sanitized.length > 31) sanitized = sanitized.substring(0, 31);
    return sanitized.isEmpty ? 'Guruh' : sanitized;
  }

  /// TAXMINIY SO'ROV — sizning haqiqiy talabalar/to'lovlar
  /// tuzilishingizga moslab tekshiring/o'zgartiring:
  ///  - 'students' to'plami va 'groupId' fieldi (talaba shu guruhda
  ///    ekanini bildiradi)
  ///  - 'joinedAt' fieldi (Timestamp) — talaba shu guruhga qachon
  ///    qo'shilgani (agar bu ma'lumot boshqa joyda — masalan
  ///    subject bo'yicha alohida saqlansa, shu yerni moslang)
  ///  - 'payments' to'plami, 'studentId' va 'forSubjectId'/'groupId'
  ///    fieldlari — shu talabaning shu guruh/fan uchun to'lovlari
  ///  - qarzdorlik — hozircha "kutilayotgan oylik to'lov" 0 qilib
  ///    qo'yilgan (expectedAmount), buni o'zingizning narx/tarif
  ///    mantig'ingiz bilan almashtiring (masalan guruh yoki fan
  ///    hujjatidagi 'monthlyFee' fieldidan olib, totalPaid bilan
  ///    solishtiring)
  Future<List<_StudentReportRow>> _fetchStudentsReportForGroup(String groupId) async {
    final firestore = FirebaseFirestore.instance;

    final studentsSnap = await firestore
        .collection('students')
        .where('groupId', isEqualTo: groupId)
        .get();

    // MUVAQQAT: 'students'/'groupId' taxminiy nomlar to'g'ri kelmasa,
    // bu yerda 0 ta hujjat qaytadi — shuning uchun talaba ma'lumoti
    // Excel'da chiqmayapti. Konsolda tekshiring:
    debugPrint('[Excel export] groupId=$groupId uchun topilgan talabalar soni: ${studentsSnap.docs.length}');

    final rows = <_StudentReportRow>[];

    for (final studentDoc in studentsSnap.docs) {
      final studentData = studentDoc.data();
      final fullName = (studentData['fullName'] ?? studentData['name'] ?? "Noma'lum").toString();

      final Timestamp? joinedTs = studentData['joinedAt'] as Timestamp?;
      final joinedAt = joinedTs?.toDate();

      final paymentsSnap = await firestore
          .collection('payments')
          .where('studentId', isEqualTo: studentDoc.id)
          .where('forSubjectId', isEqualTo: widget.subjectId) // yoki groupId — o'zingizga moslang
          .get();

      num totalPaid = 0;
      for (final p in paymentsSnap.docs) {
        totalPaid += (p.data()['amount'] as num? ?? 0);
      }

      // TODO: kutilayotgan (oylik) to'lov summasini haqiqiy manbadan oling.
      const num expectedAmount = 0;
      final num debt = (expectedAmount - totalPaid) < 0 ? 0 : (expectedAmount - totalPaid);

      rows.add(_StudentReportRow(
        fullName: fullName,
        joinedAt: joinedAt,
        totalPaid: totalPaid,
        debt: debt,
      ));
    }

    return rows;
  }

  Future<void> _exportSelectedGroupsToExcel() async {
    if (_selectedGroups.isEmpty || _isExporting) return;

    setState(() => _isExporting = true);

    try {
      final workbook = excel_lib.Excel.createExcel();
      final defaultSheetName = workbook.getDefaultSheet();

      for (final entry in _selectedGroups.entries) {
        final groupId = entry.key;
        final groupName = entry.value;
        final rows = await _fetchStudentsReportForGroup(groupId);

        final sheet = workbook[_sanitizeSheetName(groupName)];

        // Sarlavha qatori — guruh nomi
        sheet.appendRow([excel_lib.TextCellValue(groupName)]);
        sheet.appendRow([]);

        // Ustunlar sarlavhasi
        sheet.appendRow([
          excel_lib.TextCellValue("F.I.Sh."),
          excel_lib.TextCellValue("Guruhga qo'shilgan sana"),
          excel_lib.TextCellValue("To'langan summa"),
          excel_lib.TextCellValue("Qarzdorlik"),
        ]);

        for (final row in rows) {
          sheet.appendRow([
            excel_lib.TextCellValue(row.fullName),
            excel_lib.TextCellValue(row.joinedAt != null ? _formatDate(row.joinedAt!) : '-'),
            excel_lib.TextCellValue(row.totalPaid.toString()),
            excel_lib.TextCellValue(row.debt > 0 ? "Qarzdor: ${row.debt}" : "Qarzi yo'q"),
          ]);
        }
      }

      if (defaultSheetName != null) {
        workbook.delete(defaultSheetName);
      }

      final bytes = workbook.encode();
      if (bytes == null) throw Exception("Excel fayl kodlanmadi");

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/guruhlar_hisobot_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(filePath)], text: "Guruhlar bo'yicha hisobot — ${widget.subjectName}");

      _exitSelectionMode();
    } catch (e) {
      Get.snackbar(
        "Xato",
        "Excel yaratishda xatolik yuz berdi: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFFEF2F2),
        colorText: const Color(0xFF991B1B),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ===================== MAVJUD: DIALOGLAR =====================

  void _showGroupDialog(BuildContext context, CenterGroupController controller, {String? docId, String? oldName}) {
    controller.groupNameController.clear();
    if (docId != null && oldName != null) {
      controller.groupNameController.text = oldName;
    }
    final bool isEdit = docId != null;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEdit ? "Guruhni tahrirlash" : "Yangi guruh qo'shish",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  IconButton(icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20), onPressed: () => Get.back()),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.subjectName, style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),
              TextField(
                controller: controller.groupNameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Guruh nomi (masalan: ${widget.subjectName}-1)",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => isEdit ? controller.updateGroup(docId, oldName!) : controller.addGroup(),
                  child: Text(isEdit ? "Saqlash" : "Qo'shish", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, CenterGroupController controller, String docId, String name) {
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
                const Expanded(child: Text("Guruhni o'chirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "\"$name\" guruhini o'chirmoqchimisiz? Guruh o'chadi, lekin o'quvchilarning shaxsiy ma'lumotlari saqlanib qoladi.",
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => controller.deleteGroup(docId),
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

  // ===================== YANGI: BITTA GURUH KARTASI =====================
  // Checkbox tanlash rejimi va oddiy rejim uchun umumiy widget.

  Widget _buildGroupTile(BuildContext context, CenterGroupController controller, QueryDocumentSnapshot doc, {Key? key}) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Nomsiz guruh';
    final bool isSelected = _selectedGroups.containsKey(doc.id);

    return Material(
      key: key ?? ValueKey(doc.id),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _selectionMode
            ? () => _toggleGroupSelection(doc.id, name)
            : () => Get.to(() => GroupDetailView(groupId: doc.id, groupName: name, subjectId: widget.subjectId)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFFEEF2F6), width: isSelected ? 1.5 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              if (_selectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (_) => _toggleGroupSelection(doc.id, name),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981).withOpacity(0.06)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15.5)),
              ),
              if (!_selectionMode) ...[
                // YANGI: tortish uchun ushlab turish belgisi.
                const Icon(Icons.drag_handle_rounded, color: Color(0xFFCBD5E1), size: 20),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showGroupDialog(context, controller, docId: doc.id, oldName: name);
                    } else if (value == 'delete') {
                      _confirmDeleteGroup(context, controller, doc.id, name);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 10), Text("Tahrirlash")])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text("O'chirish", style: TextStyle(color: Color(0xFFDC2626)))])),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = putOnce(() => CenterGroupController(subjectId: widget.subjectId), tag: 'center_groups_${widget.subjectId}');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)), onPressed: _exitSelectionMode)
            : null,
        title: Text(
          _selectionMode ? "${_selectedGroups.length} ta tanlandi" : widget.subjectName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          if (!_selectionMode)
            IconButton(
              tooltip: "Guruhlarni tanlash",
              icon: const Icon(Icons.checklist_rounded, color: Color(0xFF0F172A)),
              onPressed: _enterSelectionMode,
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => _showGroupDialog(context, controller),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      // YANGI: checkbox orqali kamida bitta guruh tanlanganda pastdan
      // chiqadigan eksport tugmasi (baland-past animatsiya bilan).
      bottomNavigationBar: _selectionMode
          ? SafeArea(
        top: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: _selectedGroups.isEmpty ? 0 : 84,
          child: _selectedGroups.isEmpty
              ? const SizedBox.shrink()
              : Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isExporting ? null : _exportSelectedGroupsToExcel,
                icon: _isExporting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
                    : const Icon(Icons.ios_share_rounded, color: Colors.white),
                label: Text(
                  _isExporting ? "Tayyorlanmoqda..." : "Excel'ga eksport (${_selectedGroups.length} ta guruh)",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.groupsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }

          if (snapshot.hasError) {
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
                        Text("Guruhlarni yuklashda xato", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText("${snapshot.error}", style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontFamily: 'monospace')),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.groups_outlined, size: 40, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Bu fanda hozircha guruhlar yo'q", style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Pastdagi tugma orqali birinchi guruhni yarating", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            );
          }

          final alphabeticalDocs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final nameA = (a.data() as Map<String, dynamic>)['name'] ?? '';
              final nameB = (b.data() as Map<String, dynamic>)['name'] ?? '';
              return nameA.toString().compareTo(nameB.toString());
            });

          // YANGI: alifbo tartibi ustiga LOKAL saqlangan tartib qo'llanadi.
          final docs = _applyLocalOrder(alphabeticalDocs);

          // YANGI: tanlash rejimida oddiy ro'yxat (tortib joylashtirish
          // checkbox bosish bilan to'qnashmasligi uchun); aks holda —
          // avvalgidek ReorderableListView.
          if (_selectionMode) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: docs.length,
              itemBuilder: (context, index) => _buildGroupTile(context, controller, docs[index]),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) => _onReorderGroups(docs, oldIndex, newIndex),
            // YANGI: "Fanlar" ekranidagi bilan bir xil — silliq,
            // yumshoq tortish ko'rinishi (standart qo'pol soya o'rniga).
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final double scale = 1.0 + (animation.value * 0.025);
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      elevation: 4 * animation.value,
                      shadowColor: Colors.black.withOpacity(0.18),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) => _buildGroupTile(context, controller, docs[index], key: ValueKey(docs[index].id)),
          );
        },
      ),
    );
  }
}

/// YANGI: Excel hisobot uchun bitta talaba qatori.
class _StudentReportRow {
  final String fullName;
  final DateTime? joinedAt;
  final num totalPaid;
  final num debt;

  _StudentReportRow({
    required this.fullName,
    required this.joinedAt,
    required this.totalPaid,
    required this.debt,
  });
}