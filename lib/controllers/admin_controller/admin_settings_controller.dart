import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Ilova sozlamalari — hozircha faqat SMS shablonlari.
/// Firestore manzili: BITTA hujjat 'settings/sms_templates' —
/// 3 ta maydon (attendance, paymentDelay, examResult). Bu sozlamalar
/// kamdan-kam o'zgaradi, shuning uchun real-time listener SHART EMAS —
/// bir martalik .get() (ochilganda) va .set(merge:true) (saqlashda) yetarli,
/// bu eng arzon yondashuv (real-time listener bu yerda ortiqcha xarajat).
class AdminSettingsController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _docPath = 'settings';
  static const String _docId = 'sms_templates';

  final TextEditingController attendanceController = TextEditingController();
  final TextEditingController paymentDelayController = TextEditingController();
  final TextEditingController examResultController = TextEditingController();
  final TextEditingController paymentReceivedController = TextEditingController(); // YANGI

  var isLoading = true.obs;
  var isSavingAttendance = false.obs;
  var isSavingPaymentDelay = false.obs;
  var isSavingExamResult = false.obs;
  var isSavingPaymentReceived = false.obs; // YANGI

  var attendanceDirty = false.obs;
  var paymentDelayDirty = false.obs;
  var examResultDirty = false.obs;
  var paymentReceivedDirty = false.obs; // YANGI

  String _originalAttendance = '';
  String _originalPaymentDelay = '';
  String _originalExamResult = '';
  String _originalPaymentReceived = ''; // YANGI

  static const String defaultAttendanceTemplate =
      "Hurmatli ota-ona! {ism} bugun ({sana}) {sinf} sinf darsiga kelmadi.";
  static const String defaultPaymentDelayTemplate =
      "Hurmatli ota-ona! {ism} uchun to'lov {kechikkanKun} kun kechikdi. Qarzdorlik: {miqdor} so'm.";
  static const String defaultExamResultTemplate =
      "Hurmatli ota-ona! {ism} \"{imtihon}\" imtihonidan {ball} natija oldi.";
  static const String defaultPaymentReceivedTemplate = // YANGI
      "Hurmatli ota-ona! {ism} uchun {miqdor} so'm to'lov {sana} sanasida qabul qilindi. Rahmat!";

  @override
  void onInit() {
    super.onInit();
    _loadTemplates();

    attendanceController.addListener(() {
      attendanceDirty.value = attendanceController.text != _originalAttendance;
    });
    paymentDelayController.addListener(() {
      paymentDelayDirty.value = paymentDelayController.text != _originalPaymentDelay;
    });
    examResultController.addListener(() {
      examResultDirty.value = examResultController.text != _originalExamResult;
    });
    paymentReceivedController.addListener(() { // YANGI
      paymentReceivedDirty.value = paymentReceivedController.text != _originalPaymentReceived;
    });
  }

  Future<void> _loadTemplates() async {
    isLoading.value = true;
    try {
      final doc = await _db.collection(_docPath).doc(_docId).get();
      final data = doc.data() ?? {};

      _originalAttendance = data['attendance'] ?? defaultAttendanceTemplate;
      _originalPaymentDelay = data['paymentDelay'] ?? defaultPaymentDelayTemplate;
      _originalExamResult = data['examResult'] ?? defaultExamResultTemplate;
      _originalPaymentReceived = data['paymentReceived'] ?? defaultPaymentReceivedTemplate; // YANGI

      attendanceController.text = _originalAttendance;
      paymentDelayController.text = _originalPaymentDelay;
      examResultController.text = _originalExamResult;
      paymentReceivedController.text = _originalPaymentReceived; // YANGI
    } catch (e) {
      debugPrint("SMS shablonlarni yuklashda xato: $e");
      // Xato bo'lsa ham foydalanuvchi bo'sh ekran ko'rmasin — standart
      // shablonlarni ko'rsatamiz, u tahrirlab saqlasa baribir Firestore'ga yoziladi.
      _originalAttendance = defaultAttendanceTemplate;
      _originalPaymentDelay = defaultPaymentDelayTemplate;
      _originalExamResult = defaultExamResultTemplate;
      _originalPaymentReceived = defaultPaymentReceivedTemplate; // YANGI
      attendanceController.text = _originalAttendance;
      paymentDelayController.text = _originalPaymentDelay;
      examResultController.text = _originalExamResult;
      paymentReceivedController.text = _originalPaymentReceived; // YANGI
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

  Future<void> savePaymentReceivedTemplate() => _saveTemplate( // YANGI
    field: 'paymentReceived',
    value: paymentReceivedController.text,
    savingFlag: isSavingPaymentReceived,
    setOriginal: (v) => _originalPaymentReceived = v,
    dirtyFlag: paymentReceivedDirty,
  );

  @override
  void onClose() {
    attendanceController.dispose();
    paymentDelayController.dispose();
    examResultController.dispose();
    paymentReceivedController.dispose(); // YANGI
    super.onClose();
  }
}