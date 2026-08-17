import 'package:get/get.dart';

/// Get.put()ni har safar widget qayta qurilganda (masalan StatelessWidget
/// build() metodida) shartsiz chaqirish YANGI controller yaratadi va
/// ESKISINI onClose() chaqirmasdan xotirada "osilib" qoldiradi. Agar o'sha
/// controller real-time Firestore listener saqlasa (masalan
/// AdminAttendanceController), bu orphan listenerlar cheksiz ko'payib,
/// Firestore read sonini portlatib yuboradi — bu aynan ExamController'da
/// oldin uchragan xatoning o'zi.
///
/// putOnce() avval controller ALLAQACHON ro'yxatdan o'tganmi tekshiradi;
/// bo'lsa — o'shani qayta ishlatadi, YO'Q bo'lsagina yangi yaratadi.
T putOnce<T extends GetxController>(T Function() builder, {required String tag}) {
  if (Get.isRegistered<T>(tag: tag)) {
    return Get.find<T>(tag: tag);
  }
  return Get.put<T>(builder(), tag: tag);
}