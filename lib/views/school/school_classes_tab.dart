import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart'; // YANGI: sinflar tartibini LOKAL saqlash uchun
import 'package:leader_school/views/school/subject_view.dart';
import '../../controllers/school_controller.dart';
import '../../widgets/list_item_card.dart';

/// "Sinflar" bo'limi — endi BottomNav ostidagi bitta tab.
///
/// YANGI:
///   1. Standart tartib endi RAQAMLI O'SISH bo'yicha ("9-A", "10-B"
///      kabi nomlar to'g'ri tartiblanadi — sof matn taqqoslash "10"ni
///      "9"dan OLDIN chiqarib yuborardi, chunki '1' < '9').
///   2. "Fanlar"/"Guruhlar" ekranlaridagi kabi — UZOQ BOSIB TORTISH
///      orqali tartibni o'zgartirish mumkin, FAQAT LOKAL saqlanadi
///      (GetStorage) — Firestore'ga hech narsa yozilmaydi.
class SchoolClassesTab extends StatefulWidget {
  const SchoolClassesTab({super.key});

  @override
  State<SchoolClassesTab> createState() => _SchoolClassesTabState();
}

class _SchoolClassesTabState extends State<SchoolClassesTab> {
  final GetStorage _localBox = GetStorage();
  static const String _orderKey = 'school_classes_local_order';
  List<String> _localOrder = [];

  @override
  void initState() {
    super.initState();
    final saved = _localBox.read<List>(_orderKey);
    if (saved != null) _localOrder = saved.cast<String>();
  }

  // YANGI: "9", "9-A", "10-B" kabi nomlarni RAQAMLI qism bo'yicha
  // to'g'ri taqqoslaydi (sof matn taqqoslash o'rniga) — shunda "10-A"
  // "9-A"dan KEYIN keladi, oldin emas.
  int _compareClassNames(String a, String b) {
    final regex = RegExp(r'^(\d+)\s*-?\s*(.*)$');
    final matchA = regex.firstMatch(a.trim());
    final matchB = regex.firstMatch(b.trim());

    if (matchA != null && matchB != null) {
      final numA = int.tryParse(matchA.group(1)!) ?? 0;
      final numB = int.tryParse(matchB.group(1)!) ?? 0;
      if (numA != numB) return numA.compareTo(numB);
      return matchA.group(2)!.compareTo(matchB.group(2)!);
    }
    return a.compareTo(b); // zaxira — raqam bilan boshlanmasa
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

  Future<void> _onReorderClasses(List<QueryDocumentSnapshot> currentDocs, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final newOrderDocs = List<QueryDocumentSnapshot>.from(currentDocs);
    final moved = newOrderDocs.removeAt(oldIndex);
    newOrderDocs.insert(newIndex, moved);

    final newOrderIds = newOrderDocs.map((d) => d.id).toList();

    setState(() => _localOrder = newOrderIds);
    await _localBox.write(_orderKey, newOrderIds);
  }

  void _showClassDialog(BuildContext context, SchoolController controller, {String? docId, String? oldName}) {
    final isEdit = docId != null;

    controller.classInputController.clear();
    controller.subNameInputController.clear();

    if (isEdit && oldName != null) {
      if (oldName.contains('-')) {
        List<String> parts = oldName.split('-');
        controller.classInputController.text = parts[0].trim();
        controller.subNameInputController.text = parts.length > 1 ? parts[1].trim() : '';
      } else {
        controller.classInputController.text = oldName;
      }
    }

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
                  Text(
                    isEdit ? "Sinfni tahrirlash" : "Yangi sinf qo'shish",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller.classInputController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Sinf raqami",
                  hintText: "Masalan: 10",
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller.subNameInputController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: "Sinf harfi (ixtiyoriy)",
                  hintText: "Masalan: A",
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    String grade = controller.classInputController.text.trim();

                    if (grade.isEmpty) {
                      Get.snackbar("Diqqat", "Sinf raqamini kiriting!", backgroundColor: Colors.orangeAccent, colorText: Colors.white);
                      return;
                    }

                    if (isEdit) {
                      controller.updateSchoolClass(docId, oldName!);
                    } else {
                      controller.addSchoolClass();
                    }
                  },
                  child: Text(
                    isEdit ? "Yangilash" : "Saqlash",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final SchoolController controller = Get.put(SchoolController());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text("Maktab Sinflari", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showClassDialog(context, controller),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: controller.classesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Hozircha sinflar yo'q."));

          // YANGI: endi RAQAMLI O'SISH tartibida saralanadi (sof matn
          // taqqoslash emas).
          final numericallySorted = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final nameA = (a.data() as Map<String, dynamic>)['name'] ?? '';
              final nameB = (b.data() as Map<String, dynamic>)['name'] ?? '';
              return _compareClassNames(nameA.toString(), nameB.toString());
            });

          // YANGI: shu tartib ustiga LOKAL saqlangan (qo'lda o'zgartirilgan) tartib qo'llanadi.
          final classes = _applyLocalOrder(numericallySorted);

          // YANGI: ListView.builder o'rniga ReorderableListView.builder.
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            onReorder: (oldIndex, newIndex) => _onReorderClasses(classes, oldIndex, newIndex),
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
              final doc = classes[index];
              final data = doc.data() as Map<String, dynamic>;
              final className = data['name'] ?? 'Nomsiz';

              return ListItemCard(
                key: ValueKey(doc.id), // YANGI: ReorderableListView uchun shart
                title: className,
                subtitle: "${data['count'] ?? 0} ta o'quvchi",
                iconBgColor: const Color(0xFFEFF6FF),
                onTap: () {
                  Get.to(() => SubjectsView(classId: doc.id, className: className));
                },
                onEdit: () {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _showClassDialog(context, controller, docId: doc.id, oldName: className);
                  });
                },
                onDelete: () {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    Get.defaultDialog(
                      title: "O'chirish",
                      middleText: "'$className' sinfini rostdan ham o'chirmoqchimisiz?",
                      textConfirm: "O'chirish",
                      confirmTextColor: Colors.white,
                      buttonColor: Colors.red,
                      textCancel: "Bekor qilish",
                      onConfirm: () => controller.deleteSchoolClass(doc.id),
                    );
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}