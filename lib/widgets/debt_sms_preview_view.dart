import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// MUHIM: haqiqiy import yo'lingizga moslang — SMSService shu yerda
// ta'riflangan (platform channel orqali, telefonning o'z SIM-
// kartasidan to'g'ridan-to'g'ri SMS yuboradi, "Kelmaganlar" oqimida
// ham ishlatilgan).
import '../services/sms_service.dart';

// YANGI (MOSLIK UCHUN): ba'zi loyihalarda Dart SDK versiyasi record
// turini ({a, b}) qo'llab-quvvatlamasligi mumkin — shu sabab oddiy
// klassga o'tkazildi (build xatosining ehtimoliy manbai edi).
class _SmsRecipient {
  final String phone;
  final bool isParent;
  const _SmsRecipient(this.phone, this.isParent);
}

/// YANGI: Tanlangan o'quvchilarga qarzdorlik haqida SMS yuborish uchun
/// ko'rish/tasdiqlash ekrani.
///
/// Bu ekran CenterAllStudentsTab'dan "Ko'rish" tugmasi orqali ochiladi.
///
/// Tepada — tanlangan o'quvchilar orasida uchraydigan BARCHA qarzdor
/// oylar chip shaklida chiqadi (standart holatda hammasi tanlangan).
/// Foydalanuvchi kerak bo'lmagan oyni o'chirib qo'yishi mumkin.
///
/// Pastda — har bir o'quvchi va uning (filtrlangan) qarzi, ENDI FAN
/// BO'YICHA AJRATILGAN holda (masalan "Matematika: 2026 Sent, Okt").
/// "SMS yuborish" bosilganda avval TASDIQLASH so'raladi, so'ng
/// yuborilgach har bir o'quvchi qatorida "✓ SMS yuborildi" ko'rinadi.
///
/// YANGI (XAVFSIZ OMMAVIY YUBORISH): SMS'lar telefonning o'z SIM-
/// kartasidan (bulutli gateway EMAS) yuborilgani uchun, ko'p sonli
/// (masalan 300+) o'quvchiga BIR ZUMDA, pauzasiz yuborish operator
/// tomonidan spam deb baholanib, raqamning vaqtincha bloklanishiga
/// olib kelishi mumkin. Shu sabab endi: (1) har bir SMS orasiga
/// kichik pauza, (2) har _batchSize tadan keyin uzunroq pauza,
/// (3) yuborish jarayonida "N/JAMI" progress ko'rsatiladi, (4)
/// foydalanuvchi jarayonni istalgan payt "Bekor qilish" orqali
/// to'xtata oladi (shu paytgacha yuborilganlari saqlanib qoladi).
class DebtSmsPreviewView extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  // studentId -> qarzdor yozuvlar ro'yxati: {subjectId, subjectName, monthKey}
  final Map<String, List<Map<String, String>>> debtEntriesByStudent;
  final String Function(Map<String, dynamic>) fullNameBuilder;
  final String Function(String monthKey) monthLabelBuilder;

  const DebtSmsPreviewView({
    super.key,
    required this.students,
    required this.debtEntriesByStudent,
    required this.fullNameBuilder,
    required this.monthLabelBuilder,
  });

  @override
  State<DebtSmsPreviewView> createState() => _DebtSmsPreviewViewState();
}

class _DebtSmsPreviewViewState extends State<DebtSmsPreviewView> {
  late final List<String> _allMonthKeys;
  late Set<String> _selectedMonthKeys;
  bool _isSending = false;

  // YANGI (XAVFSIZ OMMAVIY YUBORISH): yuborish jarayonidagi progress
  // va bekor qilish uchun holat.
  int _sentCount = 0;
  int _totalToSend = 0;
  bool _cancelRequested = false;

  // YANGI (XAVFSIZ OMMAVIY YUBORISH): har bir SMS orasidagi kichik
  // pauza — operator tomonidan "spam burst" deb baholanish xavfini
  // kamaytiradi. Har _batchSize tadan keyin esa biroz uzunroq
  // "nafas olish" pauzasi qo'shiladi (operatorlar odatda daqiqadagi
  // portlashni emas, tekis oqimni yoqtiradi). Bu raqamlar taxminiy —
  // agar baribir muammo (bloklanish, kechikish) kuzatilsa, ularni
  // kattalashtiring.
  static const Duration _delayBetweenSms = Duration(milliseconds: 400);
  static const int _batchSize = 25;
  static const Duration _delayBetweenBatches = Duration(seconds: 3);
  // YANGI: shu sondan ko'p qabul qiluvchi bo'lsa, tasdiqlash
  // varag'ida ogohlantirish va taxminiy davomiylik ko'rsatiladi.
  static const int _warnThreshold = 30;

  // YANGI: SMS matnida foydalanuvchi TAHRIRLAY OLADIGAN shablon.
  // {ism} — o'quvchi ismi, {qarz} — fan/oy bo'yicha qarz ro'yxati
  // bilan yuborishdan oldin avtomatik almashtiriladi.
  late final TextEditingController _templateController;
  static const String _defaultTemplate =
      "Assalomu alaykum! {ism} uchun quyidagi fan(lar) bo'yicha to'lov "
      "qarzdorligi mavjud:\n{qarz}\nIltimos, imkon qadar tezroq to'lovni "
      "amalga oshirishingizni so'raymiz. Rahmat!";

  // YANGI: SMS matnida oy nomi endi TO'LIQ yoziladi ("2026-yil
  // sentyabr"), ekrandagi qisqa chip'lardagi kabi "Sent" EMAS — ota-
  // onalar tushunmasligi mumkin bo'lgan qisqartmadan qochish uchun.
  static const List<String> _uzMonthFull = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
  ];

  String _fullMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return "$year-yil ${_uzMonthFull[month - 1]}";
  }

  // YANGI (XAVFSIZ OMMAVIY YUBORISH): berilgan sondagi qabul
  // qiluvchiga taxminan qancha vaqt ketishini (pauzalar hisobga
  // olingan holda) inson o'qiy oladigan shaklda qaytaradi.
  String _estimateDuration(int count) {
    if (count <= 1) return "bir zumda";
    final totalMs = (count - 1) * _delayBetweenSms.inMilliseconds +
        ((count - 1) ~/ _batchSize) * _delayBetweenBatches.inMilliseconds;
    final totalSeconds = totalMs / 1000;
    if (totalSeconds < 60) return "~${totalSeconds.round()} soniya";
    final minutes = (totalSeconds / 60).round();
    return "~$minutes daqiqa";
  }

  // YANGI: SMS allaqachon yuborilgan o'quvchilar (shu ekran sessiyasi
  // doirasida) — qayta yuborib yubormaslik va foydalanuvchiga aniq
  // ko'rinishi uchun. Qiymat — SMS ota-ona raqamiga (true) yoki
  // o'quvchining o'z raqamiga (false) yuborilganini bildiradi.
  final Map<String, bool> _sentRecipientIsParent = {};

  // YANGI (TASHXIS UCHUN): "telefon topilmadi" deb o'tkazib
  // yuborilgan o'quvchilar — ism va aynan qaysi maydonlarni
  // tekshirganimiz bilan birga, "SMS yuborish" tugagach ko'rsatiladigan
  // xabarda ANIQ kim va NEGA o'tkazib yuborilganini ko'rish uchun.
  final List<String> _skippedNoPhoneNames = [];

  @override
  void initState() {
    super.initState();
    _templateController = TextEditingController(text: _defaultTemplate);
    final all = <String>{};
    for (final list in widget.debtEntriesByStudent.values) {
      all.addAll(list.map((e) => e['monthKey']!));
    }
    _allMonthKeys = all.toList()..sort();
    _selectedMonthKeys = Set<String>.from(_allMonthKeys); // standart: hammasi
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _studentEntriesInSelection(String studentId) {
    final entries = widget.debtEntriesByStudent[studentId] ?? [];
    final filtered = entries.where((e) => _selectedMonthKeys.contains(e['monthKey'])).toList();
    filtered.sort((a, b) {
      final c = a['monthKey']!.compareTo(b['monthKey']!);
      if (c != 0) return c;
      return a['subjectName']!.compareTo(b['subjectName']!);
    });
    return filtered;
  }

  // YANGI (FAN BO'YICHA): bir xil fanning barcha oylarini birlashtiradi.
  // labelBuilder orqali chaqiruvchi TANLAYDI — qisqa (ekran, chip'lar
  // uchun) yoki to'liq (SMS matni uchun) oy nomi.
  Map<String, List<String>> _groupBySubject(
      List<Map<String, String>> entries,
      String Function(String monthKey) labelBuilder,
      ) {
    final Map<String, List<String>> grouped = {};
    for (final e in entries) {
      grouped.putIfAbsent(e['subjectName']!, () => []).add(labelBuilder(e['monthKey']!));
    }
    return grouped;
  }

  // YANGI: yuborishga TAYYOR (hali yuborilmagan + tanlangan oylar
  // bo'yicha qarzi bor) o'quvchilar soni.
  int get _eligibleCount => widget.students.where((s) {
    final id = s['id'] as String;
    return !_sentRecipientIsParent.containsKey(id) && _studentEntriesInSelection(id).isNotEmpty;
  }).length;

  // YANGI (TUZATILDI — KENGROQ QIDIRUV + TASHXIS): avval OTA-ONA
  // raqamini qidiradi — endi bir nechta ehtimoliy maydon nomi bilan
  // (parentPhone/fatherPhone/motherPhone/parentPhoneNumber/guardianPhone).
  // Bironta ham topilmasa, O'QUVCHINING O'ZINING raqamiga o'tadi — bu
  // yerda ham bir nechta ehtimoliy nom tekshiriladi
  // (phone/studentPhone/phoneNumber/tel/telefon). MUHIM (TODO): agar
  // baribir ishlamasa, demak haqiqiy Firestore hujjatingizda bu
  // maydon BOSHQA nom bilan saqlanadi — pastdagi debugPrint orqali
  // "Mavjud maydonlar" ro'yxatini konsolda ko'rib, aniq nomni shu
  // funksiyaga qo'shing.
  _SmsRecipient? _recipientOf(Map<String, dynamic> data) {
    final parentRaw = data['parentPhone'] ??
        data['fatherPhone'] ??
        data['motherPhone'] ??
        data['parentPhoneNumber'] ??
        data['guardianPhone'];
    final parentPhone = parentRaw?.toString().trim();
    if (parentPhone != null && parentPhone.isNotEmpty) {
      return _SmsRecipient(parentPhone, true);
    }

    final studentRaw = data['phone'] ??
        data['studentPhone'] ??
        data['phoneNumber'] ??
        data['tel'] ??
        data['telefon'];
    final studentPhone = studentRaw?.toString().trim();
    if (studentPhone != null && studentPhone.isNotEmpty) {
      return _SmsRecipient(studentPhone, false);
    }

    return null;
  }

  // YANGI: endi qattiq yozilgan matn o'rniga, foydalanuvchi TAHRIRLAY
  // OLADIGAN shablon to'ldiriladi (yuborishdan oldingi tasdiqlash
  // oynasida ko'rinadi va o'zgartirilishi mumkin). {ism} — o'quvchi
  // ismi, {qarz} — fan/oy bo'yicha qarz ro'yxati bilan almashtiriladi;
  // oy nomlari TO'LIQ yoziladi ("2026-yil sentyabr").
  String _buildMessage(String template, String fullName, List<Map<String, String>> entries) {
    final grouped = _groupBySubject(entries, _fullMonthLabel);
    final qarzText = grouped.entries.map((e) => "- ${e.key}: ${e.value.join(', ')}").join('\n');
    return template.replaceAll('{ism}', fullName).replaceAll('{qarz}', qarzText);
  }

  // YANGI: endi HAQIQIY SMSService ishlatiladi (stub OLIB TASHLANDI) —
  // platform channel orqali telefonning o'z SIM-kartasidan yuboradi.
  // SMSService.sendSMS xato bo'lsa Exception TASHLAYDI (bool
  // qaytarmaydi), shuning uchun shu yerda try/catch bilan bool'ga
  // o'giramiz — qolgan kod (_performSend) o'zgarishsiz ishlayveradi.
  final SMSService _smsService = SMSService();

  Future<bool> _sendSingleSms(String phone, String message) async {
    try {
      await _smsService.sendSMS(phone, message);
      return true;
    } catch (e) {
      debugPrint("SMS yuborishda xato: $e");
      return false;
    }
  }

  // YANGI: "SMS yuborish" bosilganda — avval kengroq, tushunarli
  // "SMS tuzish" panelini ochamiz (pastdan chiqadigan varaq). Faqat
  // "N taga yuborish" bosilsagina haqiqiy yuborish boshlanadi.
  Future<void> _onSendPressed() async {
    if (_isSending) return;
    final targets = widget.students.where((s) {
      final id = s['id'] as String;
      return !_sentRecipientIsParent.containsKey(id) && _studentEntriesInSelection(id).isNotEmpty;
    }).toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yuborish uchun qarzdor o'quvchi qolmadi")),
      );
      return;
    }

    final confirmed = await _showSmsComposerSheet(targets);
    if (confirmed != true) return;
    await _performSend(targets, _templateController.text);
  }

  // YANGI (XAVFSIZ OMMAVIY YUBORISH): yuborish jarayonini
  // to'xtatishni so'raydi — hozirgi SMS yuborilib bo'lgach, KEYINGI
  // o'quvchiga o'tmasdan jarayon to'xtaydi. Shu paytgacha yuborilgan
  // SMS'lar (va ularning sms_feed yozuvlari) saqlanib qoladi.
  void _cancelSending() {
    if (!_isSending || _cancelRequested) return;
    setState(() => _cancelRequested = true);
  }

  Future<void> _performSend(List<Map<String, dynamic>> targets, String template) async {
    setState(() {
      _isSending = true;
      _cancelRequested = false;
      _sentCount = 0;
      _totalToSend = targets.length;
    });
    int success = 0;
    int failed = 0;
    int skippedNoPhone = 0;
    _skippedNoPhoneNames.clear();

    for (var i = 0; i < targets.length; i++) {
      // YANGI (XAVFSIZ OMMAVIY YUBORISH): foydalanuvchi "Bekor
      // qilish"ni bossa, keyingi o'quvchiga o'tmasdan to'xtaymiz.
      if (_cancelRequested) break;

      final data = targets[i];
      final studentId = data['id'] as String;
      final fullName = widget.fullNameBuilder(data);
      final entries = _studentEntriesInSelection(studentId);
      final recipient = _recipientOf(data);

      if (recipient == null) {
        skippedNoPhone++;
        _skippedNoPhoneNames.add(fullName);
        // YANGI (TASHXIS UCHUN): agar avtomatik fallback (ota-ona ->
        // o'quvchi) baribir ishlamasa, aynan shu qatorni Flutter
        // konsolida ko'rib, o'quvchi hujjatida telefon raqami QAYSI
        // NOM bilan saqlanganini bilib olish mumkin.
        debugPrint(
          "Telefon raqami topilmadi: $fullName ($studentId). "
              "Hujjatdagi mavjud maydonlar: ${data.keys.toList()}",
        );
      } else {
        final message = _buildMessage(template, fullName, entries);
        try {
          final ok = await _sendSingleSms(recipient.phone, message);
          if (ok) {
            success++;
            _sentRecipientIsParent[studentId] = recipient.isParent;
            // YANGI: kuzatuv uchun payments_feed'ga o'xshash tarzda log —
            // aynan qaysi fan/oy uchun va kimning raqamiga yuborilgani
            // ham saqlanadi.
            await FirebaseFirestore.instance.collection('sms_feed').add({
              'source': 'debt',
              'studentId': studentId,
              'entries': entries,
              'sentToParent': recipient.isParent,
              'sentAt': FieldValue.serverTimestamp(),
            });
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint("SMS yuborishda xato ($studentId): $e");
          failed++;
        }
      }

      if (!mounted) return;
      setState(() => _sentCount = i + 1);

      // YANGI (XAVFSIZ OMMAVIY YUBORISH): keyingi o'quvchiga o'tishdan
      // oldin kichik pauza — va har _batchSize tadan keyin uzunroq
      // pauza. Oxirgi elementdan keyin yoki bekor qilingan bo'lsa,
      // ortiqcha kutishning hojati yo'q.
      if (i < targets.length - 1 && !_cancelRequested) {
        await Future.delayed(_delayBetweenSms);
        if ((i + 1) % _batchSize == 0) {
          await Future.delayed(_delayBetweenBatches);
        }
      }
    }

    if (!mounted) return;
    setState(() => _isSending = false);

    final cancelledSuffix = _cancelRequested ? " — bekor qilindi" : "";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "SMS yuborildi: $success ta"
              "${failed > 0 ? ', xato: $failed ta' : ''}"
              "${skippedNoPhone > 0 ? ", telefon yo'q: $skippedNoPhone ta" : ''}"
              "$cancelledSuffix",
        ),
        // YANGI (TASHXIS UCHUN): telefon topilmagan o'quvchilar bo'lsa,
        // ularning ismini ko'rish uchun tezkor "Ko'rish" tugmasi.
        action: _skippedNoPhoneNames.isEmpty
            ? null
            : SnackBarAction(
          label: "Kimlar?",
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Telefon raqami topilmadi"),
                content: SingleChildScrollView(
                  child: Text(_skippedNoPhoneNames.join('\n')),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Yopish")),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // YANGI: SMS matnini tuzish/tahrirlash paneli. Endi {ism}/{qarz}
  // kabi belgilarni QO'LDA YOZISH SHART EMAS — "Ism qo'shish" va
  // "Qarz ro'yxatini qo'shish" tugmalari bosilgan joyga o'zi qo'yadi.
  // Pastda esa haqiqiy o'quvchi ma'lumoti bilan TO'LDIRILGAN NAMUNA
  // ko'rinadi — yozayotgan matn qanday chiqishini darrov ko'rasiz.
  Future<bool?> _showSmsComposerSheet(List<Map<String, dynamic>> targets) {
    final sample = targets.first;
    final sampleName = widget.fullNameBuilder(sample);
    final sampleEntries = _studentEntriesInSelection(sample['id'] as String);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void insertToken(String token) {
              final text = _templateController.text;
              final selection = _templateController.selection;
              final cursor = (selection.start >= 0 && selection.start <= text.length) ? selection.start : text.length;
              final newText = text.replaceRange(cursor, cursor, token);
              _templateController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: cursor + token.length),
              );
              setSheetState(() {});
            }

            final preview = _buildMessage(_templateController.text, sampleName, sampleEntries);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: DraggableScrollableSheet(
                initialChildSize: 0.88,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (ctx, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                          ),
                        ),
                        Text(
                          "${targets.length} ta o'quvchiga SMS",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Matnni o'zingizga qulay tarzda yozing — ism va qarz ro'yxati pastdagi tugmalar orqali avtomatik qo'shiladi",
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                        ),

                        // YANGI (XAVFSIZ OMMAVIY YUBORISH): ko'p sonli
                        // qabul qiluvchi bo'lsa, foydalanuvchini oldindan
                        // ogohlantiramiz — nega sekinroq ketayotganini va
                        // taxminan qancha vaqt ketishini tushunishi uchun.
                        if (targets.length > _warnThreshold) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${targets.length} ta SMS operatorni asrash uchun ataylab sekinroq, "
                                        "birma-bir yuboriladi — taxminan ${_estimateDuration(targets.length)} "
                                        "davom etadi. Jarayonda istalgan payt to'xtatishingiz mumkin.",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        TextField(
                          controller: _templateController,
                          minLines: 5,
                          maxLines: 10,
                          onChanged: (_) => setSheetState(() {}),
                          style: const TextStyle(fontSize: 14, height: 1.4),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // YANGI: endi {ism}/{qarz} yozish o'rniga —
                        // shu tugmalarni bosish kifoya.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF3B82F6)),
                              label: const Text("+ Ism"),
                              backgroundColor: const Color(0xFFEFF6FF),
                              side: BorderSide.none,
                              onPressed: () => insertToken('{ism}'),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFDC2626)),
                              label: const Text("+ Qarz ro'yxati"),
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: BorderSide.none,
                              onPressed: () => insertToken('{qarz}'),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF64748B)),
                              label: const Text("Standart matn"),
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: BorderSide.none,
                              onPressed: () {
                                _templateController.text = _defaultTemplate;
                                setSheetState(() {});
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Text(
                          "QANDAY KO'RINADI (namuna):",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            preview,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "($sampleName uchun namuna — boshqa o'quvchilarga o'z ismi/qarzi bilan boradi)",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Bekor qilish", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text("${targets.length} taga yuborish", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        title: Text("Qarzdorlik SMS (${widget.students.length} ta o'quvchi)"),
      ),
      body: Column(
        children: [
          if (_allMonthKeys.isNotEmpty) _buildMonthFilter(),
          Expanded(child: _buildStudentList()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        // YANGI (XAVFSIZ OMMAVIY YUBORISH): yuborish jarayonida
        // oddiy spinner o'rniga endi "N/JAMI" progress va "Bekor
        // qilish" tugmasi ko'rsatiladi.
        child: _isSending ? _buildSendingBar() : _buildSendButton(),
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _eligibleCount == 0 ? null : _onSendPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.sms_rounded),
        label: Text(
          _eligibleCount == 0 ? "Yuborish uchun yo'q" : "SMS yuborish ($_eligibleCount ta)",
        ),
      ),
    );
  }

  // YANGI (XAVFSIZ OMMAVIY YUBORISH): yuborish jarayonidagi qator —
  // chapda "Bekor qilish", o'ngda progress ("120/331 yuborilmoqda").
  Widget _buildSendingBar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _cancelRequested ? null : _cancelSending,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _cancelRequested ? "To'xtatilmoqda..." : "Bekor qilish",
                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  "Yuborilmoqda... ($_sentCount/$_totalToSend)",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthFilter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Qaysi oylar uchun SMS yuborish mumkin",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allMonthKeys.map((key) {
              final isActive = _selectedMonthKeys.contains(key);
              return InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() {
                  if (isActive) {
                    _selectedMonthKeys.remove(key);
                  } else {
                    _selectedMonthKeys.add(key);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: isActive ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    widget.monthLabelBuilder(key),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (widget.students.isEmpty) {
      return const Center(child: Text("O'quvchi tanlanmagan"));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = widget.students[index];
        final studentId = data['id'] as String;
        final name = widget.fullNameBuilder(data);
        final entries = _studentEntriesInSelection(studentId);
        final grouped = _groupBySubject(entries, widget.monthLabelBuilder);
        final isSent = _sentRecipientIsParent.containsKey(studentId);
        final sentToParent = _sentRecipientIsParent[studentId];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSent ? const Color(0xFF10B981).withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSent ? const Color(0xFF10B981) : const Color(0xFFEEF2F6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 38,
                width: 38,
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
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Color(0xFF1E293B))),
                    const SizedBox(height: 5),
                    // YANGI: SMS yuborilgan bo'lsa — buni aniq ko'rsatamiz.
                    if (isSent)
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            sentToParent == true ? "SMS yuborildi (ota-onaga)" : "SMS yuborildi (o'quvchiga)",
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    else if (entries.isEmpty)
                      const Text("Tanlangan oylar uchun qarzi yo'q", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                    else
                    // YANGI (FAN BO'YICHA): har bir fan alohida qatorda.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: grouped.entries
                            .map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            "${g.key}: ${g.value.join(', ')}",
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                          ),
                        ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}