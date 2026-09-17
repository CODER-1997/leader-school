import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// MUHIM: agar loyihangizda "Fanlar" (subjects) uchun controller
/// ALLAQACHON mavjud bo'lsa — buni ishlatmang, o'zingiznikini
/// qoldiring va faqat CenterHomeView'dagi import/joyni shunga
/// moslang. Bu — CenterGroupController bilan bir xil patternda
/// yozilgan namuna/zaxira versiya, xolos.
///
/// YANGI ("INGLIZ TILI FANI" BAYROG'I): addSubject() va
/// updateSubject() endi ixtiyoriy 'isEnglish' parametrini qabul
/// qiladi va uni fan hujjatiga yozadi. CenterSubjectsView'dagi
/// "Bu — Ingliz tili fani" tugmasi shu orqali ishlaydi — belgilangan
/// fanlar guruh ekranida (GroupDetailView) qo'shimcha "Daily Task"
/// va "IELTS/CEFR" tab'larini avtomatik ko'rsatadi.
class CenterSubjectController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final TextEditingController subjectNameController = TextEditingController();

  Stream<QuerySnapshot> get subjectsStream =>
      _db.collection('center_subjects').snapshots(); // MUHIM: kolleksiya nomiga moslang

  Future<void> addSubject({bool isEnglish = false}) async {
    final name = subjectNameController.text.trim();
    if (name.isEmpty) return;
    await _db.collection('center_subjects').add({
      'name': name,
      'isEnglish': isEnglish,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Get.back();
  }

  Future<void> updateSubject(String docId, String oldName, {bool isEnglish = false}) async {
    final name = subjectNameController.text.trim();
    if (name.isEmpty) return;
    await _db.collection('center_subjects').doc(docId).update({
      'name': name,
      'isEnglish': isEnglish,
    });
    Get.back();
  }

  Future<void> deleteSubject(String docId) async {
    await _db.collection('center_subjects').doc(docId).delete();
    Get.back();
  }

  @override
  void onClose() {
    subjectNameController.dispose();
    super.onClose();
  }
}