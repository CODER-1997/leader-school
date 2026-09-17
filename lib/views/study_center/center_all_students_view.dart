import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
// MUHIM: hisobotni Excel (.xlsx) sifatida yaratish uchun `excel` pub
// paketi ishlatiladi — pubspec.yaml'ga `excel: ^4.0.6` (yoki so'nggi
// versiya) qo'shilganiga ishonch hosil qiling. `xls.` prefiksi
// Flutter'ning o'z Row/Border kabi nomlari bilan TO'QNASHMASLIGI
// uchun ataylab qo'yilgan.
import 'package:excel/excel.dart' as xls;

// MUHIM: haqiqiy StudentProfileView yo'liga moslang
import '../school/student_profil/student_profil.dart';
import '../../controllers/crm_controller.dart'; // YANGI: MUHIM — haqiqiy yo'lingizga moslang (SubjectStudentsController qanday import qilgan bo'lsa, xuddi shunday)

// YANGI (SMS TANLASH): tanlangan o'quvchilarni ko'rish va qarzdorlik
// haqida SMS yuborish ekrani. Fayl shu papkada yotadi deb faraz
// qilinmoqda — agar boshqa joyga qo'ysangiz yo'lni moslang.
import '../../widgets/debt_sms_preview_view.dart';

/// "Barcha talabalar" bo'limi — butun o'quv markazdagi (fanlarga
/// qaramasdan) hamma o'quvchilar.
///
/// MUHIM (YANGI): bu widget endi o'ZINING Scaffold/AppBar/FAB'iga EGA
/// EMAS — chunki u CenterHomeView'ning IndexedStack'i ichida, YAGONA
/// tashqi AppBar/FAB ostida ishlaydi (avval ikkalasi ustma-ust
/// chiqib, "2 ta AppBar" ko'rinishini berardi). Qidiruv matni endi
/// TASHQARIDAN (`searchQuery` parametri orqali) keladi — qidiruv
/// maydonining o'zi CenterHomeView'ning AppBar'ida joylashgan.
///
/// Fan tab'lari + guruh chip'lari (filtr) va qarzdorlik ko'rsatish —
/// o'zgarishsiz, shu yerda qoladi (bular ro'yxat tarkibiga tegishli,
/// AppBar'ga emas).
///
/// YANGI (SMS TANLASH): endi ro'yxatdagi o'quvchini UZOQ BOSISH
/// (long-press) orqali "tanlov rejimi"ga o'tish mumkin. Tanlov
/// rejimida oddiy bosish (tap) profilga o'tkazish o'rniga
/// tanlash/bekor qilishga xizmat qiladi — profilga o'tish faqat
/// tanlov rejimi O'CHIQ bo'lganda ishlaydi (mavjud xatti-harakat
/// buzilmagan). Kamida 1 ta o'quvchi tanlanganda pastda suzuvchi
/// panel chiqadi — "Ko'rish" tugmasi tanlangan o'quvchilarni va
/// ularning FAN BO'YICHA qarzdor oylarini ko'rsatuvchi, so'ng
/// tasdiqlangandan keyin SMS yuborish imkonini beruvchi alohida
/// ekranga (DebtSmsPreviewView) olib boradi.
///
/// YANGI (FAN BO'YICHA TO'LIQ BELGILASH + MAKTAB VA QARZI YO'QLARNI
/// CHIQARIB TASHLASH + SMS YASHIL BELGI): biror FAN tab'i tanlanganda
/// (aniq guruh chip'i tanlangan-tanlanmaganidan qat'iy nazar) ro'yxat
/// ustida "Fan bo'yicha belgilash" tugmasi chiqadi — bu orqali o'sha
/// FANNING BARCHA guruhlaridagi qarzdor o'quvchilarni bir bosishda
/// tanlab, ularga qarzdorlik haqida ommaviy SMS yuborish mumkin.
/// "Hammasi" (fansiz, butun markaz) holatida bu tugma chiqmaydi —
/// funksiya faqat FAN darajasida ishlaydi, jami markaz emas. Maktab
/// o'quvchilari (classId bor, kurs to'lovidan ozod) va QARZI YO'Q
/// o'quvchilar endi tanlovga UMUMAN kirmaydi — na uzoq bosish, na
/// "Fan bo'yicha belgilash" orqali (SMS faqat haqiqiy qarzdorlarga
/// yuborilishi kerak; alohida uzoq bosish orqali qo'lda tanlashda esa
/// faqat maktab o'quvchilari cheklanadi — qarzi yo'q o'quvchini
/// istasangiz qo'lda baribir tanlashingiz mumkin). Qachon oxirgi
/// marta qarzdorlik SMS'i yuborilgani endi YASHIL rangda ko'rsatiladi
/// (avval kulrang edi) — shu bilan "SMS allaqachon yuborilgan" holati
/// bir qarashda ko'zga tashlanadi.
///
/// YANGI (FAN BO'YICHA EXCEL HISOBOT): fan tanlanganda chiqadigan
/// qatorda, "Fan bo'yicha belgilash" yonida endi "Hisobot" tugmasi
/// ham bor. U bosilganda — TANLANGAN FANNING barcha guruhlari uchun
/// Excel (.xlsx) fayl yaratiladi: har bir GURUH alohida sarlavha
/// (title) qatori bilan boshlanadi, ostida o'sha guruhning (maktab
/// o'quvchilaridan tashqari) a'zolari OILAVIY ISM bo'yicha alifbo
/// tartibida keladi. Har bir o'quvchi qatorida: F.I.Sh., shu FANGA
/// qo'shilgan sana, va — fan bo'yicha ENG ERTA qo'shilgan o'quvchidan
/// HOZIRGI oygacha bo'lgan HAR BIR oy uchun bitta ustun: agar
/// o'quvchi hali qo'shilmagan bo'lsa kulrang ("—"), qarzdor bo'lsa
/// QIZIL ("Qarzdor"), to'lagan bo'lsa YASHIL (to'langan summasi
/// bilan). Fayl tayyor bo'lgach, tizimning "ulashish" oynasi (odatda
/// Telegram, Drive va h.k.) orqali yuboriladi.
class CenterAllStudentsTab extends StatefulWidget {
  final String searchQuery; // YANGI: CenterHomeView'dan keladi

  // YANGI (SMS TANLASH): tanlov rejimi YOQILGANDA/O'CHGANDA
  // CenterHomeView'ga xabar beradi (true = kamida 1 ta o'quvchi
  // tanlangan, false = tanlov yo'q). CenterHomeView buni eshitib,
  // tashqi "O'quvchi qo'shish" FAB'ini shu vaqtga yashirishi mumkin —
  // aks holda u bizning pastdagi tanlov panelimiz bilan bir joyga
  // tushib qolardi.
  final ValueChanged<bool>? onSelectionModeChanged;

  const CenterAllStudentsTab({super.key, this.searchQuery = '', this.onSelectionModeChanged});

  @override
  State<CenterAllStudentsTab> createState() => _CenterAllStudentsTabState();
}

class _CenterAllStudentsTabState extends State<CenterAllStudentsTab> {
  // --- Fan/guruh filtri ---
  bool _isLoadingGroups = true;
  List<Map<String, String>> _groups = []; // [{id, name, subjectId}]
  List<Map<String, String>> _subjects = []; // [{id, name}]
  String? _selectedSubjectTab;
  String? _selectedGroupFilter; // null = filtrsiz (hammasi)

  // --- Qarzdorlik uchun to'lovlar keshi ---
  bool _isLoadingPayments = true;
  Map<String, Set<String>> _paidKeysByStudent = {};
  // YANGI (FAN BO'YICHA HISOBOT): 'studentId|subjectId|forMonth' ->
  // to'langan summa — hisobotdagi YASHIL yacheykada ko'rsatish uchun.
  // MUHIM (TODO): 'amount' maydon nomi taxminiy — agar
  // payments_feed hujjatingizda summa boshqa nom bilan saqlansa
  // (masalan 'sum', 'price', 'total'), pastdagi _loadPayments
  // ichidagi 'amount' so'zini shunga moslang.
  Map<String, num> _paidAmountByKey = {};

  // --- YANGI: qaysi o'quvchiga qachon qarzdorlik SMS'i yuborilgani ---
  Map<String, Timestamp> _lastDebtSmsByStudent = {};

  // --- YANGI (SMS TANLASH): ko'p tanlov rejimi ---
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedDataById = {};

  // --- YANGI (FAN BO'YICHA HISOBOT) ---
  bool _isGeneratingReport = false;

  static const List<String> _uzMonthShort = [
    'Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyun', 'Iyul', 'Avg', 'Sent', 'Okt', 'Noy', 'Dek'
  ];

  @override
  void initState() {
    super.initState();
    _loadGroupsAndSubjects();
    _loadPayments();
    _loadDebtSmsStatus();
  }

  Future<void> _loadGroupsAndSubjects() async {
    try {
      final groupsSnap = await FirebaseFirestore.instance.collection('groups').orderBy('name').get();
      final groups = groupsSnap.docs.map((d) => {
        'id': d.id,
        'name': (d.data()['name'] ?? 'Nomsiz guruh').toString(),
        'subjectId': (d.data()['subjectId'] ?? '').toString(),
      }).toList();

      final usedSubjectIds = groups.map((g) => g['subjectId']!).where((id) => id.isNotEmpty).toSet();
      final Map<String, String> subjectNames = {};
      if (usedSubjectIds.isNotEmpty) {
        final idsList = usedSubjectIds.toList();
        for (var i = 0; i < idsList.length; i += 10) {
          final end = (i + 10 > idsList.length) ? idsList.length : i + 10;
          final chunk = idsList.sublist(i, end);
          final subSnap = await FirebaseFirestore.instance.collection('center_subjects').where(FieldPath.documentId, whereIn: chunk).get();
          for (var doc in subSnap.docs) {
            subjectNames[doc.id] = (doc.data()['name'] ?? 'Nomsiz fan').toString();
          }
        }
      }

      final subjects = usedSubjectIds.map((id) => {'id': id, 'name': subjectNames[id] ?? 'Nomsiz fan'}).toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _subjects = subjects;
        _isLoadingGroups = false;
      });
    } catch (e) {
      debugPrint("Guruh/fanlarni yuklashda xato: $e");
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  // YANGI: 'sms_feed' kolleksiyasidan (source == 'debt') har bir
  // o'quvchiga OXIRGI marta qachon qarzdorlik SMS'i yuborilganini
  // BITTA so'rov bilan o'qiydi — payments_feed bilan bir xil naqsh
  // (real-time listener EMAS, bitta .get(), keyin pastga tortib
  // yangilanadi).
  Future<void> _loadDebtSmsStatus() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sms_feed')
          .where('source', isEqualTo: 'debt')
          .get();

      final Map<String, Timestamp> result = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        final sentAt = data['sentAt'] as Timestamp?;
        if (studentId == null || sentAt == null) continue;

        final existing = result[studentId];
        if (existing == null || sentAt.compareTo(existing) > 0) {
          result[studentId] = sentAt;
        }
      }

      if (!mounted) return;
      setState(() => _lastDebtSmsByStudent = result);
    } catch (e) {
      debugPrint("SMS holatini yuklashda xato: $e");
    }
  }

  // YANGI: SMS yuborilgan sanani qisqa, o'qish oson shaklda ko'rsatadi.
  String _formatSmsDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return "bugun";
    if (diff == 1) return "kecha";
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return dt.year == now.year ? "$dd.$mm" : "$dd.$mm.${dt.year}";
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoadingPayments = true);
    try {
      // MUHIM (XATO TUZATILDI): to'lovlar aslida
      // students/{id}/payments SUBCOLLECTION'ida saqlanadi, lekin
      // StudentPaymentController HAR BIR to'lovni 'payments_feed'
      // degan TEKIS (top-level) kolleksiyaga ham nusxalab yozadi —
      // aynan shu orqali BARCHA o'quvchilar bo'yicha BITTA so'rov
      // bilan tekshirish mumkin. Avval noto'g'ri 'payments' nomi
      // ishlatilgan edi (bunday kolleksiya umuman yo'q edi).
      final snap = await FirebaseFirestore.instance
          .collection('payments_feed')
          .where('source', isEqualTo: 'tutoring')
          .get();

      final Map<String, Set<String>> result = {};
      // YANGI (FAN BO'YICHA HISOBOT): to'langan summalar — hisobotda
      // YASHIL yacheykada aniq summani ko'rsatish uchun.
      final Map<String, num> amounts = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        final subjectId = data['forSubjectId'] as String?;
        final forMonth = data['forMonth'] as String?;
        if (studentId == null || subjectId == null || forMonth == null) continue;

        result.putIfAbsent(studentId, () => {}).add('$subjectId|$forMonth');

        final amountRaw = data['amount'];
        if (amountRaw is num) {
          final amtKey = '$studentId|$subjectId|$forMonth';
          amounts[amtKey] = (amounts[amtKey] ?? 0) + amountRaw;
        }
      }

      if (!mounted) return;
      setState(() {
        _paidKeysByStudent = result;
        _paidAmountByKey = amounts;
        _isLoadingPayments = false;
      });
    } catch (e) {
      debugPrint("To'lovlarni yuklashda xato: $e");
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  String _capitalize(String text) {
    if (text.trim().isEmpty) return '';
    return text.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _fullName(Map<String, dynamic> data) {
    final last = _capitalize((data['lastName'] ?? '').toString());
    final first = _capitalize((data['firstName'] ?? '').toString());
    if (last.isNotEmpty && first.isNotEmpty) return "$last $first";
    return _capitalize(
        (data['fullName'] ?? data['name'] ?? "Nomsiz o'quvchi").toString());
  }

  // YANGI: maktab o'quvchisi ekanini tekshiradi (classId bor) — bunday
  // o'quvchi kurs to'lovidan OZOD, "Qarzi yo'q" bilan aralashtirmaslik
  // uchun ALOHIDA belgi ko'rsatiladi.
  bool _isSchoolStudent(Map<String, dynamic> data) {
    final classId = data['classId'] as String?;
    return classId != null && classId.isNotEmpty;
  }

  // YANGI (FAN BO'YICHA HISOBOT): o'quvchining BERILGAN fanga
  // qo'shilgan sanasini qaytaradi (yo'q bo'lsa null).
  DateTime? _subjectJoinDate(Map<String, dynamic> data, String subjectId) {
    final joinDatesRaw = Map<String, dynamic>.from(data['centerSubjectJoinDates'] ?? {});
    final ts = joinDatesRaw[subjectId] as Timestamp?;
    return ts?.toDate();
  }

  // YANGI (REFAKTOR + FAN BO'YICHA): endi qarzdorlik FAN darajasida
  // hisoblanadi — har bir yozuv {subjectId, subjectName, monthKey}.
  // Bu SMS matnida "aynan qaysi fandan, qaysi oy uchun" qarz borligini
  // to'g'ri ko'rsatish uchun kerak (bitta oyda bir nechta fandan qarz
  // bo'lishi mumkin). Mavjud ro'yxat ko'rinishi (_computeDebtMonths)
  // o'zgarishsiz — u shu funksiyadan faqat oy nomlarini oladi.
  List<Map<String, String>> _debtEntries(String studentId, Map<String, dynamic> data) {
    if (data['isPrivileged'] == true) return [];
    final classId = data['classId'] as String?;
    if (classId != null && classId.isNotEmpty) return [];

    final centerGroupIds = List<String>.from(data['centerGroupIds'] ?? []);
    if (centerGroupIds.isEmpty) return [];

    final subjectIds = <String>{};
    for (final gId in centerGroupIds) {
      final group = _groups.firstWhere((g) => g['id'] == gId, orElse: () => {});
      final subjId = group['subjectId'];
      if (subjId != null && subjId.isNotEmpty) subjectIds.add(subjId);
    }
    if (subjectIds.isEmpty) return [];

    final joinDatesRaw = Map<String, dynamic>.from(data['centerSubjectJoinDates'] ?? {});
    final paidKeys = _paidKeysByStudent[studentId] ?? {};

    final now = DateTime.now();
    final currentMonthKey = DateTime(now.year, now.month);

    final List<Map<String, String>> entries = [];
    for (final subjId in subjectIds) {
      final joinTs = joinDatesRaw[subjId] as Timestamp?;
      if (joinTs == null) continue;
      final joinDate = joinTs.toDate();
      final subjectName = _subjects.firstWhere(
            (s) => s['id'] == subjId,
        orElse: () => {'name': 'Nomsiz fan'},
      )['name']!;

      DateTime cursor = DateTime(joinDate.year, joinDate.month);
      while (!cursor.isAfter(currentMonthKey)) {
        final monthKey = "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}";
        if (!paidKeys.contains('$subjId|$monthKey')) {
          entries.add({'subjectId': subjId, 'subjectName': subjectName, 'monthKey': monthKey});
        }
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    }

    entries.sort((a, b) {
      final c = a['monthKey']!.compareTo(b['monthKey']!);
      if (c != 0) return c;
      return a['subjectName']!.compareTo(b['subjectName']!);
    });
    return entries;
  }

  // YANGI (REFAKTOR): asosiy ro'yxat uchun — faqat aniq oylar (fansiz),
  // _debtEntries'dan olinadi, xatti-harakat o'zgarmagan.
  List<String> _debtMonthKeys(String studentId, Map<String, dynamic> data) {
    final keys = _debtEntries(studentId, data).map((e) => e['monthKey']!).toSet().toList();
    keys.sort();
    return keys;
  }

  String _monthKeyToLabel(String key) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return "$year ${_uzMonthShort[month - 1]}";
  }

  List<String> _computeDebtMonths(String studentId, Map<String, dynamic> data) {
    return _debtMonthKeys(studentId, data).map(_monthKeyToLabel).toList();
  }

  // --- YANGI (SMS TANLASH): tanlov yordamchilari ---

  // YANGI (MAKTAB O'QUVCHILARINI CHIQARIB TASHLASH): maktab
  // o'quvchilari (classId bor) HECH QACHON tanlovga kira olmaydi —
  // ular kurs to'lovidan ozod, demak qarzdorlik SMS'i ularga
  // tegishli emas. Shu sababli bu yerda eng boshida tekshirib,
  // agar maktab o'quvchisi bo'lsa, hech narsa qilinmaydi.
  //
  // ESLATMA: bu QO'LDA (uzoq bosish orqali) tanlash — bu yerda
  // "qarzi yo'q" o'quvchi ATAYIN cheklanmagan (foydalanuvchi xohласа
  // qo'lda tanlab, xabar matnida "qarzi yo'q" deb ko'rishi mumkin).
  // Qarzi yo'qlarni AVTOMATIK chiqarib tashlash faqat FAN BO'YICHA
  // ommaviy belgilashda (_selectableDebtorsForSubject) qo'llanadi.
  void _toggleSelect(Map<String, dynamic> data) {
    if (_isSchoolStudent(data)) return;
    final id = data['id'] as String;
    final wasEmpty = _selectedIds.isEmpty;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedDataById.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
        _selectedDataById[id] = data;
        _selectionMode = true;
      }
    });
    // YANGI: faqat holat haqiqatan o'zgarganda (bo'sh <-> to'la)
    // tashqi FAB'ga xabar beramiz — har bosishda emas.
    if (wasEmpty != _selectedIds.isEmpty) {
      widget.onSelectionModeChanged?.call(_selectedIds.isNotEmpty);
    }
  }

  // YANGI (HAMMASINI BELGILASH): berilgan `selectable` ro'yxatidagi
  // (allaqachon maktab o'quvchilarisiz va — FAN bo'yicha belgilashda —
  // qarzi yo'qlarsiz filtrlangan) BARCHA o'quvchilarni bir yo'la
  // tanlaydi (yoki bekor qiladi). Xavfsizlik uchun baribir
  // _isSchoolStudent tekshiruvi qayta o'tkaziladi.
  void _toggleSelectAll(List<Map<String, dynamic>> selectable, bool select) {
    setState(() {
      for (final s in selectable) {
        if (_isSchoolStudent(s)) continue;
        final id = s['id'] as String;
        if (select) {
          _selectedIds.add(id);
          _selectedDataById[id] = s;
        } else {
          _selectedIds.remove(id);
          _selectedDataById.remove(id);
        }
      }
      _selectionMode = _selectedIds.isNotEmpty;
    });
    widget.onSelectionModeChanged?.call(_selectedIds.isNotEmpty);
  }

  // YANGI (FAN BO'YICHA BELGILASH): tanlangan FANNING (barcha
  // guruhlari bo'yicha, joriy guruh chip filtri yoki qidiruvdan
  // MUSTAQIL — chunki maqsad butun fan bo'yicha ommaviy SMS
  // yuborish) QARZDOR o'quvchilarini qaytaradi. Maktab o'quvchilari
  // va qarzi yo'q o'quvchilar bu ro'yxatga UMUMAN kirmaydi.
  List<Map<String, dynamic>> _selectableDebtorsForSubject(String subjectId) {
    if (!Get.isRegistered<CrmController>()) return [];
    final crm = Get.find<CrmController>();

    final subjectGroupIds = _groups
        .where((g) => g['subjectId'] == subjectId)
        .map((g) => g['id']!)
        .toSet();
    if (subjectGroupIds.isEmpty) return [];

    final all = crm.allStudents.where((s) => s['isArchived'] != true);

    return all.where((s) {
      if (_isSchoolStudent(s)) return false;
      final groupIds = List<String>.from(s['centerGroupIds'] ?? []);
      if (!groupIds.any(subjectGroupIds.contains)) return false;
      final studentId = s['id'] as String;
      // Qarzi yo'q bo'lsa — tanlovga kirmaydi (faqat qarzdorlarga SMS).
      return _debtMonthKeys(studentId, s).isNotEmpty;
    }).toList();
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
      _selectedDataById.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  void _openDebtSmsPreview() {
    final selected = _selectedDataById.values.toList();
    final Map<String, List<Map<String, String>>> debtEntriesByStudent = {
      for (final s in selected)
        (s['id'] as String): _isSchoolStudent(s)
            ? <Map<String, String>>[]
            : _debtEntries(s['id'] as String, s),
    };

    Get.to(() => DebtSmsPreviewView(
      students: selected,
      debtEntriesByStudent: debtEntriesByStudent,
      fullNameBuilder: _fullName,
      monthLabelBuilder: _monthKeyToLabel,
    ))?.then((_) {
      // YANGI: ko'rish ekranidan qaytgach tanlovni tozalaymiz — bu
      // tanlov panelini yashiradi va tashqi "O'quvchi qo'shish"
      // FAB'ini avtomatik qaytaradi.
      _clearSelection();
    });
  }

  // --- YANGI (FAN BO'YICHA EXCEL HISOBOT) ---

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // YANGI: summani "150 000" ko'rinishida (minglik ajratkichlar bilan)
  // formatlaydi.
  String _formatSum(num amount) {
    final s = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  // YANGI: Excel varaq nomi uchun yaroqsiz belgilarni tozalaydi va
  // 31-belgi chegarasiga moslaydi (Excel talabi).
  String _sanitizeSheetName(String name) {
    var s = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_').trim();
    if (s.length > 28) s = s.substring(0, 28);
    return s.isEmpty ? 'Fan' : s;
  }

  // YANGI (FAN BO'YICHA EXCEL HISOBOT): "Hisobot" tugmasi bosilganda
  // ishga tushadi. Faqat TANLANGAN fan (_selectedSubjectTab) uchun
  // ishlaydi. Guruh -> a'zolar ro'yxatini tuzadi, fan bo'yicha ENG
  // ERTA qo'shilgan sanadan hozirgi oygacha bo'lgan oy ustunlarini
  // hisoblaydi, so'ng Excel faylni yaratib ulashadi.
  Future<void> _generateSubjectReport() async {
    if (_isGeneratingReport) return;
    final subjectId = _selectedSubjectTab;
    if (subjectId == null) return;
    if (!Get.isRegistered<CrmController>()) {
      _showSnack("Ma'lumot topilmadi");
      return;
    }

    setState(() => _isGeneratingReport = true);
    try {
      final crm = Get.find<CrmController>();
      final allStudents = crm.allStudents.where((s) => s['isArchived'] != true).toList();

      final subjectName = _subjects.firstWhere(
            (s) => s['id'] == subjectId,
        orElse: () => {'name': 'Fan'},
      )['name']!;

      final subjectGroups = _groups.where((g) => g['subjectId'] == subjectId).toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));

      if (subjectGroups.isEmpty) {
        _showSnack("Bu fanda guruh topilmadi");
        return;
      }

      // YANGI: har bir guruh uchun (maktab o'quvchilaridan tashqari)
      // a'zolarini alifbo tartibida yig'amiz, shu bilan birga FAN
      // bo'yicha ENG ERTA qo'shilgan sanani topamiz — bu hisobotdagi
      // oy ustunlari sonini belgilaydi.
      final Map<String, List<Map<String, dynamic>>> membersByGroup = {};
      DateTime? earliestJoin;
      for (final g in subjectGroups) {
        final groupId = g['id']!;
        final members = allStudents.where((s) {
          if (_isSchoolStudent(s)) return false;
          final groupIds = List<String>.from(s['centerGroupIds'] ?? []);
          return groupIds.contains(groupId);
        }).toList()
          ..sort((a, b) => _fullName(a).toLowerCase().compareTo(_fullName(b).toLowerCase()));
        membersByGroup[groupId] = members;

        for (final m in members) {
          final joinDate = _subjectJoinDate(m, subjectId);
          if (joinDate != null && (earliestJoin == null || joinDate.isBefore(earliestJoin!))) {
            earliestJoin = joinDate;
          }
        }
      }

      if (earliestJoin == null) {
        _showSnack("Bu fanda hali qo'shilgan o'quvchi yo'q");
        return;
      }

      // YANGI: eng erta qo'shilgan oydan HOZIRGI oygacha bo'lgan
      // barcha oylar — "ustunlar ko'payadi" talabiga mos.
      final now = DateTime.now();
      final monthKeys = <String>[];
      var cursor = DateTime(earliestJoin.year, earliestJoin.month);
      final endMonth = DateTime(now.year, now.month);
      while (!cursor.isAfter(endMonth)) {
        monthKeys.add("${cursor.year}-${cursor.month.toString().padLeft(2, '0')}");
        cursor = DateTime(cursor.year, cursor.month + 1);
      }

      final bytes = _buildExcelBytes(
        subjectName: subjectName,
        subjectId: subjectId,
        groups: subjectGroups,
        membersByGroup: membersByGroup,
        monthKeys: monthKeys,
      );

      await _saveAndShareReport(bytes, subjectName);
    } catch (e) {
      debugPrint("Hisobot yaratishda xato: $e");
      _showSnack("Hisobot yaratishda xatolik yuz berdi");
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  // YANGI (FAN BO'YICHA EXCEL HISOBOT): haqiqiy Excel baytlarini
  // quradi. Har bir guruh: 1 ta sarlavha (title) qatori (guruh nomi,
  // butun kenglik bo'ylab birlashtirilgan/merge qilingan) + 1 ta
  // ustun sarlavhalari qatori (F.I.Sh. | Qo'shilgan sana | har oy
  // uchun bittadan) + har bir a'zo uchun bitta qator. Guruhlar
  // orasida 1 ta bo'sh qator qoldiriladi.
  List<int> _buildExcelBytes({
    required String subjectName,
    required String subjectId,
    required List<Map<String, String>> groups,
    required Map<String, List<Map<String, dynamic>>> membersByGroup,
    required List<String> monthKeys,
  }) {
    final workbook = xls.Excel.createExcel();
    final sheetName = _sanitizeSheetName(subjectName);

    late final xls.Sheet sheet;
    try {
      final defaultName = workbook.getDefaultSheet();
      if (defaultName != null && defaultName != sheetName) {
        workbook.rename(defaultName, sheetName);
      }
      sheet = workbook[sheetName];
    } catch (_) {
      sheet = workbook[sheetName];
    }

    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#E2E8F0'),
    );
    final groupTitleStyle = xls.CellStyle(
      bold: true,
      fontSize: 13,
      backgroundColorHex: xls.ExcelColor.fromHexString('#1E293B'),
      fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
    );
    final debtStyle = xls.CellStyle(backgroundColorHex: xls.ExcelColor.fromHexString('#FECACA'));
    final paidStyle = xls.CellStyle(backgroundColorHex: xls.ExcelColor.fromHexString('#BBF7D0'));
    final naStyle = xls.CellStyle(backgroundColorHex: xls.ExcelColor.fromHexString('#F1F5F9'));

    final totalCols = 2 + monthKeys.length; // F.I.Sh. | Qo'shilgan sana | oy1..oyN
    int rowIndex = 0;

    void setCell(int col, int row, xls.CellValue value, {xls.CellStyle? style}) {
      sheet.updateCell(
        xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        value,
        cellStyle: style,
      );
    }

    for (final g in groups) {
      final groupId = g['id']!;
      final members = membersByGroup[groupId] ?? [];

      // --- Guruh nomi (title) qatori ---
      setCell(0, rowIndex, xls.TextCellValue(g['name'] ?? 'Guruh'), style: groupTitleStyle);
      for (var c = 1; c < totalCols; c++) {
        setCell(c, rowIndex, xls.TextCellValue(''), style: groupTitleStyle);
      }
      try {
        sheet.merge(
          xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
          xls.CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: rowIndex),
        );
      } catch (e) {
        debugPrint("Yacheykalarni birlashtirishda xato (e'tiborsiz qoldirildi): $e");
      }
      rowIndex++;

      // --- Ustun sarlavhalari ---
      setCell(0, rowIndex, xls.TextCellValue("F.I.Sh."), style: headerStyle);
      setCell(1, rowIndex, xls.TextCellValue("Qo'shilgan sana"), style: headerStyle);
      for (var i = 0; i < monthKeys.length; i++) {
        setCell(2 + i, rowIndex, xls.TextCellValue(_monthKeyToLabel(monthKeys[i])), style: headerStyle);
      }
      rowIndex++;

      if (members.isEmpty) {
        setCell(0, rowIndex, xls.TextCellValue("Bu guruhda o'quvchi yo'q"));
        rowIndex++;
        rowIndex++; // guruhlar orasida bo'sh qator
        continue;
      }

      for (final m in members) {
        final studentId = m['id'] as String;
        final name = _fullName(m);
        final joinDate = _subjectJoinDate(m, subjectId);
        final joinLabel = joinDate == null
            ? "—"
            : "${joinDate.year}-${joinDate.month.toString().padLeft(2, '0')}-${joinDate.day.toString().padLeft(2, '0')}";

        setCell(0, rowIndex, xls.TextCellValue(name));
        setCell(1, rowIndex, xls.TextCellValue(joinLabel));

        for (var i = 0; i < monthKeys.length; i++) {
          final monthKey = monthKeys[i];
          final monthParts = monthKey.split('-');
          final monthDate = DateTime(int.parse(monthParts[0]), int.parse(monthParts[1]));

          if (joinDate == null || monthDate.isBefore(DateTime(joinDate.year, joinDate.month))) {
            // Hali shu fanga qo'shilmagan oy.
            setCell(2 + i, rowIndex, xls.TextCellValue("—"), style: naStyle);
            continue;
          }

          final paidKey = '$subjectId|$monthKey';
          final isPaid = (_paidKeysByStudent[studentId] ?? {}).contains(paidKey);
          if (isPaid) {
            final amount = _paidAmountByKey['$studentId|$subjectId|$monthKey'];
            setCell(
              2 + i,
              rowIndex,
              xls.TextCellValue(amount != null ? _formatSum(amount) : "To'langan"),
              style: paidStyle,
            );
          } else {
            setCell(2 + i, rowIndex, xls.TextCellValue("Qarzdor"), style: debtStyle);
          }
        }
        rowIndex++;
      }

      rowIndex++; // guruhlar orasida bo'sh qator
    }

    // YANGI: ustun kengliklari — o'qish qulay bo'lishi uchun. Bu
    // faqat kosmetik, agar sizning `excel` versiyangizda
    // setColumnWidth signature'i boshqacha bo'lsa, xavfsiz tarzda
    // e'tiborsiz qoldiriladi.
    try {
      sheet.setColumnWidth(0, 26);
      sheet.setColumnWidth(1, 16);
      for (var i = 0; i < monthKeys.length; i++) {
        sheet.setColumnWidth(2 + i, 12);
      }
    } catch (e) {
      debugPrint("Ustun kengligini sozlashda xato (e'tiborsiz qoldirildi): $e");
    }

    final bytes = workbook.save();
    if (bytes == null) {
      throw Exception("Excel faylni kodlab bo'lmadi");
    }
    return bytes;
  }

  // YANGI (FAN BO'YICHA EXCEL HISOBOT): tayyor faylni qurilma
  // xotirasiga (vaqtinchalik papka) yozadi va tizimning "ulashish"
  // oynasi orqali yuboradi (Telegram, Drive, va h.k.). Agar
  // loyihangizda allaqachon boshqa (masalan maxsus Telegram) ulashish
  // funksiyasi bo'lsa, shu metodni o'shanga moslashtirishingiz mumkin.
  Future<void> _saveAndShareReport(List<int> bytes, String subjectName) async {
    final dir = await getTemporaryDirectory();
    final safeName = subjectName.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final now = DateTime.now();
    final datePart =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final fileName = "hisobot_${safeName}_$datePart.xlsx";
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(filePath)],
      text: "$subjectName bo'yicha qarzdorlik hisoboti",
    );
  }

  @override
  Widget build(BuildContext context) {
    // YANGI: hech qanday Scaffold/AppBar YO'Q — bu faqat tarkib.
    // YANGI (SMS TANLASH): endi Column Stack ichida — tanlov paneli
    // ro'yxat ustidan suzib chiqishi uchun.
    return Stack(
      children: [
        Column(
          children: [
            if (!_isLoadingGroups && _subjects.isNotEmpty) _buildFilterSection(),

            Expanded(
              // YANGI: Obx + CrmController.allStudents — endi bu ekran
              // o'zining alohida Firestore listener'iga ega EMAS, balki
              // ilovaning boshqa joylarida (masalan Maktab tomonida)
              // ALLAQACHON yuklangan umumiy keshni o'qiydi. READ = 0.
              child: Obx(() {
                if (!Get.isRegistered<CrmController>()) {
                  return const Center(child: Text("Ma'lumot topilmadi", style: TextStyle(color: Color(0xFF94A3B8))));
                }
                final crm = Get.find<CrmController>();

                var students = crm.allStudents.where((s) {
                  return s['isArchived'] != true;
                }).toList();

                if (_selectedGroupFilter != null) {
                  students = students.where((s) {
                    final groupIds = List<String>.from(s['centerGroupIds'] ?? []);
                    return groupIds.contains(_selectedGroupFilter);
                  }).toList();
                }

                // YANGI: qidiruv so'zi endi widget.searchQuery'dan keladi.
                final query = widget.searchQuery.trim().toLowerCase();
                if (query.isNotEmpty) {
                  students = students.where((s) {
                    final name = _fullName(s).toLowerCase();
                    return name.contains(query);
                  }).toList();
                }

                // YANGI (ALIFBO TARTIBI): ro'yxat endi har doim ism-familiya
                // bo'yicha (Familiya Ism, _fullName qanday tuzsa, shunday)
                // ALIFBO tartibida ko'rsatiladi — filtr/qidiruvdan keyin,
                // lekin ro'yxatni chizishdan oldin saralanadi.
                students.sort((a, b) => _fullName(a).toLowerCase().compareTo(_fullName(b).toLowerCase()));

                if (students.isEmpty) {
                  // YANGI: bo'sh holatda ham pastga tortib yangilash
                  // ishlashi uchun AlwaysScrollableScrollPhysics bilan.
                  return RefreshIndicator(
                    color: const Color(0xFF10B981),
                    onRefresh: () async {
                      await _loadGroupsAndSubjects();
                      await _loadPayments();
                      await _loadDebtSmsStatus();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(child: Text("O'quvchi topilmadi", style: TextStyle(color: Color(0xFF94A3B8)))),
                      ],
                    ),
                  );
                }

                // YANGI (FAN BO'YICHA BELGILASH): endi GURUH emas, balki
                // tanlangan FAN asosida hisoblanadi — shu fanning barcha
                // guruhlaridagi qarzdor o'quvchilar (joriy guruh chip
                // filtridan qat'iy nazar), maktab o'quvchilari va qarzi
                // yo'qlar chiqarib tashlangan holda. To'lov/guruh
                // ma'lumotlari hali yuklanayotgan bo'lsa, noto'g'ri
                // (chala) natija bermaslik uchun bo'sh ro'yxat qaytariladi.
                final selectableSubjectStudents = (_selectedSubjectTab == null || _isLoadingGroups || _isLoadingPayments)
                    ? <Map<String, dynamic>>[]
                    : _selectableDebtorsForSubject(_selectedSubjectTab!);

                // YANGI: PASTGA TORTIB YANGILASH — chip bosilganda avtomatik
                // qayta o'qish OLIB TASHLANDI (bu har safar qo'shimcha read
                // hosil qilardi); endi foydalanuvchi kerak bo'lganda o'zi
                // pastga tortib yangilaydi (guruh/fan ma'lumotlari VA
                // to'lovlar birga qayta yuklanadi).
                return Column(
                  children: [
                    // YANGI (FAN BO'YICHA EXCEL HISOBOT): bu qator endi
                    // fan tanlangan HAR qanday holatda ko'rinadi (qarzdor
                    // bor-yo'qligidan qat'iy nazar) — chunki "Hisobot"
                    // tugmasi BARCHA (qarzdor + to'lagan) o'quvchilarni
                    // qamraydigan Excel yaratadi, faqat qarzdorlarni emas.
                    if (_selectedSubjectTab != null && !_isLoadingGroups && !_isLoadingPayments)
                      _buildSelectAllBar(selectableSubjectStudents),
                    Expanded(
                      child: RefreshIndicator(
                          color: const Color(0xFF10B981),
                          onRefresh: () async {
                            await _loadGroupsAndSubjects();
                            await _loadPayments();
                            await _loadDebtSmsStatus();
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final data = students[index];
                              final studentId = data['id'] as String;
                              final name = _fullName(data);
                              final isSelected = _selectedIds.contains(studentId);

                              // YANGI: avval maktab o'quvchisi ekanini tekshiramiz —
                              // agar shunday bo'lsa, qarz UMUMAN hisoblanmaydi va
                              // "Qarzi yo'q" bilan aralashtirilmasdan ALOHIDA
                              // "Maktab o'quvchisi" belgisi ko'rsatiladi. Bunday
                              // o'quvchi endi tanlovga HAM kira olmaydi.
                              final isSchoolStudent = _isSchoolStudent(data);
                              final debtMonths = isSchoolStudent
                                  ? <String>[]
                                  : (_isLoadingGroups || _isLoadingPayments ? null : _computeDebtMonths(studentId, data));
                              // YANGI: shu o'quvchiga oxirgi marta qarzdorlik
                              // SMS'i qachon yuborilgani (bo'lsa).
                              final lastDebtSms = _lastDebtSmsByStudent[studentId];

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  // YANGI (SMS TANLASH): tanlov rejimida oddiy
                                  // bosish profilga o'tkazmaydi, balki
                                  // tanlash/bekor qilishga xizmat qiladi —
                                  // BUNDAN TASHQARI, maktab o'quvchisi ustida
                                  // (tanlashga kira olmagani uchun) bosish
                                  // baribir profilga o'tkazadi.
                                  onTap: () {
                                    if (_selectionMode && !isSchoolStudent) {
                                      _toggleSelect(data);
                                    } else {
                                      Get.to(() => StudentProfileView(studentId: studentId, subjectId: '', studentName: name));
                                    }
                                  },
                                  // YANGI (SMS TANLASH): uzoq bosish — tanlov
                                  // rejimini boshlaydi (yoki shu o'quvchini
                                  // qo'shadi/olib tashlaydi). Maktab
                                  // o'quvchilari uchun _toggleSelect ichida
                                  // avtomatik e'tiborsiz qoldiriladi.
                                  onLongPress: () => _toggleSelect(data),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF10B981).withOpacity(0.06) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF10B981) : const Color(0xFFEEF2F6),
                                        width: isSelected ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // YANGI (SMS TANLASH): tanlov rejimida
                                        // avatar o'rniga checkbox-doira chiqadi —
                                        // MAKTAB O'QUVCHISI BO'LSA, u tanlanmasligi
                                        // uchun checkbox emas, oddiy avatar
                                        // ko'rsatiladi (tanlov rejimida ham).
                                        (_selectionMode && !isSchoolStudent)
                                            ? AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          height: 42,
                                          width: 42,
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF10B981) : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                              : null,
                                        )
                                            : Container(
                                          height: 42,
                                          width: 42,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withOpacity(0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14.5)),
                                              const SizedBox(height: 3),
                                              if (isSchoolStudent)
                                                const Row(
                                                  children: [
                                                    Icon(Icons.school_rounded, size: 13, color: Color(0xFF3B82F6)),
                                                    SizedBox(width: 4),
                                                    Text("Maktab o'quvchisi", style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                                                  ],
                                                )
                                              else if (debtMonths == null)
                                                const Text("Hisoblanmoqda...", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)))
                                              else if (debtMonths.isEmpty)
                                                  const Row(
                                                    children: [
                                                      Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                                      SizedBox(width: 4),
                                                      Text("Qarzi yo'q", style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                                    ],
                                                  )
                                                else
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFDC2626)),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          "Qarz: ${debtMonths.join(', ')}",
                                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              // YANGI (SMS YASHIL BELGI): qarzdorlik
                                              // haqida SMS allaqachon yuborilgan
                                              // bo'lsa, endi buni YASHIL rangda
                                              // (ilovaning asosiy accent rangi)
                                              // ko'rsatamiz — qayta yuborishdan
                                              // oldin bir qarashda bilib olish uchun.
                                              if (lastDebtSms != null) ...[
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.mark_email_read_rounded, size: 12, color: Color(0xFF10B981)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "Qarz SMS: ${_formatSmsDate(lastDebtSms.toDate())}",
                                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (!_selectionMode || isSchoolStudent)
                                          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),

        // YANGI (SMS TANLASH): pastda suzuvchi tanlov paneli — faqat
        // kamida 1 ta o'quvchi tanlanganda ko'rinadi.
        if (_selectedIds.isNotEmpty) _buildSelectionBar(),
      ],
    );
  }

  // YANGI (FAN BO'YICHA BELGILASH + HISOBOT): fan tanlanganda
  // ko'rinadigan qator. Chapda qancha qarzdor borligi (yoki yo'qligi)
  // yozilgan, o'ngda ikkita tugma: "Hisobot" (HAR DOIM, fan
  // tanlangan bo'lsa) va "Fan bo'yicha belgilash" (faqat qarzdor
  // bo'lsa). `selectable` ro'yxatida maktab o'quvchilari va qarzi
  // yo'q o'quvchilar ALLAQACHON yo'q.
  Widget _buildSelectAllBar(List<Map<String, dynamic>> selectable) {
    final allSelected = selectable.isNotEmpty && selectable.every((s) => _selectedIds.contains(s['id']));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectable.isEmpty ? "Bu fanda qarzdor yo'q" : "Fanda qarzdor: ${selectable.length} ta o'quvchi",
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // YANGI (FAN BO'YICHA EXCEL HISOBOT)
              if (_isGeneratingReport)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: _generateSubjectReport,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.table_chart_rounded, size: 17, color: Color(0xFF3B82F6)),
                  label: const Text(
                    "Hisobot",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                  ),
                ),
              if (selectable.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _toggleSelectAll(selectable, !allSelected),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    allSelected ? Icons.remove_done_rounded : Icons.done_all_rounded,
                    size: 17,
                    color: const Color(0xFF10B981),
                  ),
                  label: Text(
                    allSelected ? "Tanlovni bekor qilish" : "Fan bo'yicha belgilash",
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // YANGI (SMS TANLASH): tanlangan o'quvchilar soni, "Bekor qilish" va
  // "Ko'rish" tugmalarini o'z ichiga olgan suzuvchi panel.
  Widget _buildSelectionBar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${_selectedIds.length} ta o'quvchi tanlandi",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              TextButton(
                onPressed: _clearSelection,
                child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _openDebtSmsPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text("Ko'rish"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    final groupsForSelectedSubject = _selectedSubjectTab == null
        ? <Map<String, String>>[]
        : _groups.where((g) => g['subjectId'] == _selectedSubjectTab).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _subjects.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  final isActive = _selectedSubjectTab == null;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _selectedSubjectTab = null;
                      _selectedGroupFilter = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text("Hammasi", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF334155))),
                      ),
                    ),
                  );
                }
                final subj = _subjects[i - 1];
                final isActive = subj['id'] == _selectedSubjectTab;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() {
                    _selectedSubjectTab = subj['id'];
                    _selectedGroupFilter = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(subj['name']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? Colors.white : const Color(0xFF334155))),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_selectedSubjectTab != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: groupsForSelectedSubject.isEmpty
                  ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text("Bu fanda guruh topilmadi", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              )
                  : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groupsForSelectedSubject.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final g = groupsForSelectedSubject[i];
                  final isActive = g['id'] == _selectedGroupFilter;
                  return InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _selectedGroupFilter = isActive ? null : g['id']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE)),
                      ),
                      child: Center(
                        child: Text(g['name']!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF1E40AF))),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}