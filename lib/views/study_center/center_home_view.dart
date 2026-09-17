import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart'; // YANGI: fanlar tartibini LOKAL saqlash uchun

import '../../controllers/center/center_absentees_controller.dart';
import '../../controllers/center/center_subject_controller.dart';
import '../../services/get_helper.dart'; // MUHIM: haqiqiy yo'lingizga moslang
import 'center_group_list_view.dart';
import 'center_absentees_view.dart';
import 'center_all_students_view.dart';
import '../../widgets/add_center_student_dialog.dart'; // YANGI: "O'quvchi qo'shish" endi shu yerdan chaqiriladi

/// O'QUV MARKAZ bo'limining bosh sahifasi — bottom navigation bilan
/// 3 ta bo'lim:
///   0. Fanlar — markazdagi barcha fanlar ro'yxati (bosilsa —
///      CenterGroupListView: shu fandagi guruhlar, o'zgarishsiz).
///   1. Kelmaganlar — bugun kelmagan o'quvchisi bor guruhlar
///      (markaz bo'ylab, fanlarga qaramasdan).
///   2. Umumiy talabalar — markazdagi barcha o'quvchi, qidiruv bilan.
///
/// YANGI: "Fanlar" ro'yxatida endi UZOQ BOSIB TORTISH orqali tartibni
/// o'zgartirish mumkin (ReorderableListView — bu long-press'ni o'zi
/// avtomatik boshqaradi). Tartib FAQAT LOKAL saqlanadi (GetStorage) —
/// Firestore'ga HECH NARSA yozilmaydi, boshqa qurilmada standart
/// (alifbo) tartib ko'rinadi. Fanlarni yuklash/qo'shish/tahrirlash/
/// o'chirish mantig'iga HECH NARSA tegilmadi.
///
/// YANGI (SMS TANLASH): "Umumiy talabalar" tabida CenterAllStudentsTab
/// endi o'quvchilarni ko'p tanlash (uzoq bosish) rejimini qo'llab-
/// quvvatlaydi — shu payt "O'quvchi qo'shish" FAB'i chalg'itmasligi
/// va tanlov panel bilan bir joyga tushib qolmasligi uchun
/// `_hideStudentFab` orqali VAQTINCHA yashiriladi.
class CenterHomeView extends StatefulWidget {
  const CenterHomeView({super.key});

  @override
  State<CenterHomeView> createState() => _CenterHomeViewState();
}

class _CenterHomeViewState extends State<CenterHomeView> {
  int _tabIndex = 0;

  // YANGI: fanlar tartibini lokal saqlash.
  final GetStorage _localBox = GetStorage();
  static const String _subjectOrderKey = 'center_subjects_local_order';
  List<String> _localOrder = [];

  // YANGI: "Umumiy talabalar" tabidagi qidiruv — endi YAGONA AppBar'da
  // (avval CenterAllStudentsTab'ning o'z AppBar'i bo'lib, ikkitasi
  // ustma-ust chiqib "2 ta AppBar" ko'rinishini berardi).
  bool _isSearchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // YANGI (SMS TANLASH): CenterAllStudentsTab'da o'quvchi(lar) tanlangan
  // paytda true bo'ladi — shu payt "O'quvchi qo'shish" FAB'i yashiriladi.
  bool _hideStudentFab = false;

  @override
  void initState() {
    super.initState();
    final saved = _localBox.read<List>(_subjectOrderKey);
    if (saved != null) _localOrder = saved.cast<String>();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Berilgan (allaqachon alifbo bo'yicha saralangan) hujjatlar
  /// ro'yxatiga LOKAL saqlangan tartibni qo'llaydi. Hali tartibda
  /// yo'q (masalan yangi qo'shilgan) fanlar oxiriga qo'shiladi.
  List<QueryDocumentSnapshot> _applyLocalOrder(List<QueryDocumentSnapshot> docs) {
    if (_localOrder.isEmpty) return docs;

    final byId = {for (final d in docs) d.id: d};
    final ordered = <QueryDocumentSnapshot>[];

    for (final id in _localOrder) {
      final doc = byId.remove(id);
      if (doc != null) ordered.add(doc);
    }
    ordered.addAll(byId.values); // yangi/tartibda bo'lmaganlar oxirida

    return ordered;
  }

  Future<void> _onReorderSubjects(List<QueryDocumentSnapshot> currentDocs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1; // ReorderableListView'ning standart talabi

    final newOrderDocs = List<QueryDocumentSnapshot>.from(currentDocs);
    final moved = newOrderDocs.removeAt(oldIndex);
    newOrderDocs.insert(newIndex, moved);

    final newOrderIds = newOrderDocs.map((d) => d.id).toList();

    setState(() => _localOrder = newOrderIds);
    await _localBox.write(_subjectOrderKey, newOrderIds);
  }

  void _showSubjectDialog(
      BuildContext context,
      CenterSubjectController controller, {
        String? docId,
        String? oldName,
        bool oldIsEnglish = false,
      }) {
    controller.subjectNameController.clear();
    if (docId != null && oldName != null) {
      controller.subjectNameController.text = oldName;
    }
    final bool isEdit = docId != null;

    // YANGI: dialog ichidagi Switch holati — dialog o'zi
    // StatelessWidget ichida chaqirilgani uchun, uni almashtirish
    // (setState) mumkin bo'lishi uchun StatefulBuilder bilan o'raymiz.
    bool isEnglishChecked = oldIsEnglish;

    Get.dialog(
      StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
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
                      Text(isEdit ? "Fanni tahrirlash" : "Yangi fan qo'shish",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      IconButton(icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20), onPressed: () => Get.back()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller.subjectNameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Fan nomi (masalan: Matematika)",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // YANGI: "Ingliz tili fani" bayrog'i — belgilansa, shu
                  // fan ostidagi har bir guruh ekranida (GroupDetailView)
                  // qo'shimcha "Daily Task" va "IELTS/CEFR" bo'limlari
                  // avtomatik chiqadi.
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setDialogState(() => isEnglishChecked = !isEnglishChecked),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isEnglishChecked ? const Color(0xFF10B981).withOpacity(0.08) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isEnglishChecked ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.language_rounded, size: 20, color: isEnglishChecked ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Bu — Ingliz tili fani",
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: isEnglishChecked ? const Color(0xFF10B981) : const Color(0xFF334155)),
                            ),
                          ),
                          Switch(
                            value: isEnglishChecked,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) => setDialogState(() => isEnglishChecked = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Belgilansa, shu fan guruhlarida qo'shimcha \"Daily Task\" va \"IELTS/CEFR\" bo'limlari chiqadi.",
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.35),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      // YANGI: endi isEnglishChecked qiymati ham
                      // controller'ga uzatiladi. MUHIM (TODO):
                      // CenterSubjectController.addSubject() va
                      // .updateSubject() metodlari 'isEnglish' nomli
                      // parametrni qabul qilib, uni Firestore
                      // hujjatiga yozadigan qilib yangilanishi kerak.
                      onPressed: () => isEdit
                          ? controller.updateSubject(docId, oldName!, isEnglish: isEnglishChecked)
                          : controller.addSubject(isEnglish: isEnglishChecked),
                      child: Text(isEdit ? "Saqlash" : "Qo'shish", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  void _confirmDeleteSubject(
      BuildContext context,
      CenterSubjectController controller,
      String docId,
      String name,
      ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                    child: Text("Fanni o'chirish",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "\"$name\" fanini o'chirmoqchimisiz? Fan ichidagi guruhlar ham ko'rinmay qoladi.",
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF64748B), height: 1.4),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => Get.back(),
                      child: const Text("Bekor qilish",
                          style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () => controller.deleteSubject(docId),
                      child: const Text("O'chirish",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildSubjectsTab(BuildContext context, CenterSubjectController controller) {
    return StreamBuilder<QuerySnapshot>(
      stream: controller.subjectsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Text("Fanlarni yuklashda xato",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText("${snapshot.error}",
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF991B1B),
                          fontFamily: 'monospace')),
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
                  decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.08),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.menu_book_outlined,
                      size: 40, color: Color(0xFF10B981)),
                ),
                const SizedBox(height: 16),
                const Text("Hozircha fanlar yo'q",
                    style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text("Pastdagi tugma orqali birinchi fanni yarating",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
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

        // YANGI: ListView.builder o'rniga ReorderableListView.builder —
        // uzoq bosib tortish orqali qator joyini o'zgartirish uchun
        // (bu — Flutter'ning o'zida tayyor, qo'shimcha sozlash kerak
        // emas). Har bir elementga UNIKAL Key kerak.
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: docs.length,
          onReorder: (oldIndex, newIndex) => _onReorderSubjects(docs, oldIndex, newIndex),
          // YANGI: tortilayotgan qatorning ko'rinishini yumshoqroq
          // qildik — Flutter'ning standart (qo'pol, keskin soyali)
          // ko'rinishi o'rniga, ilovaning uslubiga mos, silliq
          // kattalashuvchi va yumaloq burchakli soyani ishlatadi.
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
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Nomsiz fan';

            return Material(
              key: ValueKey(doc.id), // YANGI: ReorderableListView uchun shart
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Get.to(() =>
                    CenterGroupListView(subjectId: doc.id, subjectName: name)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFF10B981).withOpacity(0.15),
                            const Color(0xFF10B981).withOpacity(0.06),
                          ]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                fontSize: 15.5)),
                      ),
                      // YANGI: tortish uchun ushlab turish belgisi —
                      // foydalanuvchiga qator ko'chirilishi mumkinligini
                      // ko'rsatadi.
                      const Icon(Icons.drag_handle_rounded, color: Color(0xFFCBD5E1), size: 20),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Color(0xFF94A3B8)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showSubjectDialog(context, controller,
                                docId: doc.id, oldName: name);
                          } else if (value == 'delete') {
                            _confirmDeleteSubject(context, controller, doc.id, name);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined,
                                    size: 18, color: Color(0xFF3B82F6)),
                                SizedBox(width: 10),
                                Text("Tahrirlash")
                              ])),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Color(0xFFDC2626)),
                                SizedBox(width: 10),
                                Text("O'chirish",
                                    style: TextStyle(color: Color(0xFFDC2626)))
                              ])),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectController = putOnce(
          () => CenterSubjectController(),
      tag: 'center_subjects',
    );
    final absenteesController = putOnce(
          () => CenterAbsenteesController(),
      tag: 'center_absentees_all',
    );

    final titles = ["Fanlar", "Kelmaganlar", "Umumiy talabalar"];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // YANGI: "Umumiy talabalar" tabida, qidiruv yoqilgan bo'lsa —
        // sarlavha o'rniga qidiruv maydoni ko'rsatiladi.
        title: (_tabIndex == 2 && _isSearchActive)
            ? TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: const InputDecoration(
            hintText: "Ism yoki familiya bo'yicha qidirish...",
            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
        )
            : Text(titles[_tabIndex],
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        // YANGI: qidiruv tugmasi — faqat "Umumiy talabalar" tabida.
        actions: _tabIndex == 2
            ? [
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close_rounded : Icons.search_rounded, color: const Color(0xFF64748B)),
            onPressed: () => setState(() {
              if (_isSearchActive) {
                _searchCtrl.clear();
                _searchQuery = '';
              }
              _isSearchActive = !_isSearchActive;
            }),
          ),
        ]
            : null,
      ),
      // YANGI (SMS TANLASH): "Talabalar" tabidagi FAB endi
      // `_hideStudentFab` true bo'lsa (ya'ni CenterAllStudentsTab'da
      // kamida 1 ta o'quvchi tanlangan bo'lsa) ko'rinmaydi — aks holda
      // u bizning pastdagi tanlov paneli bilan bir joyga tushib
      // qolardi.
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => _showSubjectDialog(context, subjectController),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : (_tabIndex == 2 && !_hideStudentFab
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => showAddCenterStudentScreen(context, onSaved: () => setState(() {})),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      )
          : null),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildSubjectsTab(context, subjectController),
          const CenterAbsenteesTab(),
          // YANGI (SMS TANLASH): tanlov holati o'zgarganda (bo'sh <->
          // to'la) shu callback orqali `_hideStudentFab`ni yangilaymiz.
          CenterAllStudentsTab(
            searchQuery: _searchQuery,
            onSelectionModeChanged: (isSelecting) {
              if (_hideStudentFab != isSelecting) {
                setState(() => _hideStudentFab = isSelecting);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: Obx(
            () => BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() {
            _tabIndex = i;
            // YANGI: boshqa tabga o'tilganda qidiruv holati tozalanadi.
            if (i != 2) {
              _isSearchActive = false;
              _searchCtrl.clear();
              _searchQuery = '';
            }
          }),
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF94A3B8),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_rounded), label: "Fanlar"),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text('${absenteesController.totalAbsentToday}'),
                isLabelVisible: absenteesController.totalAbsentToday > 0,
                backgroundColor: const Color(0xFFDC2626),
                child: const Icon(Icons.person_off_rounded),
              ),
              label: "Kelmaganlar",
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_rounded), label: "Talabalar"),
          ],
        ),
      ),
    );
  }
}