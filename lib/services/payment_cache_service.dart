import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

/// Bitta o'quvchining to'lovlari uchun cache-first, delta-sync xizmati.
///
/// FIRESTORE MANZILI (TAXMIN): 'students/{studentId}/payments'.
/// MUHIM: agar sizning loyihangizda o'quvchi hujjati boshqa yo'lda
/// bo'lsa (masalan 'classes/{classId}/students/{studentId}'), pastdagi
/// _paymentsRef() metodidagi BITTA qatorni almashtirsangiz kifoya —
/// qolgan hammasi o'zgarishsiz ishlayveradi.
///
/// Pattern — ExamCacheService bilan BIR XIL: cache-first (0 Read),
/// server-cursor delta sync (clock-skew xavfsiz), soft-delete YO'Q
/// (moliyaviy yozuvlar odatda o'chirilmaydi, faqat qo'shiladi).
class PaymentCacheService {
  static const String _boxName = 'payments_cache';
  static const String _metaBoxName = 'payments_meta';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Box get _box => Hive.box(_boxName);
  Box get _metaBox => Hive.box(_metaBoxName);

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) await Hive.openBox(_boxName);
    if (!Hive.isBoxOpen(_metaBoxName)) await Hive.openBox(_metaBoxName);
  }

  CollectionReference _paymentsRef(String studentId) {
    // MUHIM: bu yerni loyihangizdagi haqiqiy yo'lga moslang, kerak bo'lsa.
    return _db.collection('students').doc(studentId).collection('payments');
  }

  List<Map<String, dynamic>> _readRaw(String studentId) {
    final raw = _box.get(studentId, defaultValue: const <dynamic>[]) as List;
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _writeRaw(String studentId, List<Map<String, dynamic>> list) =>
      _box.put(studentId, list);

  /// 0 Read — sana bo'yicha kamayish tartibida (eng yangisi tepada).
  List<Map<String, dynamic>> getCachedPayments(String studentId) {
    final list = _readRaw(studentId);
    list.sort((a, b) => (b['dateMs'] as int? ?? 0).compareTo(a['dateMs'] as int? ?? 0));
    return list;
  }

  int? _lastSyncedAtMs(String studentId) => _metaBox.get('lastSync_$studentId') as int?;

  Future<void> _setLastSyncedAtMs(String studentId, int ms) =>
      _metaBox.put('lastSync_$studentId', ms);

  /// [forceFull] = true bo'lsa — delta-sync cursor'ni CHETLAB, BARCHA
  /// hujjatlarni qayta o'qiydi va keshni TO'LIQ ALMASHTIRADI (merge emas).
  /// Bu MUHIM: agar ma'lumot Firebase Console orqali qo'lda o'zgartirilgan
  /// bo'lsa (updatedAt yangilanmasdan), oddiy delta-sync buni SEZMAYDI —
  /// forceFull esa har doim haqiqiy holatni oladi, hatto o'chirilgan
  /// hujjatlarni ham to'g'ri aks ettiradi (delta-sync o'chirishni ham
  /// bila olmaydi).
  Future<List<Map<String, dynamic>>> syncPayments(String studentId, {bool forceFull = false}) async {
    final lastSyncMs = forceFull ? null : _lastSyncedAtMs(studentId);

    Query query = _paymentsRef(studentId);
    if (lastSyncMs != null) {
      query = query.where('updatedAt', isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(lastSyncMs));
    }
    query = query.orderBy('updatedAt', descending: false);

    final snap = await query.get();

    if (forceFull) {
      final fresh = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'amount': (data['amount'] ?? 0).toDouble(),
          'method': data['method'] ?? 'cash',
          'source': data['source'] ?? 'school',
          'note': data['note'] ?? '',
          'isLocked': data['isLocked'] ?? false,
          'forMonth': data['forMonth'] ?? '',
          'dateMs': (data['date'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        };
      }).toList();

      await _writeRaw(studentId, fresh);

      int maxUpdatedAtMs = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ms = (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        if (ms > maxUpdatedAtMs) maxUpdatedAtMs = ms;
      }
      await _setLastSyncedAtMs(studentId, maxUpdatedAtMs > 0 ? maxUpdatedAtMs : DateTime.now().millisecondsSinceEpoch);

      return getCachedPayments(studentId);
    }

    if (snap.docs.isEmpty) return getCachedPayments(studentId);

    final cached = _readRaw(studentId);
    final indexById = {for (var i = 0; i < cached.length; i++) cached[i]['id']: i};

    int maxUpdatedAtMs = lastSyncMs ?? 0;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final updatedAtMs = (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
      if (updatedAtMs > maxUpdatedAtMs) maxUpdatedAtMs = updatedAtMs;

      final entry = {
        'id': doc.id,
        'amount': (data['amount'] ?? 0).toDouble(),
        'method': data['method'] ?? 'cash',
        'source': data['source'] ?? 'school',
        'note': data['note'] ?? '',
        'isLocked': data['isLocked'] ?? false,
        'forMonth': data['forMonth'] ?? '', // YANGI: "YYYY-MM" — qaysi oy uchun
        'dateMs': (data['date'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      };

      final idx = indexById[doc.id];
      if (idx != null) {
        cached[idx] = entry;
      } else {
        cached.add(entry);
        indexById[doc.id] = cached.length - 1;
      }
    }

    await _writeRaw(studentId, cached);
    await _setLastSyncedAtMs(studentId, maxUpdatedAtMs);

    return getCachedPayments(studentId);
  }

  Future<void> addToCache(String studentId, Map<String, dynamic> payment) async {
    final cached = _readRaw(studentId);
    cached.removeWhere((e) => e['id'] == payment['id']);
    cached.insert(0, payment);
    await _writeRaw(studentId, cached);
  }

  Future<void> removeFromCache(String studentId, String paymentId) async {
    final cached = _readRaw(studentId);
    cached.removeWhere((e) => e['id'] == paymentId);
    await _writeRaw(studentId, cached);
  }
}