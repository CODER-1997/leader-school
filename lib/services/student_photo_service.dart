import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// O'quvchi rasmini boshqaradi — BEPUL tashqi hosting (ImgBB) + Hive
/// kesh orqali "read/write ≈ 0" arxitektura bilan.
///
/// MUHIM SOZLASH (majburiy): https://api.imgbb.com ga kirib, bepul
/// ro'yxatdan o'ting, "Get API Key" orqali o'z kalitingizni oling va
/// pastdagi _imgbbApiKey qatoriga qo'ying. Kalitsiz yuklash ISHLAMAYDI.
///
/// ImgBB nima uchun tanlandi: to'liq bepul, cheksiz rasm hajmi, oddiy
/// REST API (autentifikatsiya/SDK shart emas), va eng muhimi — rasmning
/// o'zi Firestore'da EMAS, faqat uning URL manzili (bitta qisqa satr)
/// saqlanadi. Shu bilan rasm hajmi qanchalik katta bo'lmasin, Firestore
/// xarajatiga UMUMAN ta'sir qilmaydi.
///
/// ARXITEKTURA (read/write ≈ 0):
///   - Rasm URL'i BIR MARTA (o'sha qurilmada shu o'quvchi profili birinchi
///     ochilganda) Firestore'dan o'qiladi — 1 ta read.
///   - Shu o'qishdan keyin, HAR DOIM Hive keshidan olinadi — 0 Read.
///   - Faqat admin rasmni O'ZGARTIRGANDA — 1 ta write (Firestore) + kesh
///     yangilanadi.
///
/// MUHIM: pubspec.yaml'ga qo'shing:
///   flutter pub add http image_picker
class StudentPhotoService {
  StudentPhotoService._();

  static const String _boxName = 'student_photos_cache';

  // MUHIM: shu yerga o'z ImgBB API kalitingizni qo'ying (bepul: api.imgbb.com)
  static const String _imgbbApiKey = '9ee5683dab53a762fda4d82a456ce996';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  /// 0 Read — Hive keshidan darhol.
  static String? getCachedPhotoUrl(String studentId) {
    final v = _box.get(studentId) as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Agar keshda BOR bo'lsa — 0 Read. Aks holda Firestore'dan BIR MARTA
  /// o'qiydi (1 Read) va natijani (rasm bo'lmasa ham, "tekshirilgan"
  /// belgisi sifatida bo'sh satr bilan) keshga yozadi — shu bilan
  /// "rasmi yo'q" holat uchun ham keyingi safar qayta o'qilmaydi.
  static Future<String?> getPhotoUrl(String studentId) async {
    if (_box.containsKey(studentId)) {
      return getCachedPhotoUrl(studentId);
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      final url = doc.data()?['photoUrl'] as String?;
      await _box.put(studentId, url ?? '');
      return url;
    } catch (e) {
      debugPrint("O'quvchi rasmini o'qishda xato: $e");
      return null;
    }
  }

  /// Galereya/kameradan rasm tanlab, ImgBB'ga yuklaydi, so'ng Firestore'ga
  /// (1 write) va Hive keshiga yozadi. Muvaffaqiyatli bo'lsa yangi URL
  /// qaytaradi, aks holda null.
  /// YANGI: keshni MAJBURAN chetlab, Firestore'dan qayta o'qiydi va
  /// keshni yangilaydi. `getPhotoUrl()`dan farqi — bu HAR DOIM 1 ta read
  /// qiladi (foydalanuvchi "Yangilash" tugmasini bosganda ishlatiladi,
  /// server tomonda ma'lumot o'zgargan bo'lishi mumkinligi uchun).
  static Future<String?> refreshPhotoUrl(String studentId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
      final url = doc.data()?['photoUrl'] as String?;
      await _box.put(studentId, url ?? '');
      return url;
    } catch (e) {
      debugPrint("O'quvchi rasmini yangilashda xato: $e");
      rethrow;
    }
  }

  static Future<String?> pickAndUploadPhoto(String studentId, {required ImageSource source}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 800);
    if (picked == null) return null;

    if (_imgbbApiKey == 'SIZNING_IMGBB_API_KALITINGIZ') {
      throw Exception("ImgBB API kaliti sozlanmagan — student_photo_service.dart faylida _imgbbApiKey'ni to'ldiring");
    }

    final bytes = await File(picked.path).readAsBytes();
    final base64Image = base64Encode(bytes);

    // MUHIM: avval bu so'rovda HECH QANDAY vaqt chegarasi (timeout) yo'q
    // edi — agar tarmoq sekin/javobsiz bo'lsa, loader ABADIY aylanaverardi
    // (na muvaffaqiyat, na xato). Endi 20 soniyadan keyin aniq xato
    // (tutib bo'ladigan) tashlanadi.
    final response = await http
        .post(
      Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
      body: {'image': base64Image},
    )
        .timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw Exception("Internet ulanishi juda sekin yoki javob bermadi (20s kutildi)"),
    );

    if (response.statusCode != 200) {
      throw Exception("ImgBB yuklashda xato: ${response.statusCode}");
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['data']?['url'] as String?;
    if (url == null) throw Exception("ImgBB javobida URL topilmadi");

    await FirebaseFirestore.instance.collection('students').doc(studentId).update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _box.put(studentId, url);

    return url;
  }
}