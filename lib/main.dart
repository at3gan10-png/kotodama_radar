import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// ★追加：手順1で作った設定ファイルを読み込む
import 'firebase_options.dart'; 

// アプリ内のファイル
import 'package:kotodama_radar/universe_page.dart';
import 'package:kotodama_radar/sub_screens.dart';
import 'package:kotodama_radar/logic.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    // ★修正：ここで「鍵（options）」を渡すことで、確実に接続させる
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await Future.delayed(const Duration(seconds: 3));

  } catch (e) {
    debugPrint('起動エラー発生: $e');
  } finally {
    runApp(const LueurApp());
    FlutterNativeSplash.remove();
  }
}

class LueurApp extends StatelessWidget {
  const LueurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LUEUR',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1626),
        primaryColor: const Color(0xFF0E1626),
        useMaterial3: true,
        textTheme: GoogleFonts.zenMaruGothicTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      home: const AuthCheckScreen(), 
    );
  }
}

// ---------------------------------------------------------
// ここから下が class AuthCheckScreen です
// ---------------------------------------------------------

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  String _statusMessage = "星の記憶を読み込み中..."; // 状況を表示するメッセージ

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    // 念のため少し待つ（Firebaseの準備待ち）
    await Future.delayed(const Duration(seconds: 1));

    try {
      setState(() => _statusMessage = "認証情報を確認しています...");
      
      // 現在のユーザーを取得
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => _statusMessage = "新しい星として登録中...");
        // ユーザーがいなければ匿名ログイン
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      }

      if (user != null) {
        setState(() => _statusMessage = "プロフィールを取得中...");
        
        // Firestoreからユーザー情報を取得
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (mounted) {
          if (doc.exists && doc.data()?['acceptedTerms'] == true) {
            // 規約同意済みなら地図へ
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => LueurUniversePage(user: user!)),
            );
          } else {
            // 未同意なら規約画面へ
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => TermsPage(user: user!)),
            );
          }
        }
      }
    } catch (e) {
      // エラーが起きたら画面に表示する
      setState(() => _statusMessage = "エラーが発生しました:\n$e");
      debugPrint("ログインエラー: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LUEURらしい読み込み演出
            const CircularProgressIndicator(color: Color(0xFFBB86FC)),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: GoogleFonts.zenMaruGothic(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 規約画面（TermsPage）も念のためここに含めておきます
// ---------------------------------------------------------

class TermsPage extends StatefulWidget {
  final User user;
  const TermsPage({super.key, required this.user});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1626),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Welcome to LUEUR",
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "深宇宙へようこそ。\nここは大人のための、言葉の宇宙です。",
                style: GoogleFonts.zenMaruGothic(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              // 規約表示エリア
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "利用規約 & プライバシー",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "1. 本アプリは位置情報を利用します。\n"
                          "2. 他者を不快にさせる投稿は禁止です。\n"
                          "3. 24時間経過した投稿は地図から消えます。\n"
                          "4. 健全な利用をお願いします。",
                          style: TextStyle(color: Colors.white70, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 同意ボタン
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBB86FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    // 同意フラグを保存
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.user.uid)
                        .set({'acceptedTerms': true}, SetOptions(merge: true));

                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => LueurUniversePage(user: widget.user)),
                      );
                    }
                  },
                  child: Text(
                    "同意して始める",
                    style: GoogleFonts.zenMaruGothic(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}