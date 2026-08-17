import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum TeacherLoginStatus { success, notFound, inactive }

class TeacherLoginResult {
  final TeacherLoginStatus status;
  final String? teacherId;
  const TeacherLoginResult(this.status, {this.teacherId});
}

/// O'qituvchining shaxsiy kirishini aniqlaydi va faollik statistikasini
/// (oxirgi kirish vaqti, jami kirishlar soni) yangilaydi.
///
/// MUHIM ARXITEKTURA QARORI: har bir o'qituvchi endi Home ekranidagi
/// "maxsus kod" o'rniga O'ZINING (Admin -> O'qituvchilar bo'limida
/// qo'shilgan) TELEFON RAQAMINI kiritadi. Bu ikkita narsani bir yo'la
/// beradi: (1) kirish huquqi, (2) TIZIM ANIQ KIM kirganini biladi —
/// avvalgi "istalgan kod = teacher" modelida buni bilib bo'lmasdi.
///
/// Natijada: ro'yxatdan o'tmagan (Admin tomonidan qo'shilmagan) telefon
/// raqami bilan endi umuman kirib bo'lmaydi — bu ataylab shunday, chunki
/// "kim kirdi" savoliga javob berish uchun har bir kirish ANIQ bir
/// o'qituvchi hisobiga bog'langan bo'lishi shart.
class TeacherLoginService {
  static const String _collection = 'teachers';

  static String _sanitizePhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static Future<TeacherLoginResult> attemptLogin(String rawCode) async {
    final docId = _sanitizePhone(rawCode);
    if (docId.isEmpty) {
      return const TeacherLoginResult(TeacherLoginStatus.notFound);
    }

    try {
      final docRef = FirebaseFirestore.instance.collection(_collection).doc(docId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return const TeacherLoginResult(TeacherLoginStatus.notFound);
      }

      final data = doc.data()!;
      final isActive = data['isActive'] ?? true;
      if (!isActive) {
        return TeacherLoginResult(TeacherLoginStatus.inactive, teacherId: docId);
      }

      await docRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'loginCount': FieldValue.increment(1),
      });

      return TeacherLoginResult(TeacherLoginStatus.success, teacherId: docId);
    } catch (e) {
      debugPrint("O'qituvchi kirishini tekshirishda xato: $e");
      return const TeacherLoginResult(TeacherLoginStatus.notFound);
    }
  }
}