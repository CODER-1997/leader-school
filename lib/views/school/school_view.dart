import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:leader_school/views/school/subject_view.dart';
import '../../controllers/school_controller.dart';
import '../../widgets/list_item_card.dart';

class SchoolView extends StatelessWidget {
  const SchoolView({super.key});

  void _showClassDialog(BuildContext context, SchoolController controller, {String? docId, String? oldName}) {
    final isEdit = docId != null;

    // Har doim avval tozalab olamiz
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

          final classes = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final doc = classes[index];
              final data = doc.data() as Map<String, dynamic>;
              final className = data['name'] ?? 'Nomsiz';

              return ListItemCard(
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