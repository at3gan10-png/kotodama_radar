import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

// =========================================================
// データ・ロジック・定数
// =========================================================

const List<String> aiQuotes = [
  "暗闇こそが、星を輝かせる。", "偶然は、運命の別名。", "コーヒーの香りが時間を止める。",
  "今日はどんな物語と出会う？", "風が運ぶ想いがある。", "見えないものが、一番大切。",
  "一期一会を楽しむ心。", "深呼吸して、空を見上げて。", "答えは、沈黙の中にある。",
  "最高の出会いは、予期せぬ瞬間に。", "この辺り、散歩に最高。", "いいカフェ見つけたかも。",
  "空が綺麗に見える場所。", "誰かとお茶したい気分。", "風が気持ちいいな。",
  "静かで落ち着くエリア。", "面白いお店があったよ。", "今日も一日お疲れ様。",
  "たまには一人になりたい時もある。", "美味しいラーメン食べたい。", "誰かに話を聞いてほしい夜。",
];

class OracleEngine {
  static String generateDailyMessage(SoulType type) {
    final r = Random();
    String base = "";
    switch (type) {
      case SoulType.analyst: base = ["今日は直感よりも論理が冴える日。", "静かな場所でアイデアが降りてきます。", "古い本に答えがあるかもしれません。"][r.nextInt(3)]; break;
      case SoulType.diplomat: base = ["誰かの心に寄り添うことで、運が開けます。", "今日は感情を言葉にしてみて。", "懐かしい音楽がラッキーアイテム。"][r.nextInt(3)]; break;
      case SoulType.sentinel: base = ["いつものルーティンの中に発見があります。", "整理整頓が思考をクリアにします。", "約束を守ることが信頼の鍵。"][r.nextInt(3)]; break;
      case SoulType.explorer: base = ["いつもと違う道を歩いてみて。", "直感があなたを正しい場所へ導きます。", "新しい出会いはすぐそこに。"][r.nextInt(3)]; break;
    }
    final suffix = ["\n星々が見守っています。", "\n恐れずに進んで。", "\n良い波長を感じます。", "\n深呼吸を忘れずに。"][r.nextInt(4)];
    return "$base$suffix";
  }
}

class AiContextEngine {
  static Map<String, dynamic> generateLocalBot(double centerLat, double centerLng, int index) {
    final r = Random(index + DateTime.now().day); 
    final lat = centerLat + (r.nextDouble() - 0.5) * 0.005;
    final lng = centerLng + (r.nextDouble() - 0.5) * 0.005;
    final msg = aiQuotes[r.nextInt(aiQuotes.length)];
    final cats = ['Chill', 'Friend', 'Mystery', 'Shout']; 
    final cat = cats[r.nextInt(cats.length)];
    final catData = appCategories.firstWhere((c) => c.id == cat);
    return {
      'id': 'ai_bot_$index', 'message': msg, 'category': cat, 'colorValue': catData.color.value,
      'latitude': lat, 'longitude': lng, 'uid': 'ai_system', 'likes': r.nextInt(10),
      'isSystem': true, 'createdAt': DateTime.now(), 'type': 'text',
      'ether': 5000, 'isPremium': true,
    };
  }
}

class CategoryData {
  final String id; final String label; final String actionKey; final Color color; final List<Color> bgColors; final IconData icon; 
  const CategoryData(this.id, this.label, this.actionKey, this.color, this.bgColors, this.icon);
}

// --- 💎 Icons Updated for Luxury Feel ---
final List<CategoryData> appCategories = [
  // Romance -> 月 (Night/Romantic)
  CategoryData('Love', 'Romance', 'action_romance', const Color(0xFFFF4081), [const Color(0xFF0F0518), const Color(0xFF250030)], Icons.nightlight_round),
  // Friend -> グラス (Social/Adult)
  CategoryData('Friend', 'Friend', 'action_friend', const Color(0xFF00E5FF), [const Color(0xFF263238), const Color(0xFFE65100)], Icons.wine_bar),
  // Chill -> 葉/スパ (Relax/Healing) ※Coffeeより抽象的に
  CategoryData('Chill', 'Chill', 'action_chill', const Color(0xFF66BB6A), [const Color(0xFFF1F8E9), const Color(0xFFC8E6C9)], Icons.spa),
  // Secret -> 指紋 (Identity/Mystery)
  CategoryData('Mystery', 'Secret', 'action_mystery', const Color(0xFFB388FF), [const Color(0xFF212121), const Color(0xFF424242)], Icons.fingerprint),
  // Shout -> 音波 (Voice/Resonance)
  CategoryData('Shout', 'Shout', 'action_shout', const Color(0xFFFF5252), [const Color(0xFF3E2723), const Color(0xFF000000)], Icons.graphic_eq),
];

List<CategoryData> getAvailableCategories(bool isMarried) {
  if (isMarried) return appCategories.where((c) => c.id != 'Love').toList();
  return appCategories;
}
Color getCategoryColor(String id) {
  if (id == 'Cafe') id = 'Chill';
  return appCategories.firstWhere((c) => c.id == id, orElse: () => appCategories[3]).color;
}
List<Color> getCategoryBg(String filter) {
  if (filter == 'All') return [Colors.black, const Color(0xFF1A1A1A)];
  if (filter == 'Cafe') filter = 'Chill';
  return appCategories.firstWhere((c) => c.id == filter, orElse: () => appCategories[0]).bgColors;
}

class AiInsightEngine {
  static String analyzePersonality(SoulType type, String category) {
    if (category == 'Love' || category == 'Romance') {
      switch (type) {
        case SoulType.analyst: return "知的な会話を好み、嘘を嫌う誠実な方です。";
        case SoulType.diplomat: return "感情豊かで、ロマンチックな演出を好みます。";
        case SoulType.sentinel: return "真面目で一途。ゆっくり信頼を築くタイプです。";
        case SoulType.explorer: return "刺激的で、一緒にいて飽きない冒険家です。";
      }
    } else if (category == 'Chill') {
      switch (type) {
        case SoulType.analyst: return "静かな時間を共有できる、大人の余裕があります。";
        case SoulType.diplomat: return "聞き上手で、あなたの話を優しく受け止めます。";
        case SoulType.sentinel: return "マナーが良く、安心して時間を過ごせる方です。";
        case SoulType.explorer: return "ユニークな視点を持っており、新しい発見をくれます。";
      }
    } else { return "波長が合いそうな、素敵なオーラを感じます。"; }
  }
}

class EtherEngine {
  static int getLevel(int ether) { return (ether / 100).floor() + 1; }
  static Future<void> addEther(String uid, int amount) async { }
}

class TextSizeManager extends ChangeNotifier {
  double _scale = 1.0; double get scale => _scale;
  void setScale(double newScale) async { _scale = newScale; notifyListeners(); final prefs = await SharedPreferences.getInstance(); await prefs.setDouble('text_scale', newScale); }
  Future<void> loadSavedScale() async { final prefs = await SharedPreferences.getInstance(); _scale = prefs.getDouble('text_scale') ?? 1.0; notifyListeners(); }
}
final textSizeManager = TextSizeManager();

class LocaleManager extends ChangeNotifier {
  Locale _locale = const Locale('ja'); Locale get locale => _locale;
  void setLocale(Locale newLocale) async { _locale = newLocale; notifyListeners(); final prefs = await SharedPreferences.getInstance(); await prefs.setString('lang_code', newLocale.languageCode); }
  Future<void> loadSavedLocale() async { final prefs = await SharedPreferences.getInstance(); final String? code = prefs.getString('lang_code'); if (code != null) { _locale = Locale(code); notifyListeners(); } }
}
final localeManager = LocaleManager();

class AppStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'ja': {
      'appTitle': 'LUEUR', 'welcome': 'ようこそ\nLUEURの世界へ', 'agreeTerms': 'LUEURをはじめる',
      'termsTitle': '【安心・安全のために】', 'termsBody': '1. 相手へのリスペクトを忘れずに。\n2. 個人情報の管理は自己責任で。\n3. 心地よい距離感を大切に。',
      
      'tutorial_1_title': '言葉が、星になる。', 
      'tutorial_1_body': 'あなたの想いを「LUEUR (微かな光)」として地図に灯しましょう。\nその光は誰かの道しるべとなり、共鳴します。',
      'tutorial_2_title': '4つの顔を持つ世界', 
      'tutorial_2_body': '夜はロマンチックに、昼はカフェで穏やかに。\n「カメレオン」のように、気分に合わせてアプリのモードを切り替えられます。',
      'tutorial_3_title': '指で描き、声で囁く', 
      'tutorial_3_body': 'キーボードだけではありません。\n手書きの文字や、録音した「声」を星に込めることができます。\n誰かが読むと消える「儚い星」も…。',
      'tutorial_4_title': '星は育ち、軌跡は残る', 
      'tutorial_4_body': 'あなたの移動は「スターダスト・ログ」として記録されます。\n星を灯し、誰かとすれ違うたび、あなたの星は美しく進化します。',
      'tutorial_5_title': '守られた、第3の居場所', 
      'tutorial_5_body': '位置情報のぼかし、既婚者フィルター、写真のモザイク。\nLUEURは、大人が安心して羽を休めるためのサンクチュアリです。',

      'action_romance': '星を灯す', 'action_chill': '言葉を紡ぐ', 'action_friend': '気配を残す', 'action_shout': '想いを叫ぶ', 'action_mystery': '謎を秘める',
      'profile': 'PROFILE', 'textSize': '文字の大きさ', 'privacyBlur': '📍 位置をぼかして投稿', 'privacyBlurDesc': '実際の場所から少しずらして投稿します（自宅バレ防止）',
      'maritalStatus': 'ステータス', 'single': '未婚 / Single', 'married': '既婚・パートナーあり / Married',
      'marriedInfo': '※「既婚」を選択すると、Romance（恋愛）カテゴリーが表示されなくなります。',
      'premiumMode': 'Premium Member', 'premiumDesc': 'Ether Sight (AI分析)、限定オーラ、ステルスモードが有効です。', 'becomePremium': 'プレミアム会員になる (Demo)', 'aiAnalysisTitle': '✨ Ether Sight (AI分析)',
      'photos': 'PHOTOS', 'aboutMe': 'ABOUT ME', 'basicInfo': 'BASIC INFO', 'age': '年齢', 'height': '身長', 'job': '職業', 'hobbies': '趣味', 'secret': 'ヒミツ', 'lockedInfo': '🔒 詳細は会話が深まると解禁されます', 'nickname': 'ニックネーム', 'bio': '自己紹介', 'save': '保存する', 'filterOn': 'プライバシー保護 (ON)', 'filterOff': '保護なし (OFF)', 'filterDesc': '初期状態では写真にモザイクがかかります。', 'privacyZone': 'Privacy Zone (自宅周辺を隠す)', 'settings': '設定', 'language': '言語 / Language', 'mapLoading': 'Etherに接続中...', 'nearbyAlert': '近くに誰かの気配を感じます...', 'addKotodama': '想いを灯す', 'inputHint': '今、何を思ってる？', 'aiColor': 'AIで色を決める', 'aiDone': 'AIが感情を読み取りました', 'premium': 'プレミアム投稿 (Rainbow)', 'cancel': 'やめる', 'post': '解き放つ', 'block': 'ブロックする', 'report': '通報する', 'delete': '削除する', 'deletedMsg': '光を空に還しました', 'blockedMsg': 'ユーザーをブロックしました', 'reportedMsg': '報告しました', 'chatWait': '🔒 スタンプを送り合って波長を合わせましょう', 'chatInput': '言葉を紡ぐ...', 'postedBy': 'POSTED BY', 'likes': 'いいね', 'talk': '話してみたい', 'replySent': '言霊返しを送りました', 'ngWord': 'その言葉は投稿できません', 'safeCheck': 'AIが画像をチェック中...', 'unsafe': '不適切な画像の可能性があります', 'all': 'ALL', 'blurInfo': '※写真は相手が許可するまでモザイク処理されています', 'arMode': 'AR Mode', 'soundMode': 'Sound Mode', 'distance': 'Range', 'revealVeil': 'ベールを脱ぐ', 'revealConfirm': 'あなたの写真を相手に公開しますか？', 'revealed': '写真を公開しました', 'intuitionSetting': '直感マッチング設定', 'birthDate': '生年月日', 'soulType': 'Soul Type (タイプ)', 'aiMessage': '宇宙からのメッセージ', 'reachNotif': 'あなたの光が、@n人の魂に届きました。', 'views': 'Views', 'switchToList': 'Stardust', 'switchToRadar': 'LUEUR', 'listModeDesc': '広範囲の言霊を探索中...',
      'logTitle': '観測ログ', 'logCount': '今日すれ違った星: @n',
      'modeText': '文字', 'modeHand': '手書き', 'modeVoice': '声',
      'tapToRecord': 'タップして録音開始', 'recording': '録音中... (タップで停止)', 'voiceSent': '声を星に込めました',
      'handHint': '指で想いを描いてください', 'ephemeral': '儚い星 (1回で消滅)', 'ephemeralDesc': '誰かが読むと消える、一瞬の輝き。',
      'playVoice': '再生する', 'vanished': '光は役目を終えて消え去りました...',
    },
    'en': {
      'appTitle': 'LUEUR', 'welcome': 'Welcome to\nLUEUR', 'agreeTerms': 'Enter the Universe',
      'termsTitle': 'Terms & Privacy', 'termsBody': 'Respect others and enjoy serendipity.',
      'tutorial_1_title': 'Words become Stars', 'tutorial_1_body': 'Your thoughts light up the map as "LUEUR".\nLet your light guide someone.',
      'tutorial_2_title': 'Four Faces of the World', 'tutorial_2_body': 'Romantic nights, chill cafes.\nSwitch modes like a "Chameleon" to match your mood.',
      'tutorial_3_title': 'Draw & Whisper', 'tutorial_3_body': 'Not just text. Leave handwritten notes or voice messages.\nCreate "Ephemeral Stars" that vanish after one view.',
      'tutorial_4_title': 'Evolve & Log', 'tutorial_4_body': 'Your movement creates a "Stardust Log".\nThe more you connect, the more your star evolves.',
      'tutorial_5_title': 'A Safe Sanctuary', 'tutorial_5_body': 'Location blurring, marriage filters, photo mosaic.\nA safe "third place" for adults.',
      'action_romance': 'Light a Star', 'action_chill': 'Spin Words', 'action_friend': 'Leave a Trace', 'action_shout': 'Shout Out', 'action_mystery': 'Hide a Mystery',
      'profile': 'PROFILE', 'textSize': 'Text Size', 'privacyBlur': '📍 Blur Location', 'privacyBlurDesc': 'Randomize location slightly for safety.',
      'maritalStatus': 'Status', 'single': 'Single', 'married': 'Married / Partnered',
      'marriedInfo': '* Selecting "Married" will hide the Romance category.',
      'premiumMode': 'Premium Member', 'premiumDesc': 'Ether Sight (AI Analysis), Exclusive Aura, Stealth Mode active.', 'becomePremium': 'Become Premium (Demo)', 'aiAnalysisTitle': '✨ Ether Sight (AI)',
      'photos': 'PHOTOS', 'aboutMe': 'ABOUT ME', 'basicInfo': 'BASIC INFO', 'age': 'Age', 'height': 'Height', 'job': 'Job', 'hobbies': 'Hobbies', 'secret': 'Secret', 'lockedInfo': '🔒 Details unlock after chatting.', 'nickname': 'Nickname', 'bio': 'Bio', 'save': 'Save Profile', 'filterOn': 'Privacy Mode (ON)', 'filterOff': 'Privacy Mode (OFF)', 'filterDesc': 'Photos appear blurred to others initially.', 'privacyZone': 'Privacy Zone (Hide Home)', 'settings': 'Settings', 'language': 'Language', 'mapLoading': 'Connecting to Ether...', 'nearbyAlert': 'Someone\'s presence is near...', 'addKotodama': 'Light Lueur', 'inputHint': 'What\'s on your mind?', 'aiColor': 'AI Color', 'aiDone': 'AI analyzed sentiment!', 'premium': 'Premium (Rainbow)', 'cancel': 'Cancel', 'post': 'Unleash', 'block': 'Block User', 'report': 'Report', 'delete': 'Delete', 'deletedMsg': 'Deleted.', 'blockedMsg': 'Blocked.', 'reportedMsg': 'Reported.', 'chatWait': '🔒 Send stamps to sync vibes first.', 'chatInput': 'Spin words...', 'postedBy': 'POSTED BY', 'likes': 'Likes', 'talk': 'Connect', 'replySent': 'Reply sent.', 'ngWord': 'Cannot post that word.', 'safeCheck': 'Checking image safety...', 'unsafe': 'Image may be inappropriate.', 'all': 'ALL', 'blurInfo': '*Photos are blurred until permitted.', 'arMode': 'AR Mode', 'soundMode': 'Sound Mode', 'distance': 'Dist', 'revealVeil': 'Unveil', 'revealConfirm': 'Reveal your photos?', 'revealed': 'Photos revealed.', 'intuitionSetting': 'Intuition Settings', 'birthDate': 'Birth Date', 'soulType': 'Soul Type', 'aiMessage': 'Message from Universe', 'reachNotif': 'Your voice reached @n souls.', 'views': 'Views', 'switchToList': 'Stardust', 'switchToRadar': 'LUEUR', 'listModeDesc': 'Scanning wide range...',
      'logTitle': 'Log', 'logCount': 'Stars Today: @n',
      'modeText': 'Text', 'modeHand': 'Draw', 'modeVoice': 'Voice',
      'tapToRecord': 'Tap to Record', 'recording': 'Recording... (Tap to Stop)', 'voiceSent': 'Voice Star Created',
      'handHint': 'Draw your feelings here', 'ephemeral': 'Ephemeral Star', 'ephemeralDesc': 'Vanishes after being read once.',
      'playVoice': 'Play Voice', 'vanished': 'The star has faded away...',
    },
  };
  static String get(BuildContext context, String key) {
    final Locale locale = Localizations.localeOf(context);
    final String lang = locale.languageCode == 'en' ? 'en' : 'ja';
    return _localizedValues[lang]?[key] ?? key;
  }
}

enum SoulType { analyst, diplomat, sentinel, explorer }
extension SoulTypeExt on SoulType {
  String getLabel(String category) { return this.toString().split('.').last; } 
}
class LogicProfile {
  final String name; final DateTime? birthDate; final SoulType type;
  LogicProfile({required this.name, required this.birthDate, required this.type});
  String get zodiacSign { if (birthDate == null) return "不明"; int day = birthDate!.day; int month = birthDate!.month; if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return "おひつじ座"; if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return "おうし座"; if ((month == 5 && day >= 21) || (month == 6 && day <= 21)) return "ふたご座"; if ((month == 6 && day >= 22) || (month == 7 && day <= 22)) return "かに座"; if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return "しし座"; if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return "おとめ座"; if ((month == 9 && day >= 23) || (month == 10 && day <= 23)) return "てんびん座"; if ((month == 10 && day >= 24) || (month == 11 && day <= 22)) return "さそり座"; if ((month == 11 && day >= 23) || (month == 12 && day <= 21)) return "いて座"; if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return "やぎ座"; if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return "みずがめ座"; return "うお座"; }
  String get zodiacElement { const fire = ["おひつじ座", "しし座", "いて座"]; const earth = ["おうし座", "おとめ座", "やぎ座"]; const air = ["ふたご座", "てんびん座", "みずがめ座"]; if (zodiacSign == "不明") return "不明"; if (fire.contains(zodiacSign)) return "火"; if (earth.contains(zodiacSign)) return "地"; if (air.contains(zodiacSign)) return "風"; return "水"; }
}
class CompatibilityResult { final int score; final String catchPhrase; final String reason; final Color color; CompatibilityResult(this.score, this.catchPhrase, this.reason, this.color); }
class CompatibilityEngine {
  static CompatibilityResult calculate(LogicProfile me, LogicProfile other, String contextCategory) {
    if (me.birthDate == null || other.birthDate == null) { return CompatibilityResult(0, "", "", Colors.grey); }
    int score = 50; 
    return CompatibilityResult(score, "Good Match", "直感が合っています", Colors.pinkAccent);
  }
}