import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SchoolController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController classInputController = TextEditingController();
  final TextEditingController subNameInputController = TextEditingController();

  late Stream<QuerySnapshot> classesStream;

  @override
  void onInit() {
    super.onInit();
    classesStream = _db.collection('school_classes').orderBy('name').snapshots();
  }

  Future<bool> _isDuplicate(String name) async {
    var checkSnapshot = await _db.collection('school_classes').where('name', isEqualTo: name).get();
    return checkSnapshot.docs.isNotEmpty;
  }

  // Toza va xatosiz nom hosil qilish funksiyasi
  String _getClassName() {
    String grade = classInputController.text.trim();
    String letter = subNameInputController.text.trim();
    return letter.isNotEmpty ? "$grade-$letter" : grade;
  }

  Future<void> addSchoolClass() async {
    String className = _getClassName();
    if (className.isEmpty) return;

    try {
      if (await _isDuplicate(className)) {
        Get.snackbar("Diqqat!", "'$className' sinfi bazada mavjud!", backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      Get.back();

      await _db.collection('school_classes').add({
        'name': className,
        'createdAt': FieldValue.serverTimestamp(),
        'count': 0,
      });

      classInputController.clear();
      subNameInputController.clear();

      _showSuccess("'$className' sinfi qo'shildi!");
    } catch (e) {
      Get.snackbar("Xatolik", "Serverga yozishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> updateSchoolClass(String docId, String oldName) async {
    String newName = _getClassName();
    if (newName.isEmpty) return;

    Get.back();

    if (newName != oldName && await _isDuplicate(newName)) {
      _showWarning("'$newName' nomi bazada avvaldan mavjud!");
      return;
    }

    try {
      await _db.collection('school_classes').doc(docId).update({'name': newName});
      classInputController.clear();
      subNameInputController.clear();
      _showSuccess("Sinf yangilandi!");
    } catch (e) {
      Get.snackbar("Xato", "Yangilashda xatolik: $e");
    }
  }

  Future<void> deleteSchoolClass(String docId) async {
    Get.back();
    try {
      await _db.collection('school_classes').doc(docId).delete();
      _showSuccess("Sinf o'chirildi!");
    } catch (e) {
      Get.snackbar("Xato", "O'chirishda xatolik: $e");
    }
  }

  void _showWarning(String msg) {
    Get.snackbar("Diqqat!", msg, backgroundColor: Colors.orangeAccent, colorText: Colors.white);
  }

  void _showSuccess(String msg) {
    Get.snackbar("Muvaffaqiyatli", msg, backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
  }

  @override
  void onClose() {
    classInputController.dispose();
    subNameInputController.dispose();
    super.onClose();
  }
}