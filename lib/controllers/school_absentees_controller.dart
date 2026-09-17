import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Butun MAKTAB bo'yicha (barcha sinflar/fanlar) BUGUNGI kun uchun
/// olingan davomatlar asosida "kelmagan o'quvchilar" statistikasini
/// hisoblaydi. O'QUV MARKAZ (CenterAbsenteesController) bilan BIR XIL
/// arxitektura, farqi: Markazda birlik "guruh", Maktabda esa "sinf +
/// fan" birikmasi (chunki har bir fan o'z sinfida ALOHIDA attendance
/// hujjatiga ega — SubjectStudentsController.saveAttendance() shunday
/// yozadi).
///
/// HAQIQIY SXEMA:
///   - 'attendance' hujjatida MAKTAB yozuvi: 'classId' MAVJUD,
///     'subjectId' = FAN ID'si (school_classes/{classId}/subjects
///     ichidagi hujjat ID'si — GURUH emas), 'date' = "yyyy-MM-dd",
///     'records': Map<studentId, bool>.
///   - Sinf nomi: 'school_classes/{classId}' -> 'name'.
///   - Fan nomi: TOP-LEVEL 'subjects/{subjectId}' -> 'name' (subcollection
///     EMAS — SubjectController'da tasdiqlangan haqiqiy tuzilma).
///
/// Arxivlangan (o'chirilgan) o'quvchilar chetlashtiriladi (CenterAbsentees
/// bilan bir xil tuzatish).
class ClassSubjectAbsenteeSummary {
  final String classId;
  final String subjectId;
  final String className;
  final String subjectName;
  final List<String> absentStudentIds;
  final String attendanceDocId;
  final DateTime? smsNotifiedAt;

  ClassSubjectAbsenteeSummary({
    required this.classId,
    required this.subjectId,
    required this.className,
    required this.subjectName,
    required this.absentStudentIds,
    required this.attendanceDocId,
    this.smsNotifiedAt,
  });

  int get absentCount => absentStudentIds.length;
  bool get isNotified => smsNotifiedAt != null;
  String get displayTitle => "$className - $subjectName";
}

/// YANGI: SINF darajasidagi guruhlash — "Kelmaganlar" bo'limi endi
/// ikki bosqichli (Sinf -> Fan -> O'quvchilar). Bu klass bitta sinf
/// ichidagi BARCHA fanlarning (bugun kelmagani bor) yig'indisini
/// ifodalaydi.
class ClassAbsenteeGroup {
  final String classId;
  final String className;
  final List<ClassSubjectAbsenteeSummary> subjects;

  ClassAbsenteeGroup({required this.classId, required this.className, required this.subjects});

  int get totalAbsentCount => subjects.fold(0, (sum, s) => sum + s.absentCount);
  bool get anyNotified => subjects.any((s) => s.isNotified);
}

class SchoolAbsenteesController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final RxBool isLoading = true.obs;
  final RxList<ClassSubjectAbsenteeSummary> summaries = <ClassSubjectAbsenteeSummary>[].obs;

  // YANGI: sinf darajasida guruhlangan ko'rinish — "Kelmaganlar"ning
  // 1-bosqichi (sinflar ro'yxati) shundan foydalanadi. Har safar
  // `summaries` o'zgarganda qayta hisoblanadi (arzon — RAM ichida).
  List<ClassAbsenteeGroup> get classSummaries {
    final Map<String, List<ClassSubjectAbsenteeSummary>> byClass = {};
    for (final s in summaries) {
      byClass.putIfAbsent(s.classId, () => []).add(s);
    }
    final result = byClass.entries
        .map((e) => ClassAbsenteeGroup(classId: e.key, className: e.value.first.className, subjects: e.value))
        .toList()
      ..sort((a, b) => b.totalAbsentCount.compareTo(a.totalAbsentCount));
    return result;
  }

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  int get totalAbsentToday => summaries.fold(0, (sum, s) => sum + s.absentCount);

  Future<void> loadData() async {
    isLoading.value = true;

    // Bugun olingan barcha davomat hujjatlari (Maktab + Markaz birga —
    // ular Firestore darajasida ajratilmagan, shu yerda ajratamiz).
    final attSnap = await _db.collection('attendance').where('date', isEqualTo: _todayStr).get();

    // Kalit: "classId|subjectId" (bitta sinf-fan birikmasi).
    final Map<String, Set<String>> absentByKey = {};
    final Map<String, String> attendanceDocIdByKey = {};
    final Map<String, DateTime?> smsNotifiedAtByKey = {};
    final Map<String, String> classIdByKey = {};
    final Map<String, String> subjectIdByKey = {};

    for (var doc in attSnap.docs) {
      final data = doc.data();

      // MUHIM: bu — MARKAZ yozuvi (classId YO'Q) — o'tkazib yuboramiz,
      // faqat MAKTAB (classId BOR) hujjatlarini hisoblaymiz. Bu —
      // CenterAbsenteesController'dagi filtrning AYNAN TESKARISI.
      final classId = data['classId'] as String?;
      if (classId == null || classId.isEmpty) continue;

      final subjectId = data['subjectId'] as String?;
      if (subjectId == null || subjectId.isEmpty) continue;

      final key = "$classId|$subjectId";

      final records = Map<String, dynamic>.from(data['records'] ?? {});
      final absentIds = records.entries
          .where((e) => e.value == false)
          .map((e) => e.key)
          .toSet();

      if (absentIds.isNotEmpty) {
        absentByKey.putIfAbsent(key, () => {}).addAll(absentIds);
        attendanceDocIdByKey[key] = doc.id;
        smsNotifiedAtByKey[key] = (data['absenteesSmsNotifiedAt'] as Timestamp?)?.toDate();
        classIdByKey[key] = classId;
        subjectIdByKey[key] = subjectId;
      }
    }

    if (absentByKey.isEmpty) {
      summaries.clear();
      isLoading.value = false;
      return;
    }

    // YANGI: arxivlangan o'quvchilarni chetlashtirish.
    final allAbsentIds = absentByKey.values.expand((s) => s).toSet().toList();
    final Set<String> archivedIds = {};
    for (var i = 0; i < allAbsentIds.length; i += 10) {
      final end = (i + 10 > allAbsentIds.length) ? allAbsentIds.length : i + 10;
      final chunk = allAbsentIds.sublist(i, end);
      final snap = await _db.collection('students').where(FieldPath.documentId, whereIn: chunk).get();
      for (var doc in snap.docs) {
        if (doc.data()['isArchived'] == true) archivedIds.add(doc.id);
      }
    }
    if (archivedIds.isNotEmpty) {
      for (final key in absentByKey.keys.toList()) {
        absentByKey[key]!.removeWhere((id) => archivedIds.contains(id));
        if (absentByKey[key]!.isEmpty) absentByKey.remove(key);
      }
    }
    if (absentByKey.isEmpty) {
      summaries.clear();
      isLoading.value = false;
      return;
    }

    // Sinf nomlarini olish.
    final classIds = classIdByKey.values.toSet().toList();
    final Map<String, String> classNames = {};
    for (var i = 0; i < classIds.length; i += 10) {
      final end = (i + 10 > classIds.length) ? classIds.length : i + 10;
      final chunk = classIds.sublist(i, end);
      final snap = await _db.collection('school_classes').where(FieldPath.documentId, whereIn: chunk).get();
      for (var doc in snap.docs) {
        classNames[doc.id] = (doc.data())['name']?.toString() ?? 'Nomsiz sinf';
      }
    }

    // Fan nomlarini olish — MUHIM TUZATISH: fanlar 'school_classes/
    // {classId}/subjects' SUBCOLLECTION'ida EMAS, balki TOP-LEVEL
    // 'subjects' collection'ida saqlanadi (SubjectController'da
    // tasdiqlangan) — hujjat ID'si = subjectId, 'classId' esa alohida
    // maydon sifatida saqlanadi. Shu sababli oddiy whereIn so'rovi
    // yetarli (har bir juftlik uchun alohida so'rov shart emas).
    final uniqueSubjectIds = subjectIdByKey.values.toSet().toList();
    final Map<String, String> subjectNameById = {}; // kalit: subjectId
    for (var i = 0; i < uniqueSubjectIds.length; i += 10) {
      final end = (i + 10 > uniqueSubjectIds.length) ? uniqueSubjectIds.length : i + 10;
      final chunk = uniqueSubjectIds.sublist(i, end);
      final snap = await _db.collection('subjects').where(FieldPath.documentId, whereIn: chunk).get();
      for (var doc in snap.docs) {
        subjectNameById[doc.id] = (doc.data())['name']?.toString() ?? 'Nomsiz fan';
      }
    }

    final result = absentByKey.entries.map((e) {
      final key = e.key;
      return ClassSubjectAbsenteeSummary(
        classId: classIdByKey[key]!,
        subjectId: subjectIdByKey[key]!,
        className: classNames[classIdByKey[key]] ?? 'Nomsiz sinf',
        subjectName: subjectNameById[subjectIdByKey[key]] ?? 'Nomsiz fan',
        absentStudentIds: e.value.toList(),
        attendanceDocId: attendanceDocIdByKey[key] ?? '',
        smsNotifiedAt: smsNotifiedAtByKey[key],
      );
    }).toList()
      ..sort((a, b) => b.absentCount.compareTo(a.absentCount));

    summaries.assignAll(result);
    isLoading.value = false;
  }
}