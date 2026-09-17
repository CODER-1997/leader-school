import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/center/center_subject_controller.dart';
import '../../services/get_helper.dart';
import 'center_group_list_view.dart'; // MUHIM: sizning haqiqiy yo'lingizga moslang


/// O'quv Markaz — endi FANLAR ro'yxati bilan boshlanadi (avval to'g'ridan
/// -to'g'ri guruhlar ko'rinardi). Fanga bosilsa — o'sha fan ICHIDAGI
/// guruhlar ro'yxati ochiladi (CenterGroupListView).
///
/// YANGI ("INGLIZ TILI FANI" BAYROG'I): fan qo'shish/tahrirlash
/// dialogida endi "Bu — Ingliz tili fani" degan yoqib-o'chiriladigan
/// tugma (Switch) bor. Yoqilsa, fan hujjatiga 'isEnglish: true' deb
/// saqlanadi (MUHIM: buni haqiqatda Firestore'ga yozish uchun
/// CenterSubjectController.addSubject()/updateSubject() metodlari
/// ham 'isEnglish' parametrini qabul qilib, hujjatga yozishi kerak —
/// controller fayli bu yerda yo'q, shuning uchun faqat CHAQIRUV
/// tomoni (bu fayl) tayyorlandi). Shu bayroq orqali GroupDetailView
/// (guruh ichidagi ekran) aynan shu fan guruhlarida qo'shimcha
/// "Daily Task" va "IELTS/CEFR" tab'larini avtomatik ko'rsatadi.
class CenterSubjectsView extends StatelessWidget {
  const CenterSubjectsView({super.key});
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


  void _confirmDeleteSubject(BuildContext context, CenterSubjectController controller, String docId, String name) {
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
                const Expanded(child: Text("Fanni o'chirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "\"$name\" fanini o'chirmoqchimisiz? Bu fan ICHIDAGI BARCHA guruhlar ham o'chadi (o'quvchilarning shaxsiy ma'lumotlari saqlanib qoladi).",
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
                      onPressed: () => controller.deleteSubject(docId),
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
    final controller = putOnce(() => CenterSubjectController(), tag: 'center_subjects');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("O'quv Markaz", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => _showSubjectDialog(context, controller),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.subjectsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Hozircha fanlar yo'q", style: TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text("Pastdagi tugma orqali birinchi fanni yarating", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Nomsiz fan';
              // YANGI: ro'yxatda ham shu fan Ingliz tili fani ekanini
              // bilib turish uchun (kichik yorliq) va tahrirlash
              // dialogini ochganda Switch'ning boshlang'ich holatini
              // to'g'ri ko'rsatish uchun.
              final bool isEnglishSubject = data['isEnglish'] == true;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Get.to(() => CenterGroupListView(subjectId: doc.id, subjectName: name)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.15), const Color(0xFF10B981).withOpacity(0.06)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15.5), overflow: TextOverflow.ellipsis),
                              ),
                              // YANGI: "Ingliz tili fani" bo'lsa, kichik
                              // yorliq bilan belgilaymiz — ro'yxatdan
                              // darrov ko'rinib tursin.
                              if (isEnglishSubject) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                  child: const Text("EN", style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10.5, fontWeight: FontWeight.w700)),
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
                              _showSubjectDialog(context, controller, docId: doc.id, oldName: name, oldIsEnglish: isEnglishSubject);
                            } else if (value == 'delete') {
                              _confirmDeleteSubject(context, controller, doc.id, name);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 10), Text("Tahrirlash")])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)), SizedBox(width: 10), Text("O'chirish", style: TextStyle(color: Color(0xFFDC2626)))])),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}