import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:leader_school/services/exam_cache_servise.dart';
import 'package:leader_school/services/payment_cache_service.dart';
import 'package:leader_school/services/student_photo_service.dart';
import 'package:leader_school/views/home_view.dart';

import 'controllers/crm_controller.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GetStorage.init();
  await Hive.initFlutter();
  await Hive.openBox('exams_cache');
  await ExamCacheService.init();
  await PaymentCacheService.init();
  await StudentPhotoService.init();


  // Oflayn keshni yoqamiz: dastur yashindek tez ishlashi uchun asosiy sanksiya
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Butun ilova davomida ishlaydigan Asosiy Controllerni xotiraga yuklaymiz
  Get.put(CrmController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'O\'quv Markaz CRM',
      theme: ThemeData(
        primarySwatch: Colors.indigo, // Chiroyli ko'k rang
      ),
      home:   const HomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}