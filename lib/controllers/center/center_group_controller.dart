import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// O'quv markazidagi GURUHLAR ro'yxatini boshqaradi — endi BITTA FAN
/// doirasida (subjectId bo'yicha filtrlangan). Firestore: top-level
/// 'groups' collection, har bir guruhda 'subjectId' maydoni bor.
class CenterGroupController extends GetxController {
  final String subjectId; // YANGI: qaysi fanga tegishli

  CenterGroupController({required this.subjectId});

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController groupNameController = TextEditingController();

  late Stream<QuerySnapshot> groupsStream;

  @override
  void onInit() {
    super.onInit();
    // MUHIM: avval bu yerda .orderBy('name') ham bor edi — where(subjectId)
    // + orderBy(name) kombinatsiyasi Firestore composite index talab
    // qiladi. Index yo'q edi, shuning uchun so'rov XATO bilan tugardi,
    // lekin StreamBuilder buni "guruhlar yo'q" deb noto'g'ri ko'rsatgan
    // edi. Endi orderBy OLIB TASHLANDI — bitta oddiy tenglik so'rovi
    // (index kerak emas), saralash esa UI tomonida (Dart'da) bajariladi.
    groupsStream = _db.collection('groups').where('subjectId', isEqualTo: subjectId).snapshots();
  }

  Future<bool> _isDuplicate(String name) async {
    final snap = await _db.collection('groups').where('subjectId', isEqualTo: subjectId).where('name', isEqualTo: name).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> addGroup() async {
    final name = groupNameController.text.trim();
    if (name.isEmpty) return;

    try {
      if (await _isDuplicate(name)) {
        Get.snackbar("Diqqat!", "'$name' guruhi shu fanda mavjud!", backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      Get.back();

      await _db.collection('groups').add({
        'subjectId': subjectId, // YANGI: qaysi fanga tegishli
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'count': 0,
      });

      groupNameController.clear();
      Get.snackbar("Muvaffaqiyatli", "'$name' guruhi qo'shildi!", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Serverga yozishda xato: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> updateGroup(String docId, String oldName) async {
    final newName = groupNameController.text.trim();
    if (newName.isEmpty) return;

    Get.back();

    if (newName != oldName && await _isDuplicate(newName)) {
      Get.snackbar("Diqqat!", "'$newName' nomi shu fanda avvaldan mavjud!", backgroundColor: Colors.orangeAccent, colorText: Colors.white);
      return;
    }

    try {
      await _db.collection('groups').doc(docId).update({'name': newName});
      groupNameController.clear();
      Get.snackbar("Muvaffaqiyatli", "Guruh yangilandi!", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xato", "Yangilashda xatolik: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> deleteGroup(String docId) async {
    Get.back();
    try {
      await _db.collection('groups').doc(docId).delete();
      Get.snackbar("Muvaffaqiyatli", "Guruh o'chirildi!", backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xato", "O'chirishda xatolik: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  void onClose() {
    groupNameController.dispose();
    super.onClose();
  }
}