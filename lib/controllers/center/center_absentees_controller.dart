import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Butun O'QUV MARKAZ bo'yicha (barcha fanlar/guruhlar) BUGUNGI kun
/// uchun olingan davomatlar asosida "kelmagan o'quvchilar"
/// statistikasini hisoblaydi.
///
/// HAQIQIY SXEMA (GroupStudentsController'dan tasdiqlangan):
///   - 'attendance' hujjatida guruh ID'si — chalkash nom bilan —
///     'subjectId' maydonida saqlanadi (aslida GURUH ID'si, fan emas).
///   - 'date' — "yyyy-MM-dd" string (masalan "2026-08-23").
///   - 'records' — Map<studentId, bool>: true = kelgan, false = kelmagan.
///     Belgilanmagan o'quvchilar records ichida umuman yo'q.
///
/// MUHIM TUZATISH #1: 'attendance' collection'i MAKTAB va MARKAZ uchun
/// BIR XIL (ikkalasi ham 'subjectId' maydonidan foydalanadi) — lekin
/// MAKTABNING yozuvida QO'SHIMCHA 'classId' maydoni bor, MARKAZNIKIDA
/// esa YO'Q. Bu hujjatlar to'liq o'tkazib yuboriladi.
///
/// MUHIM TUZATISH #2 (YANGI): O'quvchi keyinchalik ARXIVLANGAN
/// (o'chirilgan) bo'lishi mumkin — lekin BUGUNGI 'attendance'
/// hujjatining 'records' xaritasi ESKI holicha qoladi (u yozilgan
/// paytda o'quvchi hali faol edi). Shu sababli, arxivlangan
/// o'quvchilar attendance yozuvida "kelmagan" deb qolib, bu yerda
/// noto'g'ri ko'rinib turardi. Endi absent bo'lgan barcha
/// studentId'lar uchun 'isArchived' holati QO'SHIMCHA tekshiriladi va
/// arxivlanganlar chetlashtiriladi.
class GroupAbsenteeSummary {
  final String groupId;
  final String groupName;
  final List<String> absentStudentIds;
  final String attendanceDocId; // YANGI: shu guruh/kunning attendance hujjati ID'si
  final DateTime? smsNotifiedAt; // YANGI: shu guruh uchun bugun SMS yuborilganmi

  GroupAbsenteeSummary({
    required this.groupId,
    required this.groupName,
    required this.absentStudentIds,
    required this.attendanceDocId,
    this.smsNotifiedAt,
  });

  int get absentCount => absentStudentIds.length;
  bool get isNotified => smsNotifiedAt != null;
}

class CenterAbsenteesController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final RxBool isLoading = true.obs;
  final RxList<GroupAbsenteeSummary> summaries = <GroupAbsenteeSummary>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  int get totalAbsentToday =>
      summaries.fold(0, (sum, s) => sum + s.absentCount);

  Future<void> loadData() async {
    isLoading.value = true;

    // Bugun olingan barcha davomat hujjatlari (Maktab + Markaz birga,
    // bitta so'rov — ular Firestore darajasida ajratilmaydi).
    final attSnap = await _db
        .collection('attendance')
        .where('date', isEqualTo: _todayStr)
        .get();

    final Map<String, Set<String>> absentByGroup = {};
    final Map<String, String> attendanceDocIdByGroup = {};
    final Map<String, DateTime?> smsNotifiedAtByGroup = {}; // YANGI
    for (var doc in attSnap.docs) {
      final data = doc.data();

      // MUHIM: bu — MAKTAB yozuvi (classId bor) — o'tkazib yuboramiz,
      // faqat MARKAZ (classId YO'Q) hujjatlarini hisoblaymiz.
      if (data.containsKey('classId')) continue;

      final groupId = data['subjectId'] as String?; // = guruh ID'si (chalkash nom)
      if (groupId == null || groupId.isEmpty) continue;

      final records = Map<String, dynamic>.from(data['records'] ?? {});
      final absentIds = records.entries
          .where((e) => e.value == false) // false = kelmagan
          .map((e) => e.key)
          .toSet();

      if (absentIds.isNotEmpty) {
        absentByGroup.putIfAbsent(groupId, () => {}).addAll(absentIds);
        attendanceDocIdByGroup[groupId] = doc.id;
        // YANGI: shu guruh uchun bugun SMS yuborilganmi (guruh
        // DARAJASIDA — kim ekanidan qat'i nazar, hech bo'lmasa bitta
        // kishiga yuborilgan bo'lsa ham "ogohlantirilgan" deb belgilanadi).
        smsNotifiedAtByGroup[groupId] = (data['absenteesSmsNotifiedAt'] as Timestamp?)?.toDate();
      }
    }

    if (absentByGroup.isEmpty) {
      summaries.clear();
      isLoading.value = false;
      return;
    }

    // YANGI: barcha kelmagan studentId'lar orasidan ARXIVLANGANLARINI
    // aniqlash uchun bitta (yoki bir nechta chunklangan) so'rov.
    final allAbsentIds = absentByGroup.values.expand((s) => s).toSet().toList();
    final Set<String> archivedIds = {};
    for (var i = 0; i < allAbsentIds.length; i += 10) {
      final end = (i + 10 > allAbsentIds.length) ? allAbsentIds.length : i + 10;
      final chunk = allAbsentIds.sublist(i, end);
      final snap = await _db
          .collection('students')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (var doc in snap.docs) {
        if (doc.data()['isArchived'] == true) archivedIds.add(doc.id);
      }
    }

    // Arxivlanganlarni har bir guruh ro'yxatidan olib tashlaymiz.
    if (archivedIds.isNotEmpty) {
      for (final groupId in absentByGroup.keys.toList()) {
        absentByGroup[groupId]!.removeWhere((id) => archivedIds.contains(id));
        if (absentByGroup[groupId]!.isEmpty) absentByGroup.remove(groupId);
      }
    }

    if (absentByGroup.isEmpty) {
      summaries.clear();
      isLoading.value = false;
      return;
    }

    // Faqat kelmagani bor guruhlarning nomini olish (hammasini emas).
    final groupIds = absentByGroup.keys.toList();
    final Map<String, String> groupNames = {};
    for (var i = 0; i < groupIds.length; i += 10) {
      final end = (i + 10 > groupIds.length) ? groupIds.length : i + 10;
      final chunk = groupIds.sublist(i, end);
      final snap = await _db
          .collection('groups')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (var doc in snap.docs) {
        groupNames[doc.id] = (doc.data())['name']?.toString() ?? 'Nomsiz guruh';
      }
    }

    final result = absentByGroup.entries
        .map((e) => GroupAbsenteeSummary(
      groupId: e.key,
      groupName: groupNames[e.key] ?? 'Nomsiz guruh',
      absentStudentIds: e.value.toList(),
      attendanceDocId: attendanceDocIdByGroup[e.key] ?? '',
      smsNotifiedAt: smsNotifiedAtByGroup[e.key], // YANGI
    ))
        .toList()
      ..sort((a, b) => b.absentCount.compareTo(a.absentCount));

    summaries.assignAll(result);
    isLoading.value = false;
  }
}