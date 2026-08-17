/// Ilova bo'ylab ishlatiladigan foydalanuvchi rollari.
/// "admin" kabi satrlarni har joyda qo'lda yozish o'rniga shu konstantalar
/// ishlatiladi — xato ehtimoli kamayadi va yangi rol qo'shish (masalan
/// "teacher") faqat shu bitta faylda amalga oshiriladi.
class AppRoles {
  AppRoles._(); // instansiya yaratilmasin

  static const String admin = 'admin';
  static const String teacher = 'teacher';
}