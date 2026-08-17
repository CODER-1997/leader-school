import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class CrmController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Rx (Reaktiv) o'zgaruvchilar - Bular o'zgarganda EKRAN avtomat yangilanadi
  var isLoading = true.obs;
  var allStudents = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Dastur ishga tushishi bilan barcha o'quvchilarni orqa fonda yuklaymiz
    fetchAllStudents();
  }

  // 1. 750 ta o'quvchini 1 marta xotiraga (RAM) olish
  Future<void> fetchAllStudents() async {
    try {
      isLoading.value = true;

      // serverAndCache: Internet tez bo'lsa serverdan, sekin bo'lsa keshdan oladi
      var snapshot = await _db.collection('students').get(
          const GetOptions(source: Source.serverAndCache)
      );

      // Kelgan ma'lumotni GetX'ning reaktiv ro'yxatiga joylaymiz
      allStudents.value = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

    } catch (e) {
      Get.snackbar("Xatolik", "O'quvchilarni yuklashda muammo: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // 2. Maktab fani yoki Markaz guruhiga kirganda ishlaydigan filtrlash
  // DIQQAT: Serverga so'rov umuman KETMAYDI! Vaqt: 0.001 sekund.
  List<Map<String, dynamic>> getStudentsByIds(List<dynamic> groupStudentIds) {
    if (allStudents.isEmpty) return [];

    return allStudents.where((student) => groupStudentIds.contains(student['id'])).toList();
  }

  // 3. Yo'qlamani saqlash (750 marta emas, 1 marta yoziladi)
  Future<void> saveAttendance({
    required String classOrGroupId,
    required String type, // "maktab" yoki "markaz"
    required List<String> presentIds,
    required List<String> absentIds,
  }) async {
    try {
      DateTime date = DateTime.now();
      String formattedDate = "${date.year}-${date.month}-${date.day}";
      String docId = "${classOrGroupId}_$formattedDate"; // Masalan: "10A_math_2023-10-25"

      await _db.collection('attendance').doc(docId).set({
        'groupId': classOrGroupId,
        'type': type,
        'date': formattedDate,
        'present': presentIds,
        'absent': absentIds,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        "Muvaffaqiyatli",
        "Yo'qlama bazaga saqlandi!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor.withOpacity(0.8),
        colorText: Get.theme.colorScheme.onPrimary,
      );
    } catch (e) {
      Get.snackbar("Xatolik", "Yo'qlamani saqlashda xatolik yuz berdi");
    }
  }
}