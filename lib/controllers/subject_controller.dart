import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SubjectController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String classId;

  late Stream<QuerySnapshot> subjectsStream;

  // Barcha maktab fanlari ro'yxati
  final List<String> presetSubjects = [
    "Matematika",
    "Algebra",
    "Geometriya",
    "Fizika",
    "Kimyo",
    "Biologiya",
    "Informatika",
    "Ingliz tili",
    "Rus tili",
    "Ona tili",
    "Adabiyot",
    "Tarix",
    "Geografiya",
    "Jismoniy tarbiya",
    "Mehnat ta'limi",
    "Rasm (Tasviriy san'at)",
    "Musiqa madaniyati",
    "Tarbiya",
    "Iqtisodiy bilim asoslari",
    "Chaqiruvga qadar boshlang'ich tayyorgarlik"
  ];

  SubjectController({required this.classId});

  @override
  void onInit() {
    super.onInit();
    subjectsStream = _db
        .collection('subjects')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  // Fanni qo'shish
  Future<void> addSubject(String name) async {
    if (name.isEmpty) return;
    Get.back();
    try {
      await _db.collection('subjects').add({
        'name': name,
        'classId': classId,
        'createdAt': FieldValue.serverTimestamp(),
      });
     } catch (e) {
      Get.snackbar("Xato", "Xatolik: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // Fanni tahrirlash (Endi qo'shish kabi BottomSheet ochadi)
  Future<void> updateSubject(BuildContext context, String subjectId, String currentName) async {
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Fanni o'zgartirish ($currentName)",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetSubjects.map((subject) {
                    bool isSelected = subject == currentName;
                    return ActionChip(
                      backgroundColor: isSelected ? const Color(0xFF10B981) : const Color(0xFFECFDF5),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF047857),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide.none),
                      label: Text(subject),
                      onPressed: () async {
                        Get.back();
                        await _db.collection('subjects').doc(subjectId).update({'name': subject});
                        Get.snackbar("Yangilandi", "Fan nomi '$subject'ga o'zgartirildi", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // Fanni o'chirish
  Future<void> deleteSubject(String subjectId, String subjectName) async {
    Get.defaultDialog(
      title: "Fanni o'chirish",
      middleText: "'$subjectName' fanini o'chirmoqchimisiz?",
      textConfirm: "Ha, o'chirish",
      textCancel: "Yo'q",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back();
        await _db.collection('subjects').doc(subjectId).delete();
        Get.snackbar("O'chirildi", "Fan muvaffaqiyatli o'chirildi", backgroundColor: Colors.red, colorText: Colors.white);
      },
    );
  }
}