import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// BOSQICH-1: Maktab sinflari va Markaz guruhlari ro'yxati, har biriga
/// BUGUNGI kelmaganlar soni biriktirilgan holda.
class AdminAbsentGroupsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var schoolClasses = <Map<String, dynamic>>[].obs; // {id, name, absentCount}
  var centerGroups = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = RxnString();

  String get _todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      // 1. Bugungi BARCHA davomat hujjatlari — 1 ta so'rov.
      final attSnap = await _db.collection('attendance').where('date', isEqualTo: _todayKey).get();

      final Map<String, Set<String>> schoolAbsentByClass = {};
      final Map<String, Set<String>> centerAbsentByGroup = {};

      for (final doc in attSnap.docs) {
        final data = doc.data();
        final records = Map<String, dynamic>.from(data['records'] ?? {});
        final absentIds = records.entries.where((e) => e.value != true).map((e) => e.key).toSet();
        if (absentIds.isEmpty) continue;

        if (data.containsKey('classId')) {
          final classId = data['classId'] as String?;
          if (classId != null) {
            schoolAbsentByClass.putIfAbsent(classId, () => {}).addAll(absentIds);
          }
        } else {
          final groupId = data['subjectId'] as String?;
          if (groupId != null) {
            centerAbsentByGroup.putIfAbsent(groupId, () => {}).addAll(absentIds);
          }
        }
      }

      // 2. Sinflar ro'yxati + kelmaganlar soni.
      final classesSnap = await _db.collection('school_classes').get();
      final schoolList = classesSnap.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc.data()['name'] ?? doc.id,
          'absentCount': schoolAbsentByClass[doc.id]?.length ?? 0,
        };
      }).toList();
      schoolList.sort((a, b) => (b['absentCount'] as int).compareTo(a['absentCount'] as int));
      schoolClasses.value = schoolList;

      // 3. Guruhlar ro'yxati + kelmaganlar soni.
      final groupsSnap = await _db.collection('groups').get();
      final centerList = groupsSnap.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc.data()['name'] ?? doc.id,
          'absentCount': centerAbsentByGroup[doc.id]?.length ?? 0,
        };
      }).toList();
      centerList.sort((a, b) => (b['absentCount'] as int).compareTo(a['absentCount'] as int));
      centerGroups.value = centerList;
    } catch (e) {
      debugPrint("Guruhlarni yuklashda xato: $e");
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _load();
}