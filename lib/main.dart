import 'package:http/http.dart' as http;
import 'package:light/light.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const BitkiAsistani());
}

class BitkiAsistani extends StatelessWidget {
  const BitkiAsistani({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _YuklemeEkrani();
          }
          if (snapshot.hasData) {
            return const AnaSayfa();
          }
          return const GirisSayfasi();
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// YÜKLEME EKRANI
// ════════════════════════════════════════════════════════════
class _YuklemeEkrani extends StatelessWidget {
  const _YuklemeEkrani();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF2E7D32),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Colors.white),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// BAKIM KAYDI MODELİ
// ════════════════════════════════════════════════════════════
class BakimKaydi {
  final DateTime planlanmaTarihi;
  final DateTime? tamamlanmaTarihi;
  final bool tamamlandi;
  final String tip; // 'sulama', 'besleme', 'kontrol'

  BakimKaydi({
    required this.planlanmaTarihi,
    this.tamamlanmaTarihi,
    required this.tamamlandi,
    required this.tip,
  });

  int get gecikmGunu {
    if (!tamamlandi) {
      return DateTime.now().difference(planlanmaTarihi).inDays;
    }
    if (tamamlanmaTarihi == null) return 0;
    return tamamlanmaTarihi!.difference(planlanmaTarihi).inDays;
  }

  bool get zamaninda => tamamlandi && gecikmGunu <= 0;
  bool get gec => tamamlandi && gecikmGunu > 0;
  bool get kacirilan => !tamamlandi && DateTime.now().isAfter(planlanmaTarihi);

  Map<String, dynamic> toJson() => {
        'planlanmaTarihi': planlanmaTarihi.toIso8601String(),
        'tamamlanmaTarihi': tamamlanmaTarihi?.toIso8601String(),
        'tamamlandi': tamamlandi,
        'tip': tip,
      };

  factory BakimKaydi.fromJson(Map<String, dynamic> j) => BakimKaydi(
        planlanmaTarihi: DateTime.parse(j['planlanmaTarihi']),
        tamamlanmaTarihi: j['tamamlanmaTarihi'] != null
            ? DateTime.parse(j['tamamlanmaTarihi'])
            : null,
        tamamlandi: j['tamamlandi'] ?? false,
        tip: j['tip'] ?? 'sulama',
      );
}

// ════════════════════════════════════════════════════════════
// GİRİŞ / KAYIT SAYFASI
// ════════════════════════════════════════════════════════════
class GirisSayfasi extends StatefulWidget {
  const GirisSayfasi({super.key});
  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _girisFormKey = GlobalKey<FormState>();
  final _kayitFormKey = GlobalKey<FormState>();

  final _girisEmailCtrl = TextEditingController();
  final _girisSifreCtrl = TextEditingController();
  final _kayitAdCtrl = TextEditingController();
  final _kayitEmailCtrl = TextEditingController();
  final _kayitSifreCtrl = TextEditingController();
  final _kayitSifreTekrarCtrl = TextEditingController();

  bool _yukleniyor = false;
  bool _sifreGoster1 = false;
  bool _sifreGoster2 = false;
  bool _sifreGoster3 = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _girisEmailCtrl.dispose();
    _girisSifreCtrl.dispose();
    _kayitAdCtrl.dispose();
    _kayitEmailCtrl.dispose();
    _kayitSifreCtrl.dispose();
    _kayitSifreTekrarCtrl.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (!_girisFormKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _girisEmailCtrl.text.trim(),
        password: _girisSifreCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _hataGoster(_firebaseHataMesaji(e.code));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _kayitOl() async {
    if (!_kayitFormKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _kayitEmailCtrl.text.trim(),
        password: _kayitSifreCtrl.text.trim(),
      );
      await cred.user?.updateDisplayName(_kayitAdCtrl.text.trim());
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(cred.user!.uid)
          .set({
        'ad': _kayitAdCtrl.text.trim(),
        'email': _kayitEmailCtrl.text.trim(),
        'kayitTarihi': FieldValue.serverTimestamp(),
        'analizSayisi': 0,
        'rozet': 'Stajyer 🩺',
      });
    } on FirebaseAuthException catch (e) {
      _hataGoster(_firebaseHataMesaji(e.code));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _sifremiUnuttum() async {
    final email = _girisEmailCtrl.text.trim();
    if (email.isEmpty) {
      _hataGoster('Lütfen önce e-posta adresinizi girin.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şifre sıfırlama e-postası gönderildi!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      _hataGoster('E-posta gönderilemedi.');
    }
  }

  void _hataGoster(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: Colors.red.shade700),
    );
  }

  String _firebaseHataMesaji(String kod) {
    switch (kod) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı yok.';
      case 'wrong-password':
        return 'Şifre yanlış.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanımda.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen bekleyin.';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      default:
        return 'Bir hata oluştu: $kod';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: Column(
        children: [
          _ustPanel(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Giriş Yap'),
                        Tab(text: 'Kayıt Ol'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _girisFormu(),
                        _kayitFormu(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ustPanel() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white30, width: 2),
              ),
              child: const Icon(Icons.eco, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Plant Doctor Pro AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bitkilerinizin sağlığı bizim önceliğimiz 🌿',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _rozet('🤖 AI Teşhis'),
                const SizedBox(width: 8),
                _rozet('☀️ Hava Takibi'),
                const SizedBox(width: 8),
                _rozet('📅 Bakım'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rozet(String metin) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child:
            Text(metin, style: const TextStyle(color: Colors.white, fontSize: 10)),
      );

  Widget _girisFormu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _girisFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tekrar hoş geldiniz! 👋',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Bitkileriniz sizi bekliyor.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _inputAlani(
              controller: _girisEmailCtrl,
              label: 'E-posta',
              ikon: Icons.email_outlined,
              klavyeTipi: TextInputType.emailAddress,
              validator: (v) =>
                  v!.contains('@') ? null : 'Geçerli e-posta girin',
            ),
            const SizedBox(height: 16),
            _inputAlani(
              controller: _girisSifreCtrl,
              label: 'Şifre',
              ikon: Icons.lock_outline,
              gizli: !_sifreGoster1,
              sonEk: IconButton(
                icon: Icon(
                    _sifreGoster1 ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey),
                onPressed: () =>
                    setState(() => _sifreGoster1 = !_sifreGoster1),
              ),
              validator: (v) => v!.length >= 6 ? null : 'En az 6 karakter',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _sifremiUnuttum,
                child: const Text(
                  'Şifremi unuttum',
                  style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _anaButon(metin: 'Giriş Yap', onTap: _girisYap),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => _tabController.animateTo(1),
                child: RichText(
                  text: const TextSpan(
                    text: 'Hesabınız yok mu? ',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Kayıt Ol',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kayitFormu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _kayitFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hesap Oluştur 🌱',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Bitkilerinizle yolculuğunuz başlıyor.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _inputAlani(
              controller: _kayitAdCtrl,
              label: 'Ad Soyad',
              ikon: Icons.person_outline,
              validator: (v) => v!.length >= 2 ? null : 'Ad giriniz',
            ),
            const SizedBox(height: 16),
            _inputAlani(
              controller: _kayitEmailCtrl,
              label: 'E-posta',
              ikon: Icons.email_outlined,
              klavyeTipi: TextInputType.emailAddress,
              validator: (v) =>
                  v!.contains('@') ? null : 'Geçerli e-posta girin',
            ),
            const SizedBox(height: 16),
            _inputAlani(
              controller: _kayitSifreCtrl,
              label: 'Şifre',
              ikon: Icons.lock_outline,
              gizli: !_sifreGoster2,
              sonEk: IconButton(
                icon: Icon(
                    _sifreGoster2 ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey),
                onPressed: () =>
                    setState(() => _sifreGoster2 = !_sifreGoster2),
              ),
              validator: (v) => v!.length >= 6 ? null : 'En az 6 karakter',
            ),
            const SizedBox(height: 16),
            _inputAlani(
              controller: _kayitSifreTekrarCtrl,
              label: 'Şifre Tekrar',
              ikon: Icons.lock_outline,
              gizli: !_sifreGoster3,
              sonEk: IconButton(
                icon: Icon(
                    _sifreGoster3 ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey),
                onPressed: () =>
                    setState(() => _sifreGoster3 = !_sifreGoster3),
              ),
              validator: (v) =>
                  v == _kayitSifreCtrl.text ? null : 'Şifreler eşleşmiyor',
            ),
            const SizedBox(height: 24),
            _anaButon(metin: 'Kayıt Ol', onTap: _kayitOl),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => _tabController.animateTo(0),
                child: RichText(
                  text: const TextSpan(
                    text: 'Zaten hesabınız var mı? ',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Giriş Yap',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputAlani({
    required TextEditingController controller,
    required String label,
    required IconData ikon,
    bool gizli = false,
    TextInputType klavyeTipi = TextInputType.text,
    Widget? sonEk,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: gizli,
      keyboardType: klavyeTipi,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: const Color(0xFF2E7D32), size: 20),
        suffixIcon: sonEk,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: const Color(0xFFF9FBF9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _anaButon({required String metin, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _yukleniyor ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: _yukleniyor
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(metin,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// KLİNİK DETAY SAYFASI
// ════════════════════════════════════════════════════════════
class KlinikSayfasi extends StatelessWidget {
  final Map<String, String> bitkiDetay;

  const KlinikSayfasi({
    super.key,
    required this.bitkiDetay,
  });

  @override
  Widget build(BuildContext context) {
    final bool saglikli =
        bitkiDetay['teshis']?.contains('Sağlıklı') ?? false;
    final Color renkAna =
        saglikli ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: renkAna,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                bitkiDetay['isim'] ?? 'Bitki Kliniği',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [renkAna, renkAna.withOpacity(0.7)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    saglikli ? Icons.eco : Icons.local_hospital,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _klinikKart(
                  ikon: saglikli ? Icons.check_circle : Icons.warning_amber,
                  renk: renkAna,
                  baslik: 'Teşhis',
                  icerik: Text(
                    bitkiDetay['teshis'] ?? '-',
                    style: TextStyle(
                        fontSize: 16,
                        color: renkAna,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                _klinikKart(
                  ikon: Icons.water_drop,
                  renk: Colors.blue.shade700,
                  baslik: 'Sulama Talimatı',
                  icerik: Text(
                    bitkiDetay['sulama'] ?? '-',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                _klinikKart(
                  ikon: Icons.medical_services,
                  renk: Colors.orange.shade700,
                  baslik: 'Tedavi Reçetesi',
                  icerik: Text(
                    bitkiDetay['recete'] ?? '-',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                _klinikKart(
                  ikon: Icons.note_alt,
                  renk: Colors.purple.shade700,
                  baslik: 'Doktor Notu',
                  icerik: Text(
                    bitkiDetay['not'] ?? '-',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                if (!saglikli)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.red.shade200, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emergency,
                            color: Colors.red.shade700, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ ACİL MÜDAHALE GEREKLİ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Reçetedeki talimatları en kısa sürede uygulayın. Gecikme bitkinin iyileşme şansını düşürür.',
                                style:
                                    TextStyle(fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _klinikKart({
    required IconData ikon,
    required Color renk,
    required String baslik,
    required Widget icerik,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, color: renk, size: 20),
              const SizedBox(width: 8),
              Text(
                baslik,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: renk),
              ),
            ],
          ),
          const Divider(height: 16),
          icerik,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// DAVRANIS ANALİZİ SAYFASI
// ════════════════════════════════════════════════════════════
class DavranisAnaliziSayfasi extends StatelessWidget {
  final List<BakimKaydi> kayitlar;
  final String kullaniciProfili;
  final double ortalamaGecikme;

  const DavranisAnaliziSayfasi({
    super.key,
    required this.kayitlar,
    required this.kullaniciProfili,
    required this.ortalamaGecikme,
  });

  @override
  Widget build(BuildContext context) {
    final son30Gun = kayitlar.where((k) {
      return DateTime.now().difference(k.planlanmaTarihi).inDays <= 30;
    }).toList();

    final zamanindaSayisi = son30Gun.where((k) => k.zamaninda).length;
    final gecSayisi = son30Gun.where((k) => k.gec).length;
    final kacirilanSayisi = son30Gun.where((k) => k.kacirilan).length;

    // Hatalı davranış tespiti (son 15 gün)
    final son15Gun = kayitlar.where((k) {
      return DateTime.now().difference(k.planlanmaTarihi).inDays <= 15;
    }).toList();
    final geciktirmeSayisi = son15Gun.where((k) => k.gec).length;
    final erkenSulama = son15Gun
        .where((k) =>
            k.tamamlandi &&
            k.tamamlanmaTarihi != null &&
            k.tamamlanmaTarihi!
                    .difference(k.planlanmaTarihi)
                    .inDays <
                -1)
        .length;
    final tamamlanmayanSayisi = son15Gun.where((k) => k.kacirilan).length;

    String riskSeviyesi = 'Düşük Seviye';
    Color riskRenk = Colors.green.shade700;
    if (geciktirmeSayisi >= 4 || tamamlanmayanSayisi >= 3) {
      riskSeviyesi = 'Orta Seviye';
      riskRenk = Colors.orange.shade700;
    }
    if (geciktirmeSayisi >= 6 || tamamlanmayanSayisi >= 5) {
      riskSeviyesi = 'Yüksek Seviye';
      riskRenk = Colors.red.shade700;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'Davranış Analizi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kullanıcı Profili Kartı
            _profilKarti(kullaniciProfili),
            const SizedBox(height: 12),

            // Son 30 Gün İstatistikleri
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _kartDekor(Colors.blue.shade50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.calendar_month,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Son 30 Gün',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 14)),
                  ]),
                  const SizedBox(height: 12),
                  _istatistikSatiri('✓ Zamanında Bakım',
                      '$zamanindaSayisi', Colors.green.shade700),
                  _istatistikSatiri(
                      '⚠️ Geciken Bakım', '$gecSayisi', Colors.orange.shade700),
                  _istatistikSatiri('❌ Kaçırılan Bakım',
                      '$kacirilanSayisi', Colors.red.shade700),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ortalama Gecikme:',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(
                        '${ortalamaGecikme.toStringAsFixed(1)} gün',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hatalı Davranış Tespiti
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _kartDekor(Colors.orange.shade50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text('Davranış Analizi Sonucu',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Son 15 gün içerisinde:',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  if (geciktirmeSayisi > 0)
                    _hataSatiri('• $geciktirmeSayisi kez sulama gecikti'),
                  if (erkenSulama > 0)
                    _hataSatiri('• $erkenSulama kez erken sulama yapıldı'),
                  if (tamamlanmayanSayisi > 0)
                    _hataSatiri(
                        '• $tamamlanmayanSayisi bakım görevi tamamlanmadı'),
                  if (geciktirmeSayisi == 0 &&
                      erkenSulama == 0 &&
                      tamamlanmayanSayisi == 0)
                    const Text('✅ Son 15 günde hatalı davranış tespit edilmedi.',
                        style: TextStyle(
                            color: Color(0xFF2E7D32), fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Risk: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: riskRenk.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: riskRenk),
                        ),
                        child: Text(riskSeviyesi,
                            style: TextStyle(
                                color: riskRenk,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _profilKarti(String profil) {
    IconData profilIkon = Icons.star;
    Color profilRenk = const Color(0xFF2E7D32);
    String profilAciklama = '';

    switch (profil) {
      case 'Düzenli Kullanıcı':
        profilIkon = Icons.workspace_premium;
        profilRenk = const Color(0xFF2E7D32);
        profilAciklama = 'Bakımlarını zamanında yapıyor.';
        break;
      case 'Erteleyen Kullanıcı':
        profilIkon = Icons.hourglass_bottom;
        profilRenk = Colors.orange.shade700;
        profilAciklama = 'Bakımları sık sık erteliyor.';
        break;
      case 'İlgisiz Kullanıcı':
        profilIkon = Icons.sentiment_dissatisfied;
        profilRenk = Colors.red.shade700;
        profilAciklama = 'Bakımların büyük çoğunluğunu atlıyor.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [profilRenk, profilRenk.withOpacity(0.75)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: profilRenk.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(profilIkon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kullanıcı Profili',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(profil,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text(profilAciklama,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _istatistikSatiri(String etiket, String deger, Color renk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket,
              style: const TextStyle(fontSize: 13)),
          Text(deger,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: renk, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _hataSatiri(String metin) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(metin,
          style: TextStyle(fontSize: 13, color: Colors.orange.shade800)),
    );
  }

  BoxDecoration _kartDekor(Color bgRenk) {
    return BoxDecoration(
      color: bgRenk,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// İSTATİSTİK SAYFASI
// ════════════════════════════════════════════════════════════
class IstatistikSayfasi extends StatelessWidget {
  final List<BakimKaydi> kayitlar;
  final int analizSayisi;

  const IstatistikSayfasi({
    super.key,
    required this.kayitlar,
    required this.analizSayisi,
  });

  @override
  Widget build(BuildContext context) {
    final toplam = kayitlar.length;
    final zamaninda = kayitlar.where((k) => k.zamaninda).length;
    final gec = kayitlar.where((k) => k.gec).length;
    final kacirilan = kayitlar.where((k) => k.kacirilan).length;

    final zamanindaYuzde = toplam > 0 ? (zamaninda / toplam * 100) : 0.0;
    final gecYuzde = toplam > 0 ? (gec / toplam * 100) : 0.0;
    final kacirilanYuzde = toplam > 0 ? (kacirilan / toplam * 100) : 0.0;
    final basariOrani = toplam > 0
        ? ((zamaninda + gec) / toplam * 100)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text(
          'İstatistikler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Özet kart
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('📈 İstatistikler',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text('Toplam Bakım: $toplam',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Toplam Analiz: $analizSayisi',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Yüzde kartları
            Row(
              children: [
                Expanded(
                  child: _yuzdeKart(
                      'Zamanında',
                      '${zamanindaYuzde.toStringAsFixed(0)}%',
                      Colors.green.shade600,
                      Icons.check_circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _yuzdeKart(
                      'Geç',
                      '${gecYuzde.toStringAsFixed(0)}%',
                      Colors.orange.shade600,
                      Icons.schedule),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _yuzdeKart(
                      'Kaçırıldı',
                      '${kacirilanYuzde.toStringAsFixed(0)}%',
                      Colors.red.shade600,
                      Icons.cancel),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bakım başarı oranı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bakım Başarı Oranı',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: basariOrani / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF2E7D32),
                      minHeight: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${basariOrani.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _yuzdeKart(
      String baslik, String deger, Color renk, IconData ikon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(ikon, color: renk, size: 22),
          const SizedBox(height: 6),
          Text(deger,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: renk)),
          Text(baslik,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ANA SAYFA
// ════════════════════════════════════════════════════════════
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  // GENEL DEĞİŞKENLER
  File? _secilenResim;
  String _analizSonucu = "";
  bool _yukleniyor = false;
  List<File> _bitkiGunlugu = [];
  // Hava durumu değişkenleri
  double _sicaklik = 0;
  int _nem = 0;
  String _sehirAdi = "";
  String _havaDurumTanim = "";
  String _havaDurumIkon = "🌡️";
  bool _havaYukleniyor = true;
  Timer? _havaTimer;
  final TextEditingController _soruController = TextEditingController();
  String _doktorCevabi = "Bitkiniz hakkında bir soru sorun...";
  int _analizSayisi = 0;
  String _rozet = "Stajyer 🩺";
  List<bool> _haftalikKontrol = [
    false, false, false, false, false, false, false
  ];
  final List<String> _gunler = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
  double _luxDegeri = 0;
  String _isikDurumu = "Ölçülüyor...";
  late Light _light;
  StreamSubscription? _subscription;

  // TFLite DEĞİŞKENLERİ
  late tfl.Interpreter _interpreter;
  List<String> _etiketler = [];
  bool _modelHazir = false;

  // Son analiz detayı
  Map<String, String>? _sonAnalizDetay;

  // ── YENİ: BAKIM KAYITLARI ───────────────────────────────
  List<BakimKaydi> _bakimKayitlari = [];

  // ── YENİ: BAŞARIMLAR ────────────────────────────────────
  // Her başarım: {'id', 'isim', 'ikon', 'aciklama', 'kazanildi'}
  final List<Map<String, dynamic>> _basarimlar = [
    {
      'id': 'ilk_sulama',
      'isim': 'İlk Sulama',
      'ikon': '💧',
      'aciklama': 'İlk bakım görevini tamamla',
      'kazanildi': false,
    },
    {
      'id': 'yedi_gun_seri',
      'isim': '7 Gün Seri Bakım',
      'ikon': '🔥',
      'aciklama': '7 gün arka arkaya bakım yap',
      'kazanildi': false,
    },
    {
      'id': 'otuz_gun_duzenli',
      'isim': '30 Gün Düzenli',
      'ikon': '🏆',
      'aciklama': '30 gün boyunca düzenli bakım yap',
      'kazanildi': false,
    },
    {
      'id': 'yuz_gun_seri',
      'isim': '100 Günlük Seri',
      'ikon': '🎖️',
      'aciklama': '100 gün kesintisiz bakım yap',
      'kazanildi': false,
    },
    {
      'id': 'ilk_analiz',
      'isim': 'İlk Analiz',
      'ikon': '🔬',
      'aciklama': 'İlk AI analizini yap',
      'kazanildi': false,
    },
    {
      'id': 'on_analiz',
      'isim': '10 Analiz',
      'ikon': '🧬',
      'aciklama': '10 analiz tamamla',
      'kazanildi': false,
    },
  ];

  // ── HASTALIK BİLGİ BANKASI ──────────────────────────────
  final Map<String, Map<String, String>> bitkiVeriTabani = {
    "healthy aloe vera plant": {
      "isim": "Aloe Vera",
      "teshis": "Sağlıklı 🌿",
      "sulama": "10-14 günde bir, toprak tamamen kuruyunca sulayın.",
      "recete": "Mevcut bakıma devam edin. Güneşli pencere kenarı idealdir.",
      "not": "Bitkinin formu çok iyi. Jeli cilt bakımında kullanılabilir.",
    },
    "aloe vera mushy brown leaves": {
      "isim": "Aloe Vera",
      "teshis": "Yumuşak Kahverengi Yapraklar ⚠️",
      "sulama": "Sulamayı DERHAL durdurun! En az 3 hafta su vermeyin.",
      "recete":
          "Saksıdan çıkarın, çürük kökleri temiz makasla kesin, yeni kaktüs toprağına dikin.",
      "not": "Aşırı sulama nedeniyle kök çürümesi başlamış. Acil müdahale gerekli.",
    },
    "healthy monstera deliciosa leaf": {
      "isim": "Monstera (Deve Tabanı)",
      "teshis": "Sağlıklı ✨",
      "sulama": "Toprak 2-3 cm kuruyunca sulayın (yaklaşık haftada 1).",
      "recete": "Yapraklarını nemli bezle silin. Dolaylı parlak ışık verin.",
      "not": "Gelişimi ideal. Delikli yapılar sağlıklı büyümeyi gösterir.",
    },
    "yellow monstera leaf brown spots": {
      "isim": "Monstera",
      "teshis": "Sarı Yaprak & Kahverengi Leke ⚠️",
      "sulama": "Sulama düzenini kontrol edin; fazla veya az olabilir.",
      "recete": "Doğrudan güneş ışığından uzaklaştırın. Sarı yaprakları kesin.",
      "not": "Güneş yanığı veya mantar enfeksiyonu olabilir. Havalandırmayı artırın.",
    },
    "healthy snake plant leaves": {
      "isim": "Paşa Kılıcı",
      "teshis": "Sağlıklı 💪",
      "sulama": "2-3 haftada bir, kış aylarında ayda bir sulayın.",
      "recete": "Az ışıkta bile kalabilir. Fazla sulamaktan kaçının.",
      "not": "Son derece dayanıklı. Hava temizleme özelliği mükemmel.",
    },
    "root rot snake plant base": {
      "isim": "Paşa Kılıcı",
      "teshis": "Kök Çürümesi 🚨",
      "sulama": "Sulamayı TAMAMEN kesin.",
      "recete":
          "Çürük ve siyah kökleri tamamen kesin, mantar ilacı uygulayın, yeni kuru toprağa aktarın.",
      "not": "Tabanda yumuşama ve koku varsa acil müdahale şart.",
    },
    "healthy spider plant indoor": {
      "isim": "Kurdele Çiçeği",
      "teshis": "Sağlıklı 🌿",
      "sulama": "Haftada 1 kez, yaz aylarında 2 kez sulayın.",
      "recete": "Yarı gölge alanı sever. Sarkan filizler yeni saksıya dikilebilir.",
      "not": "Uçlarda kuruma yok, bitki formda.",
    },
    "spider plant brown tips": {
      "isim": "Kurdele Çiçeği",
      "teshis": "Kahverengi Uçlar ⚠️",
      "sulama": "1-2 gün bekletilmiş veya filtre edilmiş su kullanın.",
      "recete":
          "Nem oranını artırın (yanına su kabı koyun). Gübre miktarını azaltın.",
      "not": "Klorlu çeşme suyu veya düşük nem ana nedendir.",
    },
    "healthy peace lily": {
      "isim": "Barış Çiçeği",
      "teshis": "Sağlıklı 🏳️",
      "sulama": "Toprak nemli kalsın ama su göllenmemeli (haftada 1).",
      "recete": "Çiçeklenme için parlak dolaylı ışık verin.",
      "not": "Diri ve parlak yapraklar. Çiçeklenme yakında başlayabilir.",
    },
    "wilted drooping peace lily": {
      "isim": "Barış Çiçeği",
      "teshis": "Solgun & Sarkık Yapraklar 🚨",
      "sulama": "ACİL olarak bol su verin! Daldırma sulama yapın.",
      "recete": "Saksıyı 30 dk suya daldırın. Toprak iyice ıslanınca çıkarın.",
      "not": "Aşırı susuzluk (dehidrasyon). Çabuk iyileşir, paniğe gerek yok.",
    },
    "pothos yellow leaves drooping": {
      "isim": "Pothos Sarmaşığı",
      "teshis": "Sarı Sarkık Yapraklar ⚠️",
      "sulama": "Kontrollü sulama - toprak kuruyunca sulayın.",
      "recete": "Işık miktarını artırın. Dengeli sıvı gübre uygulayın.",
      "not": "Besin eksikliği veya yetersiz ışık. Sarı yaprakları kesin.",
    },
  };

  @override
  void initState() {
    super.initState();
    _light = Light();
    _gunluguYukle();
    _isikOlc();
    _havaDurumunuGetir();
    _modeliYukle();
    _bakimKayitlariniYukle();
    _basarimlariYukle();
    _havaTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _havaDurumunuGetir();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _soruController.dispose();
    _havaTimer?.cancel();
    if (_modelHazir) _interpreter.close();
    super.dispose();
  }

  // ── MODEL YÜKLEMESİ ─────────────────────────────────────
  Future<void> _modeliYukle() async {
    try {
      _interpreter =
          await tfl.Interpreter.fromAsset('assets/bitki_modeli.tflite');
      final String labelData =
          await rootBundle.loadString('assets/labels.txt');
      _etiketler = labelData
          .split('\n')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() => _modelHazir = true);
      debugPrint(
          "✅ TFLite Modeli Yüklendi. Etiket sayısı: ${_etiketler.length}");
    } catch (e) {
      debugPrint("❌ Model yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Model yüklenemedi: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── GÖRSEL İŞLEME ───────────────────────────────────────
  Float32List _resmiModeleHazirla(img.Image image) {
    final resized = img.copyResize(image, width: 224, height: 224);
    final buffer = Float32List(1 * 224 * 224 * 3);
    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[index++] = (pixel.r.toDouble() - 127.5) / 127.5;
        buffer[index++] = (pixel.g.toDouble() - 127.5) / 127.5;
        buffer[index++] = (pixel.b.toDouble() - 127.5) / 127.5;
      }
    }
    return buffer;
  }

  // ════════════════════════════════════════════════════════
  // HİBRİT ANALİZ
  // ════════════════════════════════════════════════════════
  static const double _guvenEsigi = 0.95;
  
  static const String _openRouterApiKey = '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';

  // OpenRouter için görsel okuyabilen (Vision) en iyi model:
  static const String _openRouterVisionModel = 'meta-llama/llama-3.2-11b-vision-instruct';

  Future<void> _aiAnalizYap() async {
    if (_secilenResim == null) return;
    setState(() => _yukleniyor = true);

    try {
      double tflitePuan = 0.0;
      String tfliteEtiket = "";
      Map<String, String>? tfliteDetay;

      if (_modelHazir) {
        final bytes = await _secilenResim!.readAsBytes();
        final rawImg = img.decodeImage(bytes);

        if (rawImg != null) {
          final inputData = _resmiModeleHazirla(rawImg);
          final outputShape =
              _interpreter.getOutputTensors()[0].shape;
          final int sinifSayisi =
              outputShape.length > 1 ? outputShape[1] : outputShape[0];
          final outputBuffer =
              List.generate(1, (_) => List<double>.filled(sinifSayisi, 0.0));
          _interpreter.run(
              inputData.reshape([1, 224, 224, 3]), outputBuffer);
          final sonuclar = outputBuffer[0];

          double enYuksek = -1.0;
          int enYuksekIdx = 0;
          for (int i = 0; i < sonuclar.length; i++) {
            if (sonuclar[i] > enYuksek) {
              enYuksek = sonuclar[i];
              enYuksekIdx = i;
            }
          }

          tflitePuan = enYuksek;
          tfliteEtiket = enYuksekIdx < _etiketler.length
              ? _etiketler[enYuksekIdx].toLowerCase().trim()
              : "";

          for (final key in bitkiVeriTabani.keys) {
            if (key.toLowerCase().trim() == tfliteEtiket) {
              tfliteDetay = bitkiVeriTabani[key];
              break;
            }
          }
          debugPrint(
              "🤖 TFLite → $tfliteEtiket | %${(tflitePuan * 100).toStringAsFixed(1)}");
        }
      }

      if (tflitePuan >= _guvenEsigi && tfliteDetay != null) {
        _sonuclariGuncelle(detay: tfliteDetay, kaynak: "🤖 Yerel AI");
        return;
      }

      debugPrint(
          "⚡ Güven düşük, Gemini Vision devreye giriyor...");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔍 Gelişmiş AI analizi yapılıyor...'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1565C0),
          ),
        );
      }
        // DEĞİŞEN KISIM: Groq yerine OpenRouter analiz fonksiyonunu çağırıyoruz
      final openRouterSonuc = await _openRouterVisionAnaliz();
      
      if (openRouterSonuc != null) {
        _sonuclariGuncelle(detay: openRouterSonuc, kaynak: "⚡ Groq AI");
        } else {
        _sonuclariGuncelle(
          detay: tfliteDetay ??
              {
                "isim": "Bilinmeyen Bitki",
                "teshis": "Teşhis yapılamadı",
                "sulama": "Bitkinizi daha iyi ışıkta çekin.",
                "recete": "Net bir fotoğraf çekip tekrar deneyin.",
                "not": "Yaprak ve gövde açıkça görünmeli.",
              },
          kaynak: "🤖 Yerel AI",
        );
      }
    } catch (e) {
      debugPrint("❌ Analiz hatası: $e");
      setState(() => _yukleniyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
static const String _groqVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  Future<Map<String, String>?>  _openRouterVisionAnaliz() async {
  int maksimumDeneme = 3;
  int beklemeSuresi = 2;

  for (int deneme = 1; deneme <= maksimumDeneme; deneme++) {
    try {
      final bytes = await _secilenResim!.readAsBytes();
      final base64Img = base64Encode(bytes);
      final uzanti = _secilenResim!.path.toLowerCase();
      final mimeType = uzanti.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_openRouterApiKey',
              'Content-Type': 'application/json; charset=utf-8',
              'HTTP-Referer': 'https://localhost',
              'X-Title': 'Plant Doctor App',
            },
            body: jsonEncode({
              'model':_openRouterVisionModel,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                     'text': '''Bu fotoğraftaki ev bitkisini çok sıkı bir botanik taramasından geçir. 

Adım Adım Mantık Kuralları (MANDATORY):
1. Bitki türünü tespit et ve "isim" alanına yaz.
2. Yapraklardaki sararmaları, kahverengi veya siyah lekeleri, uçlardaki kurumaları analiz et.
3. EĞER yapraklarda en ufak bir sararma, kuruma veya leke gördüysen; "teshis" alanına ASLA "Sağlıklı" yazma! Gördüğün kusura göre spesifik bir teşhis koy (Örn: "Aşırı Sulama ve Yaprak Çürümesi ⚠️", "Güneş Yanığı / Hatalı Konumlandırma ⚠️", "Mantar Lekesi ⚠️").
4. "sulama" ve "recete" kısımlarını asla genel cümlelerle geçiştirme. "Düzenli sulayın" veya "Toprağı yenileyin" gibi kalıplar yerine, koyduğun teşhise özel tedavi yöntemleri yaz .

Sadece şu JSON formatında yanıt ver, markdown (`json) veya başka hiçbir açıklama metni ekleme:
{
  "isim": "bitkinin net Türkçe adı",
  "teshis": "Spesifik hastalık/sorun adı ⚠️ (Bitki kusursuzsa sadece: Sağlıklı 🌿)",
  "sulama": "Teşhise ve hastalığa özel tedavi edici sulama planı",
  "recete": "Bitkiyi kurtarmak için yapılması gereken net bakım adımları",
  "not": "Yapraklarda gördüğün leke, sararma veya hasarın tam olarak nerede ve ne durumda olduğunun teknik özeti"
}
Türkçe yanıt ver.''',
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:$mimeType;base64,$base64Img',
                      },
                    },
                  ],
                },
              ],
              'temperature': 0.1,
              'max_tokens': 500,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String metin = data['choices'][0]['message']['content'].toString().trim();
        // Olası kod bloğu işaretlerini temizle
        metin = metin.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> jsonData = jsonDecode(metin);
        return {
          'isim': jsonData['isim']?.toString() ?? 'Bitki',
          'teshis': jsonData['teshis']?.toString() ?? 'Analiz edildi',
          'sulama': jsonData['sulama']?.toString() ?? '-',
          'recete': jsonData['recete']?.toString() ?? '-',
          'not': jsonData['not']?.toString() ?? '-',
        };
      }

      if (response.statusCode == 429 && deneme < maksimumDeneme) {
        debugPrint("⚠️ Groq Vision 429 aldı. $beklemeSuresi sn bekleniyor (Deneme $deneme/$maksimumDeneme)...");
        await Future.delayed(Duration(seconds: beklemeSuresi));
        beklemeSuresi *= 2;
        continue;
      } else {
        debugPrint("❌ Groq Vision hata: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Groq Vision exception (Deneme $deneme): $e");
      if (deneme < maksimumDeneme) {
        await Future.delayed(Duration(seconds: beklemeSuresi));
        beklemeSuresi *= 2;
      } else {
        return null;
      }
    }
  }
  return null;
}
  void _sonuclariGuncelle({
    required Map<String, String>? detay,
    required String kaynak,
  }) {
    final bool saglikli =
        detay?['teshis']?.contains('Sağlıklı') ?? false;

    final String sonuc = detay != null
        ? """🌿 BİTKİ: ${detay['isim']}\n${saglikli ? '✅' : '⚠️'} TEŞHİS: ${detay['teshis']}\n$kaynak\n💧 SULAMA: ${detay['sulama']}\n🩺 REÇETE: ${detay['recete']}\n📝 NOT: ${detay['not']}"""
        : "Teşhis yapılamadı. Lütfen daha net bir fotoğraf çekin.";

    setState(() {
      _analizSonucu = sonuc;
      _sonAnalizDetay = detay;
      _bitkiGunlugu.insert(0, _secilenResim!);
      _analizSayisi++;
      _yukleniyor = false;
    });

    // Analiz başarımlarını kontrol et
    if (_analizSayisi == 1) _basarimKazan('ilk_analiz');
    if (_analizSayisi >= 10) _basarimKazan('on_analiz');

    _rozetGuncelle();
    _gunluguKaydet();
    _veriyiBulutaGonder();
    _bakimPuaniniHesapla();
  }

  // ── YAPAY ZEKA ASISTAN ──────────────────────────────────
 Future<void> _openRouterSoruSor(String kullaniciSorusu) async {
  setState(() {
    _yukleniyor = true;
    _doktorCevabi = "";
  });

  // openrouter.ai'den aldığın sk-or-v1- ile başlayan key'i buraya yaz:
  final String openRouterApiKey = "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"; 
  
  // OpenRouter'ın ortak API adresi
  final String apiUrl = "https://openrouter.ai/api/v1/chat/completions";

  try {
    var response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $openRouterApiKey',
        'Content-Type': 'application/json; charset=utf-8',
        // OpenRouter için bu iki başlığı eklemek iyi olur (zorunlu değil ama hatayı önler)
        'HTTP-Referer': 'https://localhost', 
        'X-Title': 'Plant Doctor App',
      },
      body: jsonEncode({
        // İstediğin Llama 3.3 modelini OpenRouter formatında tam olarak böyle çağırıyoruz:
        'model': 'meta-llama/llama-3.3-70b-instruct', 
        'messages': [
          {
            'role': 'system',
            'content': 'Sen uzman bir bitki doktoru ve botanik asistanısın. Kullanıcıların bitki bakımı, sulama ve hastalık sorularına kısa Türkçe yanıtlar ver.'
          },
          {
            'role': 'user', 
            'content': kullaniciSorusu
          }
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _doktorCevabi = data['choices'][0]['message']['content'].toString().trim();
        _yukleniyor = false;
      });
    } else {
      debugPrint("❌ Groq hatası: ${response.statusCode} - ${response.body}");
      setState(() {
        _doktorCevabi = "Hata oluştu: ${response.statusCode}";
        _yukleniyor = false;
      });
    }
  } catch (e) {
    debugPrint("❌ Bağlantı hatası: $e");
    setState(() {
      _doktorCevabi = "Bağlantı hatası oluştu.";
      _yukleniyor = false;
    });
  }
}
  // ════════════════════════════════════════════════════════
  // YENİ: BAKIM KAYIT SİSTEMİ
  // ════════════════════════════════════════════════════════

  Future<void> _bakimKayitlariniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('bakim_kayitlari') ?? [];
    setState(() {
      _bakimKayitlari = jsonList
          .map((s) => BakimKaydi.fromJson(jsonDecode(s)))
          .toList();
    });
  }

  Future<void> _bakimKayitlariniKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bakim_kayitlari',
      _bakimKayitlari.map((k) => jsonEncode(k.toJson())).toList(),
    );
  }

  // Takvim kutusuna tıklanınca bakım kaydı oluştur/güncelle
  void _haftalikBakimToggle(int gunIndex) {
    final simdi = DateTime.now();
    final haftaBaslangici =
        simdi.subtract(Duration(days: simdi.weekday - 1));
    final planTarihi =
        DateTime(haftaBaslangici.year, haftaBaslangici.month,
            haftaBaslangici.day + gunIndex);

    setState(() => _haftalikKontrol[gunIndex] = !_haftalikKontrol[gunIndex]);

    if (_haftalikKontrol[gunIndex]) {
      // Bakım tamamlandı kaydı ekle
      final yeniKayit = BakimKaydi(
        planlanmaTarihi: planTarihi,
        tamamlanmaTarihi: simdi,
        tamamlandi: true,
        tip: 'sulama',
      );
      setState(() => _bakimKayitlari.insert(0, yeniKayit));

      // İlk sulama başarımı
      _basarimKazan('ilk_sulama');

      // 7 gün seri kontrol
      _seriKontrol();
    } else {
      // İşareti kaldır → kaydı sil
      setState(() {
        _bakimKayitlari.removeWhere((k) =>
            k.planlanmaTarihi.year == planTarihi.year &&
            k.planlanmaTarihi.month == planTarihi.month &&
            k.planlanmaTarihi.day == planTarihi.day);
      });
    }

    _bakimKayitlariniKaydet();
    _gunluguKaydet();
    _bakimPuaniniHesapla();
  }

  void _seriKontrol() {
    final tamamlananGunler = _bakimKayitlari
        .where((k) => k.tamamlandi)
        .map((k) => DateTime(k.planlanmaTarihi.year,
            k.planlanmaTarihi.month, k.planlanmaTarihi.day))
        .toSet()
        .toList()
      ..sort();

    int maxSeri = 1;
    int guncelSeri = 1;
    for (int i = 1; i < tamamlananGunler.length; i++) {
      if (tamamlananGunler[i]
              .difference(tamamlananGunler[i - 1])
              .inDays ==
          1) {
        guncelSeri++;
        if (guncelSeri > maxSeri) maxSeri = guncelSeri;
      } else {
        guncelSeri = 1;
      }
    }

    if (maxSeri >= 7) _basarimKazan('yedi_gun_seri');
    if (maxSeri >= 30) _basarimKazan('otuz_gun_duzenli');
    if (maxSeri >= 100) _basarimKazan('yuz_gun_seri');
  }

  // ════════════════════════════════════════════════════════
  // YENİ: BAKIM PUANI HESAPLAMA
  // ════════════════════════════════════════════════════════

  // Sulama, Besleme, Düzenlilik alt puanları
  int get _sulamaPuani {
    final son7Gun = _bakimKayitlari
        .where((k) =>
            k.tip == 'sulama' &&
            DateTime.now().difference(k.planlanmaTarihi).inDays <= 7)
        .toList();
    if (son7Gun.isEmpty) return 50;
    final zamaninda = son7Gun.where((k) => k.zamaninda).length;
    return ((zamaninda / son7Gun.length) * 100).round().clamp(0, 100);
  }

  int get _beslemePuani {
    // Besleme kayıtları yoksa ortalamayla başla
    return (_haftalikKontrol.where((b) => b).length / 7 * 100)
        .round()
        .clamp(0, 100);
  }

  int get _duzenlilikPuani {
    if (_bakimKayitlari.isEmpty) return 50;
    final son30Gun = _bakimKayitlari
        .where((k) =>
            DateTime.now().difference(k.planlanmaTarihi).inDays <= 30)
        .toList();
    if (son30Gun.isEmpty) return 50;
    final zamaninda = son30Gun.where((k) => k.zamaninda).length;
    return ((zamaninda / son30Gun.length) * 100).round().clamp(0, 100);
  }

  int get _genelBakimPuani {
    return ((_sulamaPuani + _beslemePuani + _duzenlilikPuani) / 3).round();
  }

  // Geçen haftaya göre fark (simüle)
  int get _haftalikFark {
    return _haftalikKontrol.where((b) => b).length * 2 - 3;
  }

  void _bakimPuaniniHesapla() {
    // Puan değişince setState tetikle
    setState(() {});
  }

  // ════════════════════════════════════════════════════════
  // YENİ: KULLANICI PROFİLİ
  // ════════════════════════════════════════════════════════

  String get _kullaniciProfili {
    final son30Gun = _bakimKayitlari
        .where((k) =>
            DateTime.now().difference(k.planlanmaTarihi).inDays <= 30)
        .toList();
    if (son30Gun.isEmpty) return 'Düzenli Kullanıcı';
    final kacirilan = son30Gun.where((k) => k.kacirilan).length;
    final gec = son30Gun.where((k) => k.gec).length;

    if (kacirilan >= 5 || (kacirilan + gec) >= 10) return 'İlgisiz Kullanıcı';
    if (gec >= 4) return 'Erteleyen Kullanıcı';
    return 'Düzenli Kullanıcı';
  }

  double get _ortalamaGecikme {
    final gecKayitlar =
        _bakimKayitlari.where((k) => k.gec && k.gecikmGunu > 0).toList();
    if (gecKayitlar.isEmpty) return 0.0;
    final toplamGecikme =
        gecKayitlar.fold<int>(0, (sum, k) => sum + k.gecikmGunu);
    return toplamGecikme / gecKayitlar.length;
  }

  // ════════════════════════════════════════════════════════
  // YENİ: MOTİVASYON MESAJI
  // ════════════════════════════════════════════════════════

  String get _motivasyonMesaji {
    switch (_kullaniciProfili) {
      case 'Düzenli Kullanıcı':
        if (_haftalikKontrol.where((b) => b).length >= 5) {
          return 'Son 7 gündür düzenli bakım yapıyorsunuz.\nBitkiniz oldukça sağlıklı. Devam edin! 🌿';
        }
        return 'Harika gidiyorsunuz!\nBu ay görevleri tamamlamaya devam edin.';
      case 'Erteleyen Kullanıcı':
        return 'Bugünkü bakım sadece\n2 dakika sürecek. Hadi başlayalım! ⏰';
      case 'İlgisiz Kullanıcı':
        return 'Bitkiniz son günlerde\nbakım bekliyor. 🌱 Küçük bir adım atın!';
      default:
        return 'Bitkilerinizi düzenli kontrol etmeyi unutmayın.';
    }
  }

  String get _motivasyonIkon {
    switch (_kullaniciProfili) {
      case 'Düzenli Kullanıcı':
        return '🏆';
      case 'Erteleyen Kullanıcı':
        return '⏰';
      case 'İlgisiz Kullanıcı':
        return '🌱';
      default:
        return '💚';
    }
  }

  Color get _motivasyonRenk {
    switch (_kullaniciProfili) {
      case 'Düzenli Kullanıcı':
        return const Color(0xFF2E7D32);
      case 'Erteleyen Kullanıcı':
        return Colors.orange.shade700;
      case 'İlgisiz Kullanıcı':
        return Colors.red.shade700;
      default:
        return const Color(0xFF2E7D32);
    }
  }

  // ════════════════════════════════════════════════════════
  // YENİ: BAŞARIMLAR
  // ════════════════════════════════════════════════════════

  Future<void> _basarimlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final kazanilanlar =
        prefs.getStringList('kazanilan_basarimlar') ?? [];
    setState(() {
      for (final b in _basarimlar) {
        b['kazanildi'] = kazanilanlar.contains(b['id']);
      }
    });
  }

  Future<void> _basarimKazan(String id) async {
    final idx = _basarimlar.indexWhere((b) => b['id'] == id);
    if (idx == -1 || _basarimlar[idx]['kazanildi'] == true) return;

    setState(() => _basarimlar[idx]['kazanildi'] = true);

    final prefs = await SharedPreferences.getInstance();
    final kazanilanlar =
        prefs.getStringList('kazanilan_basarimlar') ?? [];
    kazanilanlar.add(id);
    await prefs.setStringList('kazanilan_basarimlar', kazanilanlar);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Text(_basarimlar[idx]['ikon'],
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Başarım kazanıldı: ${_basarimlar[idx]['isim']}!'),
          ]),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── SİSTEM FONKSİYONLARI ────────────────────────────────
  Future<void> _sehirDegistir() async {
    final controller = TextEditingController(text: _sehirAdi);
    final String? yeniSehir = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_city, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Şehir Girin', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'örn: Istanbul, Ankara, Izmir',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.search),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ara'),
          ),
        ],
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (yeniSehir != null && yeniSehir.trim().isNotEmpty) {
      await _sehreGoreHavaGetir(yeniSehir.trim());
    }
  }

  Future<void> _sehreGoreHavaGetir(String sehir) async {
    setState(() => _havaYukleniyor = true);
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?q=$sehir'
        '&appid=22bcc581096b89d7410594d3038fdf9b'
        '&units=metric'
        '&lang=tr',
      );
      final res =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final double sicaklik = (data['main']['temp'] as num).toDouble();
        final int nem = data['main']['humidity'] as int;
        final String tanim = data['weather'][0]['description'] ?? '';
        final String sehirAdi = data['name'] ?? sehir;
        final String ikonKod = data['weather'][0]['icon'] ?? '';
        String ikon = _ikonKodunuCevir(ikonKod);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('secili_sehir', sehirAdi);
        setState(() {
          _sicaklik = sicaklik;
          _nem = nem;
          _sehirAdi = sehirAdi;
          _havaDurumTanim = tanim;
          _havaDurumIkon = ikon;
          _havaYukleniyor = false;
        });
      } else if (res.statusCode == 404) {
        setState(() => _havaYukleniyor = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$sehir" bulunamadı. İngilizce yazmayı deneyin.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _havaYukleniyor = false);
    }
  }

  String _ikonKodunuCevir(String ikonKod) {
    if (ikonKod.startsWith('01')) return '☀️';
    if (ikonKod.startsWith('02')) return '⛅';
    if (ikonKod.startsWith('03') || ikonKod.startsWith('04')) return '☁️';
    if (ikonKod.startsWith('09') || ikonKod.startsWith('10')) return '🌧️';
    if (ikonKod.startsWith('11')) return '⛈️';
    if (ikonKod.startsWith('13')) return '❄️';
    if (ikonKod.startsWith('50')) return '🌫️';
    return '🌡️';
  }
  

  Future<void> _havaDurumunuGetir() async {
    setState(() => _havaYukleniyor = true);
    try {
      double? lat;
      double? lon;

      // 1) Önce gerçek GPS konumunu dene (daha doğru)
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint("⚠️ Konum servisi kapalı.");
        } else {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.whileInUse ||
              perm == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            ).timeout(const Duration(seconds: 12));
            lat = pos.latitude;
            lon = pos.longitude;
            debugPrint("✅ GPS konumu alındı: $lat, $lon");
          } else if (perm == LocationPermission.deniedForever) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Konum izni reddedildi. Ayarlardan izin verin veya şehir seçin.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint("⚠️ GPS hatası: $e");
      }

      // 2) GPS alınamadıysa IP tabanlı konuma düş
      if (lat == null || lon == null) {
        try {
          final ipRes = await http
              .get(Uri.parse('http://ip-api.com/json/?fields=lat,lon,city'))
              .timeout(const Duration(seconds: 8));
          if (ipRes.statusCode == 200) {
            final ipData = json.decode(ipRes.body);
            lat = (ipData['lat'] as num).toDouble();
            lon = (ipData['lon'] as num).toDouble();
            debugPrint("✅ IP konumu alındı: $lat, $lon");
          }
        } catch (e) {
          debugPrint("⚠️ IP konum hatası: $e");
        }
      }

      // 3) Hâlâ yoksa varsayılan (İstanbul)
      lat ??= 41.0082;
      lon ??= 28.9784;

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lon'
        '&appid=22bcc581096b89d7410594d3038fdf9b'
        '&units=metric'
        '&lang=tr',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _sicaklik = (data['main']['temp'] as num).toDouble();
          _nem = data['main']['humidity'] as int;
          _havaDurumTanim = data['weather'][0]['description'] ?? '';
          _sehirAdi = data['name'] ?? '';
          _havaDurumIkon = _ikonKodunuCevir(data['weather'][0]['icon'] ?? '');
          _havaYukleniyor = false;
        });
      } else {
        setState(() {
          _havaDurumTanim = "API hatası (${res.statusCode})";
          _havaYukleniyor = false;
        });
      }
    } catch (e) {
      setState(() {
        _havaDurumTanim = "Bağlantı yok";
        _havaYukleniyor = false;
      });
    }
  }

  void _isikOlc() {
    try {
      _subscription = _light.lightSensorStream.listen((lux) {
        setState(() {
          _luxDegeri = lux.toDouble();
          if (lux < 200) {
            _isikDurumu = "🌑 Çok Karanlık";
          } else if (lux < 500) {
            _isikDurumu = "⚠️ Loş";
          } else if (lux < 2000) {
            _isikDurumu = "🌤️ Yeterli";
          } else {
            _isikDurumu = "☀️ Parlak";
          }
        });
      });
    } catch (e) {
      setState(() => _isikDurumu = "Sensör yok");
    }
  }

  Future<void> _gunluguKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bitki_gunlugu',
      _bitkiGunlugu.map((f) => f.path).toList(),
    );
    await prefs.setInt('analiz_sayisi', _analizSayisi);
    await prefs.setStringList(
      'takvim',
      _haftalikKontrol.map((b) => b.toString()).toList(),
    );
  }

  Future<void> _gunluguYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final yollar = prefs.getStringList('bitki_gunlugu');
    final takvim = prefs.getStringList('takvim');
    _analizSayisi = prefs.getInt('analiz_sayisi') ?? 0;
    if (yollar != null) {
      setState(() => _bitkiGunlugu = yollar
          .map((p) => File(p))
          .where((f) => f.existsSync())
          .toList());
    }
    if (takvim != null) {
      setState(() =>
          _haftalikKontrol = takvim.map((s) => s == "true").toList());
    }
    _rozetGuncelle();
  }

  void _rozetGuncelle() {
    setState(() {
      if (_analizSayisi >= 50) {
        _rozet = "Bitki Profesörü 🎓";
      } else if (_analizSayisi >= 20) {
        _rozet = "Uzman Doktor 🏥";
      } else if (_analizSayisi >= 10) {
        _rozet = "Asistan Doktor 👨‍⚕️";
      } else {
        _rozet = "Stajyer 🩺";
      }
    });
  }

  Future<void> _veriyiBulutaGonder() async {
    try {
      await FirebaseFirestore.instance
          .collection('kullanici_aksiyonlari')
          .add({
        'tarih': FieldValue.serverTimestamp(),
        'analiz_sayisi': _analizSayisi,
        'isik_seviyesi': _luxDegeri,
        'bakim_puani': _genelBakimPuani,
        'kullanici_profili': _kullaniciProfili,
        'son_teshis': _sonAnalizDetay?['teshis'] ?? 'bilinmiyor',
      });
    } catch (e) {
      debugPrint("Firebase hatası: $e");
    }
  }

  // ── RESİM ALMA ──────────────────────────────────────────
  Future<void> _resimAl(ImageSource kaynak) async {
    final picked = await ImagePicker().pickImage(
      source: kaynak,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() {
        _secilenResim = File(picked.path);
        _analizSonucu = "";
        _sonAnalizDetay = null;
      });
      _aiAnalizYap();
    }
  }

  void _secimPaneliniGoster(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            children: [
              const ListTile(
                title: Text('Fotoğraf Seç',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.photo_library,
                      color: Color(0xFF2E7D32)),
                ),
                title: const Text('Galeriden Seç'),
                subtitle: const Text('Kaydedilmiş fotoğraf kullan'),
                onTap: () {
                  Navigator.pop(context);
                  _resimAl(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child:
                      Icon(Icons.camera_alt, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Kamera'),
                subtitle: const Text('Şu an fotoğraf çek'),
                onTap: () {
                  Navigator.pop(context);
                  _resimAl(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // UI WIDGET'LARI
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: _appBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _gelisimHikayesiKarti(),
            _haftalikTakvim(),
            // ── YENİ: BAKIM SKORU KARTI ──
            _bakimSkoruKarti(),
            const Divider(height: 20, indent: 20, endIndent: 20),
            _analizAlani(),
            _ortamPaneli(),
            // ── YENİ: MOTİVASYON KARTI ──
            _motivasyonKarti(),
            // ── YENİ: BAŞARIMLAR KARTI ──
            _basarimlarKarti(),
            _gunlukZamanTuneli(),
            _asistanPaneli(),
            const SizedBox(height: 20),
            // ── YENİ: MENÜ BUTONLARI ──
            _menuButonlari(),
            const SizedBox(height: 16),
            _analizBaslatButonu(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final user = FirebaseAuth.instance.currentUser;
    return AppBar(
      backgroundColor: const Color(0xFF2E7D32),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLANT DOCTOR PRO AI',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
          Text(
            _rozet,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        if (_analizSayisi > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_analizSayisi analiz',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
          tooltip: user?.email ?? 'Çıkış',
          onPressed: () => _cikisYap(),
        ),
      ],
    );
  }

  Future<void> _cikisYap() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkmak istiyor musunuz?'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Widget _gelisimHikayesiKarti() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📈 GELİŞİM TAKİBİ",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF2E7D32)),
              ),
              Text(
                "Toplam Analiz: $_analizSayisi",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bitkiGunlugu.length < 2
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    "Farklı zamanlarda 2 fotoğraf analiz edince gelişim takibi başlar.",
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _fotoEtiketli(_bitkiGunlugu.last, "İLK HAL"),
                    const Column(
                      children: [
                        Icon(Icons.trending_up,
                            color: Color(0xFF2E7D32), size: 30),
                        Text("Gelişim",
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                    _fotoEtiketli(_bitkiGunlugu.first, "GÜNCEL"),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _fotoEtiketli(File f, String t) => Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(f, width: 75, height: 75, fit: BoxFit.cover),
          ),
          const SizedBox(height: 5),
          Text(
            t,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32)),
          ),
        ],
      );

  Widget _haftalikTakvim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            "📅 BAKIM TAKVİMİ",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF2E7D32)),
          ),
        ),
        SizedBox(
          height: 65,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: 7,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _haftalikBakimToggle(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 50,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _haftalikKontrol[i]
                      ? const Color(0xFF2E7D32)
                      : Colors.white,
                  border: Border.all(color: const Color(0xFF81C784)),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 4),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _gunler[i],
                      style: TextStyle(
                        color: _haftalikKontrol[i]
                            ? Colors.white
                            : Colors.black54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      _haftalikKontrol[i]
                          ? Icons.check_circle
                          : Icons.water_drop_outlined,
                      color: _haftalikKontrol[i]
                          ? Colors.white
                          : Colors.blue.shade300,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── YENİ: BAKIM SKORU KARTI ─────────────────────────────
  Widget _bakimSkoruKarti() {
    final puan = _genelBakimPuani;
    final fark = _haftalikFark;
    Color puanRenk = const Color(0xFF2E7D32);
    if (puan < 60) puanRenk = Colors.red.shade700;
    else if (puan < 80) puanRenk = Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "🏆 BAKIM SKORU",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF2E7D32)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fark >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: fark >= 0
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  fark >= 0 ? '+$fark puan' : '$fark puan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: fark >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$puan',
                style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: puanRenk),
              ),
              Text(
                '/100',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                'Bu hafta geçen haftaya göre\n${fark >= 0 ? '+$fark' : '$fark'} puan',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _skorSatiri('💧 Sulama', _sulamaPuani, Colors.blue.shade600),
          const SizedBox(height: 6),
          _skorSatiri(
              '🌿 Besleme', _beslemePuani, Colors.green.shade600),
          const SizedBox(height: 6),
          _skorSatiri('📅 Düzenlilik', _duzenlilikPuani,
              Colors.purple.shade600),
        ],
      ),
    );
  }

  Widget _skorSatiri(String etiket, int puan, Color renk) {
    return Row(
      children: [
        SizedBox(
            width: 90,
            child: Text(etiket,
                style: const TextStyle(fontSize: 11))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: puan / 100,
              backgroundColor: Colors.grey.shade200,
              color: renk,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$puan',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: renk)),
      ],
    );
  }

  // ── YENİ: MOTİVASYON KARTI ──────────────────────────────
  Widget _motivasyonKarti() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _motivasyonRenk,
            _motivasyonRenk.withOpacity(0.80)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _motivasyonRenk.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Text(_motivasyonIkon,
              style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🌱 Motivasyon Asistanı',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  _motivasyonMesaji,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _kullaniciProfili,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── YENİ: BAŞARIMLAR KARTI ──────────────────────────────
  Widget _basarimlarKarti() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withOpacity(0.08),
              blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🏅 BAŞARIMLAR",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _basarimlar.map((b) {
              final bool kazanildi = b['kazanildi'] as bool;
              return Tooltip(
                message: b['aciklama'],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kazanildi
                        ? const Color(0xFFE8F5E9)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kazanildi
                          ? const Color(0xFF81C784)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kazanildi ? b['ikon'] : '🔒',
                        style: TextStyle(
                            fontSize: 16,
                            color: kazanildi
                                ? null
                                : Colors.grey.shade400),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        b['isim'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kazanildi
                              ? const Color(0xFF2E7D32)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── YENİ: MENÜ BUTONLARI ────────────────────────────────
Widget _menuButonlari() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _menuButon(
                ikon: Icons.bar_chart,
                etiket: 'Davranış\nAnalizi',
                renk: Colors.indigo.shade600,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DavranisAnaliziSayfasi(
                      kayitlar: _bakimKayitlari,
                      kullaniciProfili: _kullaniciProfili,
                      ortalamaGecikme: _ortalamaGecikme,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _menuButon(
                ikon: Icons.analytics,
                etiket: 'İstatistikler',
                renk: Colors.teal.shade600,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IstatistikSayfasi(
                      kayitlar: _bakimKayitlari,
                      analizSayisi: _analizSayisi,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _menuButon(
            ikon: Icons.local_florist,
            etiket: 'Yakındaki Çiçekçileri Bul',
            renk: Colors.pink.shade600,
            onTap: _cicekciBul,
          ),
        ),
      ],
    ),
  );
}
   Future<void> _cicekciBul() async {
  // 1) Yükleniyor bildirimi göster
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Konum alınıyor...'),
          ],
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  double? lat;
  double? lon;

  // 2) GPS konumunu almayı dene
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 10));
        lat = pos.latitude;
        lon = pos.longitude;
      }
    }
  } catch (e) {
    debugPrint("⚠️ GPS hatası: $e");
  }

  // 3) GPS alınamadıysa mevcut hava durumu konumunu kullan
  if (lat == null && _sehirAdi.isNotEmpty) {
    // Şehir adıyla arama yap
    final query = Uri.encodeComponent('çiçekçi $_sehirAdi');
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("❌ Maps açılamadı: $e");
    }
    return;
  }

  // 4) Koordinatlarla "yakınımdaki çiçekçiler" araması
  if (lat != null && lon != null) {
    final query = Uri.encodeComponent('çiçekçi');
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query&location=$lat,$lon&radius=5000');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // canLaunchUrl false dönerse direkt dene
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("❌ Maps açılamadı: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harita açılamadı. Google Maps yüklü mü?'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } else {
    // Hiç konum yoksa genel arama
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=çiçekçi');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
Widget _menuButon({
  required IconData ikon,
  required String etiket,
  required Color renk,
  required VoidCallback onTap,
}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: renk.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(ikon, color: renk, size: 26),
            const SizedBox(height: 6),
            Text(
              etiket,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: renk),
            ),
          ],
        ),
      ),
    );
  }

  // ── ANALİZ ALANI ────────────────────────────────────────
  Widget _analizAlani() {
    if (_secilenResim == null) return _bosEkran();
    if (_yukleniyor) return _yuklemeEkran();
    return _bitkiPasaportuWidget();
  }

  Widget _bosEkran() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.eco_outlined,
                  size: 50, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 12),
            const Text(
              "Henüz analiz yapılmadı",
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Text(
              "Bitkinizin fotoğrafını çekerek başlayın",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _yuklemeEkran() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32), strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text("Bitkiniz analiz ediliyor...",
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.memory,
                        size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text("1. Yerel AI modeli çalışıyor...",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud, size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text("2. Gerekirse Groq Vision devreye girer",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _bitkiPasaportuWidget() {
    final bool saglikli =
        _sonAnalizDetay?['teshis']?.contains('Sağlıklı') ?? true;
    final Color karRenk =
        saglikli ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [karRenk, karRenk.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: karRenk.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_secilenResim!,
                    width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PASAPORT ONAYLANDI ✓",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1),
                    ),
                    const Text(
                      "Bitki Analiz Raporu",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Text(
            _analizSonucu,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _pasaportButon(
                  Icons.alarm, "SULAMA", () => _sulamaBilgisiGoster()),
              _pasaportButon(Icons.science, "BESLENME",
                  () => _beslemeBilgisiGoster()),
              _pasaportButon(Icons.local_hospital, "KLİNİK",
                  () => _klinikSayfasinaGit()),
            ],
          ),
          const SizedBox(height: 12),
          _toprakAnalizi(),
        ],
      ),
    );
  }

  Widget _pasaportButon(
      IconData ikon, String etiket, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white38),
        ),
        child: Column(
          children: [
            Icon(ikon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(etiket,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _klinikSayfasinaGit() {
    if (_sonAnalizDetay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir analiz yapın!')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KlinikSayfasi(bitkiDetay: _sonAnalizDetay!),
      ),
    );
  }

  void _sulamaBilgisiGoster() {
    final sulama = _sonAnalizDetay?['sulama'] ?? 'Bilgi bulunamadı.';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.water_drop, color: Colors.blue),
            SizedBox(width: 8),
            Text('Sulama Talimatı'),
          ],
        ),
        content: Text(sulama, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _beslemeBilgisiGoster() {
    final not = _sonAnalizDetay?['not'] ?? 'Bilgi bulunamadı.';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science, color: Colors.purple),
            SizedBox(width: 8),
            Text('Beslenme & Notlar'),
          ],
        ),
        content: Text(not, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _toprakAnalizi() {
    final bool kilitli = _analizSayisi < 30;
    return GestureDetector(
      onTap: kilitli
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${20 - _analizSayisi} analiz daha yapınca açılır!'),
                  backgroundColor: Colors.orange,
                ),
              )
          : null,
      child: Opacity(
        opacity: kilitli ? 0.6 : 1.0,
        child: Row(
          children: [
            Icon(kilitli ? Icons.lock : Icons.science,
                color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Text(
              kilitli
                  ? "🧪 Toprak Analizi (${30 - _analizSayisi} analiz sonra açılır)"
                  : "🧪 Toprak: %40 Kum, %60 Torf - Optimal karışım",
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ortamPaneli() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.08), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
            child: Row(
              children: [
                Text(_havaDurumIkon,
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _sehirDegistir,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _sehirAdi.isNotEmpty
                                  ? _sehirAdi
                                  : "Şehir seç...",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit,
                                size: 11, color: Color(0xFF1565C0)),
                          ],
                        ),
                        if (_havaDurumTanim.isNotEmpty)
                          Text(
                            _havaDurumTanim,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _havaYukleniyor ? null : _havaDurumunuGetir,
                  icon: _havaYukleniyor
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh,
                          color: Color(0xFF1565C0), size: 20),
                  tooltip: "Hava durumunu güncelle",
                ),
              ],
            ),
          ),
          const Divider(height: 12, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _birim(
                  Icons.thermostat,
                  _havaYukleniyor
                      ? "—"
                      : "${_sicaklik.toStringAsFixed(1)}°C",
                  "Sıcaklık",
                  Colors.orange,
                ),
                _dikey(),
                _birim(
                  Icons.water_drop,
                  _havaYukleniyor ? "—" : "%$_nem",
                  "Nem",
                  Colors.blue,
                ),
                _dikey(),
                _birim(
                  Icons.wb_sunny,
                  "${_luxDegeri.toInt()} lx",
                  _isikDurumu,
                  Colors.amber,
                ),
              ],
            ),
          ),
          if (!_havaYukleniyor && _sicaklik > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _bitkiIcinOneriBg(),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(_bitkiIcinOneriIkon(),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bitkiIcinOneri(),
                        style: TextStyle(
                          fontSize: 11,
                          color: _bitkiIcinOneriRenk(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _bitkiIcinOneri() {
    if (_sicaklik > 35) return "Çok sıcak! Bitkilerinizi güneşten uzak tutun.";
    if (_sicaklik > 28) return "Sıcak hava — bitkileri daha sık sulayın.";
    if (_sicaklik < 10) return "Soğuk hava — bitkilerinizi içeri alın!";
    if (_sicaklik < 18) return "Serin hava — sulama sıklığını azaltın.";
    if (_nem < 30) return "Düşük nem — yapraklara sis yapın veya nem artırın.";
    if (_nem > 80) return "Yüksek nem — havalandırmayı artırın, mantar riski var.";
    return "İdeal bitki bakım koşulları! 🌿";
  }

  String _bitkiIcinOneriIkon() {
    if (_sicaklik > 35 || _sicaklik < 10) return "🚨";
    if (_sicaklik > 28 || _nem < 30 || _nem > 80) return "⚠️";
    return "✅";
  }

  Color _bitkiIcinOneriBg() {
    if (_sicaklik > 35 || _sicaklik < 10) return Colors.red.shade50;
    if (_sicaklik > 28 || _nem < 30 || _nem > 80) return Colors.orange.shade50;
    return Colors.green.shade50;
  }

  Color _bitkiIcinOneriRenk() {
    if (_sicaklik > 35 || _sicaklik < 10) return Colors.red.shade700;
    if (_sicaklik > 28 || _nem < 30 || _nem > 80) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Widget _dikey() => Container(
      height: 40, width: 1, color: Colors.grey.shade200);

  Widget _birim(IconData i, String d, String e, Color renk) => Column(
        children: [
          Icon(i, color: renk, size: 22),
          const SizedBox(height: 4),
          Text(d,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: renk)),
          Text(e,
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      );

  Widget _gunlukZamanTuneli() {
    if (_bitkiGunlugu.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            "📜 TIBBİ GEÇMİŞ",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF2E7D32)),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _bitkiGunlugu.length,
            itemBuilder: (context, i) => Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_bitkiGunlugu[i],
                    width: 90, height: 100, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _asistanPaneli() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.08), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.psychology,
                      color: Color(0xFF2E7D32), size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DR. BOT ASİSTAN",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF2E7D32)),
                    ),
                    Text("Groq AI destekli",
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _doktorCevabi,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _soruController,
              decoration: InputDecoration(
                hintText: "Yapay zekaya soru sor...",
                hintStyle: const TextStyle(fontSize: 12),
                suffixIcon: _yukleniyor
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send,
                            color: Color(0xFF2E7D32)),
                        onPressed: () {
                        // textController, senin TextField'a bağlı olan controller adındır
                         // Eski hali: _groqSoruSor(textController.text);

                      _openRouterSoruSor(_soruController.text);
                       }
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      BorderSide(color: Colors.green.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      BorderSide(color: Colors.green.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                      color: Color(0xFF2E7D32), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F7F5),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _openRouterSoruSor
            ),
          ],
      ),
    )
    );
  }

  Widget _analizBaslatButonu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _secimPaneliniGoster(context),
          icon: const Icon(Icons.center_focus_strong),
          label: Text(
            _secilenResim == null
                ? "YAPAY ZEKA ANALİZİ BAŞLAT"
                : "YENİ ANALİZ BAŞLAT",
            style: const TextStyle(
                fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: 4,
            shadowColor:
                const Color(0xFF2E7D32).withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}
