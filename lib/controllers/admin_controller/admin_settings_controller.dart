import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Ilova sozlamalari — hozircha faqat SMS shablonlari.
/// Firestore manzili: BITTA hujjat 'settings/sms_templates'.
///
/// YANGI: Davomat shablonlari endi MAKTAB va MARKAZ uchun ALOHIDA —
/// chunki bir xil matnning ikkalasiga ham ketishi mantiqsiz edi
/// (Markazda "guruh/fan"ga, Maktabda "sinf/fan"ga tegishli bo'lishi
/// kerak). Firestore maydonlari:
///   - 'attendance' / 'attendancePresent' — FAQAT MAKTAB uchun
///   - 'centerAttendance' / 'centerAttendancePresent' — FAQAT MARKAZ uchun
class AdminSettingsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _docPath = 'settings';
  static const String _docId = 'sms_templates';

  // --- MAKTAB davomat shablonlari ---
  final TextEditingController attendanceController = TextEditingController();
  final TextEditingController attendancePresentController = TextEditingController();

  // --- YANGI: MARKAZ davomat shablonlari (alohida) ---
  final TextEditingController centerAttendanceController = TextEditingController();
  final TextEditingController centerAttendancePresentController = TextEditingController();

  final TextEditingController paymentDelayController = TextEditingController();
  final TextEditingController examResultController = TextEditingController();
  final TextEditingController paymentReceivedController = TextEditingController();

  var isLoading = true.obs;
  var isSavingAttendance = false.obs;
  var isSavingAttendancePresent = false.obs;
  var isSavingCenterAttendance = false.obs; // YANGI
  var isSavingCenterAttendancePresent = false.obs; // YANGI
  var isSavingPaymentDelay = false.obs;
  var isSavingExamResult = false.obs;
  var isSavingPaymentReceived = false.obs;

  var attendanceDirty = false.obs;
  var attendancePresentDirty = false.obs;
  var centerAttendanceDirty = false.obs; // YANGI
  var centerAttendancePresentDirty = false.obs; // YANGI
  var paymentDelayDirty = false.obs;
  var examResultDirty = false.obs;
  var paymentReceivedDirty = false.obs;

  String _originalAttendance = '';
  String _originalAttendancePresent = '';
  String _originalCenterAttendance = ''; // YANGI
  String _originalCenterAttendancePresent = ''; // YANGI
  String _originalPaymentDelay = '';
  String _originalExamResult = '';
  String _originalPaymentReceived = '';

  static const String defaultAttendanceTemplate =
      "Hurmatli ota-ona! {ism} bugun ({sana}) {sinf} sinf darsiga kelmadi.";
  static const String defaultAttendancePresentTemplate =
      "Hurmatli ota-ona! {ism} bugun ({sana}) {sinf} sinf darsiga keldi.";

  // YANGI: Markaz uchun standart matnlar — "{sinf}" o'rniga "{guruh}"
  // joy-belgisi ishlatiladi, chunki bu Markazning guruh/fan nomiga
  // (masalan "Matematika-1") tegishli — "sinf" so'zi Maktabga xos va
  // bu yerda chalkashtiradi.
  static const String defaultCenterAttendanceTemplate =
      "Hurmatli ota-ona! {ism} bugun ({sana}) {guruh} guruhiga kelmadi.";
  static const String defaultCenterAttendancePresentTemplate =
      "Hurmatli ota-ona! {ism} bugun ({sana}) {guruh} guruhiga keldi.";

  static const String defaultPaymentDelayTemplate =
      "Hurmatli ota-ona! {ism} uchun to'lov {kechikkanKun} kun kechikdi. Qarzdorlik: {miqdor} so'm.";
  static const String defaultExamResultTemplate =
      "Hurmatli ota-ona! {ism} \"{imtihon}\" imtihonidan {ball} natija oldi.";
  static const String defaultPaymentReceivedTemplate =
      "Hurmatli ota-ona! {ism} uchun {miqdor} so'm to'lov {sana} sanasida qabul qilindi. Rahmat!";

  @override
  void onInit() {
    super.onInit();
    _loadTemplates();

    attendanceController.addListener(() {
      attendanceDirty.value = attendanceController.text != _originalAttendance;
    });
    attendancePresentController.addListener(() {
      attendancePresentDirty.value = attendancePresentController.text != _originalAttendancePresent;
    });
    centerAttendanceController.addListener(() { // YANGI
      centerAttendanceDirty.value = centerAttendanceController.text != _originalCenterAttendance;
    });
    centerAttendancePresentController.addListener(() { // YANGI
      centerAttendancePresentDirty.value = centerAttendancePresentController.text != _originalCenterAttendancePresent;
    });
    paymentDelayController.addListener(() {
      paymentDelayDirty.value = paymentDelayController.text != _originalPaymentDelay;
    });
    examResultController.addListener(() {
      examResultDirty.value = examResultController.text != _originalExamResult;
    });
    paymentReceivedController.addListener(() {
      paymentReceivedDirty.value = paymentReceivedController.text != _originalPaymentReceived;
    });
  }

  Future<void> _loadTemplates() async {
    isLoading.value = true;
    try {
      final doc = await _db.collection(_docPath).doc(_docId).get();
      final data = doc.data() ?? {};

      _originalAttendance = data['attendance'] ?? defaultAttendanceTemplate;
      _originalAttendancePresent = data['attendancePresent'] ?? defaultAttendancePresentTemplate;
      _originalCenterAttendance = data['centerAttendance'] ?? defaultCenterAttendanceTemplate; // YANGI
      _originalCenterAttendancePresent = data['centerAttendancePresent'] ?? defaultCenterAttendancePresentTemplate; // YANGI
      _originalPaymentDelay = data['paymentDelay'] ?? defaultPaymentDelayTemplate;
      _originalExamResult = data['examResult'] ?? defaultExamResultTemplate;
      _originalPaymentReceived = data['paymentReceived'] ?? defaultPaymentReceivedTemplate;

      attendanceController.text = _originalAttendance;
      attendancePresentController.text = _originalAttendancePresent;
      centerAttendanceController.text = _originalCenterAttendance; // YANGI
      centerAttendancePresentController.text = _originalCenterAttendancePresent; // YANGI
      paymentDelayController.text = _originalPaymentDelay;
      examResultController.text = _originalExamResult;
      paymentReceivedController.text = _originalPaymentReceived;
    } catch (e) {
      debugPrint("SMS shablonlarni yuklashda xato: $e");
      _originalAttendance = defaultAttendanceTemplate;
      _originalAttendancePresent = defaultAttendancePresentTemplate;
      _originalCenterAttendance = defaultCenterAttendanceTemplate;
      _originalCenterAttendancePresent = defaultCenterAttendancePresentTemplate;
      _originalPaymentDelay = defaultPaymentDelayTemplate;
      _originalExamResult = defaultExamResultTemplate;
      _originalPaymentReceived = defaultPaymentReceivedTemplate;
      attendanceController.text = _originalAttendance;
      attendancePresentController.text = _originalAttendancePresent;
      centerAttendanceController.text = _originalCenterAttendance;
      centerAttendancePresentController.text = _originalCenterAttendancePresent;
      paymentDelayController.text = _originalPaymentDelay;
      examResultController.text = _originalExamResult;
      paymentReceivedController.text = _originalPaymentReceived;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveTemplate({
    required String field,
    required String value,
    required RxBool savingFlag,
    required void Function(String) setOriginal,
    required RxBool dirtyFlag,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      Get.snackbar("Diqqat", "Shablon matni bo'sh bo'lishi mumkin emas",
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    savingFlag.value = true;
    try {
      await _db.collection(_docPath).doc(_docId).set(
        {field: trimmed, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      setOriginal(trimmed);
      dirtyFlag.value = false;

      Get.snackbar("Saqlandi", "SMS shablon yangilandi",
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Xatolik", "Saqlashda xato: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      savingFlag.value = false;
    }
  }

  Future<void> saveAttendanceTemplate() => _saveTemplate(
    field: 'attendance',
    value: attendanceController.text,
    savingFlag: isSavingAttendance,
    setOriginal: (v) => _originalAttendance = v,
    dirtyFlag: attendanceDirty,
  );

  Future<void> saveAttendancePresentTemplate() => _saveTemplate(
    field: 'attendancePresent',
    value: attendancePresentController.text,
    savingFlag: isSavingAttendancePresent,
    setOriginal: (v) => _originalAttendancePresent = v,
    dirtyFlag: attendancePresentDirty,
  );

  // YANGI: Markaz shablonlarini saqlash.
  Future<void> saveCenterAttendanceTemplate() => _saveTemplate(
    field: 'centerAttendance',
    value: centerAttendanceController.text,
    savingFlag: isSavingCenterAttendance,
    setOriginal: (v) => _originalCenterAttendance = v,
    dirtyFlag: centerAttendanceDirty,
  );

  Future<void> saveCenterAttendancePresentTemplate() => _saveTemplate(
    field: 'centerAttendancePresent',
    value: centerAttendancePresentController.text,
    savingFlag: isSavingCenterAttendancePresent,
    setOriginal: (v) => _originalCenterAttendancePresent = v,
    dirtyFlag: centerAttendancePresentDirty,
  );

  Future<void> savePaymentDelayTemplate() => _saveTemplate(
    field: 'paymentDelay',
    value: paymentDelayController.text,
    savingFlag: isSavingPaymentDelay,
    setOriginal: (v) => _originalPaymentDelay = v,
    dirtyFlag: paymentDelayDirty,
  );

  Future<void> saveExamResultTemplate() => _saveTemplate(
    field: 'examResult',
    value: examResultController.text,
    savingFlag: isSavingExamResult,
    setOriginal: (v) => _originalExamResult = v,
    dirtyFlag: examResultDirty,
  );

  Future<void> savePaymentReceivedTemplate() => _saveTemplate(
    field: 'paymentReceived',
    value: paymentReceivedController.text,
    savingFlag: isSavingPaymentReceived,
    setOriginal: (v) => _originalPaymentReceived = v,
    dirtyFlag: paymentReceivedDirty,
  );

  @override
  void onClose() {
    attendanceController.dispose();
    attendancePresentController.dispose();
    centerAttendanceController.dispose(); // YANGI
    centerAttendancePresentController.dispose(); // YANGI
    paymentDelayController.dispose();
    examResultController.dispose();
    paymentReceivedController.dispose();
    super.onClose();
  }
}