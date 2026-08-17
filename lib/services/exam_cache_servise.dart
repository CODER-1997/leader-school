import 'package:hive/hive.dart';

/// Exam'lar uchun offline-first cache.
/// Haqiqiy manba (source of truth) — ExamController'dagi real-time listener.
/// Bu servis faqat: (a) ilova ochilganda darhol ko'rsatish uchun oxirgi
/// ma'lumotni Hive'da saqlaydi, (b) real-time stream'dan kelgan har bir
/// yangilanishni diskka yozib boradi (keyingi ochilishda ham tez ko'rinsin).
class ExamCacheService {
  static const String _boxName = 'exams_cache';

  Box get _box => Hive.box(_boxName);

  /// App ishga tushganda (main.dart, runApp'dan OLDIN) bir marta chaqiring:
  ///   await ExamCacheService.init();
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
  }

  /// 0 Read — faqat Hive'dan, createdAt bo'yicha kamayish tartibida.
  List<Map<String, dynamic>> getCachedExams(String classId) {
    final raw = _box.get(classId, defaultValue: const <dynamic>[]) as List;
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    list.sort((a, b) => (b['createdAt'] as int? ?? 0).compareTo(a['createdAt'] as int? ?? 0));
    return list;
  }

  /// Real-time listener'dan kelgan TO'LIQ ro'yxatni diskka yozadi.
  Future<void> saveSnapshot(String classId, List<Map<String, dynamic>> exams) async {
    await _box.put(classId, exams);
  }
}