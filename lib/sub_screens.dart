import 'dart:io';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:image_picker/image_picker.dart';
import 'logic.dart';
import 'universe_page.dart'; 

class ProfileEditPage extends StatefulWidget {
  final User user;
  const ProfileEditPage({super.key, required this.user});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> with SingleTickerProviderStateMixin {
  final List<File> _newImages = [];
  List<String> _serverImages = [];
  final ImagePicker _picker = ImagePicker();
  
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _hobbyCtrl = TextEditingController();

  DateTime? _birthDate;
  SoulType _soulType = SoulType.explorer; 
  String _gender = 'Female'; 
  bool _isMarried = false; 
  bool _isPremium = false;
  int _currentEther = 0; 

  bool _emoFilter = true; 
  bool _privateZone = false;
  bool _loading = true;

  Map<String, dynamic>? _myLatestKotodama;
  late AnimationController _previewAnimCtrl;

  @override
  void initState() {
    super.initState();
    _previewAnimCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _loadData();
    _loadMyKotodama();
  }

  @override
  void dispose() {
    _previewAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _nameCtrl.text = d['nickname'] ?? '';
          _bioCtrl.text = d['bio'] ?? '';
          _ageCtrl.text = d['age'] ?? '';
          _heightCtrl.text = d['height'] ?? '';
          _jobCtrl.text = d['job'] ?? '';
          _hobbyCtrl.text = d['hobbies'] ?? '';
          _serverImages = List<String>.from(d['photoUrls'] ?? []);
          _emoFilter = d['emoFilter'] ?? true;
          _privateZone = d['privateZone'] ?? false;
          _isMarried = d['isMarried'] ?? false;
          _isPremium = d['isPremium'] ?? false;
          _currentEther = d['ether'] ?? 0;
          _gender = d['gender'] ?? 'Female';
          
          if (d['birthDate'] != null) _birthDate = (d['birthDate'] as Timestamp).toDate();
          if (d['soulType'] != null) {
            String savedType = d['soulType'].toString();
            _soulType = SoulType.values.firstWhere((e) => e.toString() == savedType, orElse: () => SoulType.explorer);
          }
          _loading = false;
        });
      } else {
        if(mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if(mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyKotodama() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));
      final snap = await FirebaseFirestore.instance
          .collection('kotodamas')
          .where('uid', isEqualTo: widget.user.uid)
          .where('createdAt', isGreaterThan: yesterday)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) { 
        setState(() { 
          _myLatestKotodama = snap.docs.first.data(); 
          _myLatestKotodama!['id'] = snap.docs.first.id; 
        }); 
      }
    } catch (e) {
      debugPrint("Index might be needed: $e");
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    List<String> urls = [..._serverImages];
    for (var f in _newImages) {
      final ref = FirebaseStorage.instance.ref().child('users/${widget.user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(f);
      urls.add(await ref.getDownloadURL());
    }
    
    await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
      'nickname': _nameCtrl.text,
      'bio': _bioCtrl.text,
      'age': _ageCtrl.text,
      'height': _heightCtrl.text,
      'job': _jobCtrl.text,
      'hobbies': _hobbyCtrl.text,
      'photoUrls': urls,
      'emoFilter': _emoFilter,
      'privateZone': _privateZone,
      'birthDate': _birthDate, 
      'soulType': _soulType.toString(), 
      'isMarried': _isMarried,
      'isPremium': _isPremium,
      'gender': _gender,
    }, SetOptions(merge: true));
    
    if (mounted) {
      setState(() { _newImages.clear(); _serverImages = urls; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get(context, 'save') + " OK")));
    }
  }

  Future<void> _pick() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x != null) setState(() => _newImages.add(File(x.path)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFBB86FC))), child: child!)
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Widget _applyMosaic(Widget image) {
    if (!_emoFilter) return image;
    return ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), child: image);
  }

  void _editKotodama() {
    if (_myLatestKotodama == null) return;
    String txt = _myLatestKotodama!['message'];
    String catId = _myLatestKotodama!['category'];
    List<CategoryData> availableCats = getAvailableCategories(_isMarried);
    CategoryData currentCat = availableCats.firstWhere((c) => c.id == catId, orElse: () => availableCats[0]);
    Color col = Color(_myLatestKotodama!['colorValue']);

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.95),
      title: const Text("Edit My Star", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: TextEditingController(text: txt), style: const TextStyle(color: Colors.white), onChanged: (v)=>txt=v, decoration: const InputDecoration(labelText: "Message")),
        const SizedBox(height: 10),
        ElevatedButton.icon(icon: const Icon(Icons.auto_awesome), label: Text(AppStrings.get(ctx, 'aiColor')), onPressed: () {
            if(txt.isEmpty) return;
            if(txt.contains('悲') || txt.contains('sad')) setS(() => col = Colors.blue[200]!);
            else if(txt.contains('怒') || txt.contains('angry')) setS(() => col = Colors.red[200]!);
            else setS(() => col = Colors.purple[200]!);
        }),
        const SizedBox(height: 10),
        Wrap(spacing: 5, children: availableCats.map((c) => Padding(padding: const EdgeInsets.all(2.0), child: ChoiceChip(
            avatar: Icon(c.icon, size: 16, color: currentCat.id == c.id ? Colors.white : c.color),
            label: Text(c.label), selected: currentCat.id == c.id, selectedColor: c.color, 
            onSelected: (v) => setS((){ currentCat=c; col=c.color; }))
        )).toList()),
      ])),
      actions: [
        TextButton(onPressed: () async {
          await FirebaseFirestore.instance.collection('kotodamas').doc(_myLatestKotodama!['id']).delete();
          if(mounted) setState(() => _myLatestKotodama = null);
          if(ctx.mounted) Navigator.pop(ctx);
        }, child: Text(AppStrings.get(ctx, 'delete'), style: const TextStyle(color: Colors.red))),
        ElevatedButton(onPressed: () async {
          await FirebaseFirestore.instance.collection('kotodamas').doc(_myLatestKotodama!['id']).update({ 'message': txt, 'category': currentCat.id, 'colorValue': col.value });
          if(mounted) { setState(() { _myLatestKotodama!['message'] = txt; _myLatestKotodama!['category'] = currentCat.id; _myLatestKotodama!['colorValue'] = col.value; }); }
          if(ctx.mounted) Navigator.pop(ctx);
        }, child: const Text("Update"))
      ]
    )));
  }

  Widget _buildStarPreview() {
    if (_myLatestKotodama == null) { return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text("No Active Star (24h)", style: TextStyle(color: Colors.grey)))); }
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MyStarDetailScreen(
          starData: _myLatestKotodama!,
          ether: _currentEther,
          isPremium: _isPremium,
        )));
      },
      child: Hero(
        tag: 'my_star_hero', 
        child: Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
          child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.0, colors: getCategoryBg(_myLatestKotodama!['category'])))))),
              AnimatedBuilder(animation: _previewAnimCtrl, builder: (_, __) { 
                return CustomPaint(size: const Size(100, 100), painter: UniversePainter(
                      stars: [{..._myLatestKotodama!, 'sx': 50.0, 'sy': 50.0, 'dist': 0.0, 'likes': 0, 'isSystem': false, 'ether': _currentEther, 'isPremium': _isPremium}], 
                      scale: 1.0, centerX: 50, centerY: 50, animValue: _previewAnimCtrl.value, currentCategory: _myLatestKotodama!['category'])); 
              }),
              Positioned(bottom: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)), child: Text(_myLatestKotodama!['message'], style: const TextStyle(color: Colors.white, fontSize: 12)))),
              Positioned(right: 5, top: 5, child: IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () { _editKotodama(); }))
          ])
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Color(0xFF0e1626), body: Center(child: CircularProgressIndicator()));
    int myLevel = EtherEngine.getLevel(_currentEther);

    return AnimatedBuilder(
      animation: textSizeManager,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: textSizeManager.scale),
          child: Scaffold(
            backgroundColor: const Color(0xFF0e1626),
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, 
              title: Text(AppStrings.get(context, 'profile'), style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, letterSpacing: 2)), 
              iconTheme: const IconThemeData(color: Colors.white)
            ),
            body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppStrings.get(context, 'textSize'), style: GoogleFonts.zenMaruGothic(color: Colors.white70, fontWeight: FontWeight.bold)),
              Row(children: [const Icon(Icons.text_fields, size: 16, color: Colors.grey), Expanded(child: Slider(value: textSizeManager.scale, min: 0.8, max: 1.5, divisions: 7, activeColor: const Color(0xFFBB86FC), onChanged: (v) => textSizeManager.setScale(v))), const Icon(Icons.text_fields, size: 30, color: Colors.white)]),
              const Divider(color: Colors.white24), const SizedBox(height: 10),
              
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("MY STAR (Active)", style: GoogleFonts.cinzel(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)), 
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text("Lv.$myLevel (Ether: $_currentEther)", style: const TextStyle(color: Colors.amber, fontSize: 12)))
              ]),
              const SizedBox(height: 10),
              _buildStarPreview(),
              if (!_isPremium && myLevel >= 10) const Padding(padding: EdgeInsets.only(top: 8), child: Text("🔒 レベルアップしています！プレミアム会員になると進化エフェクトが解放されます。", style: TextStyle(color: Colors.pinkAccent, fontSize: 11))),
              const SizedBox(height: 30),

              Text("GENDER", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1A1A2E),
                value: _gender,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "性別 / Gender"),
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("男性 / Male")),
                  DropdownMenuItem(value: "Female", child: Text("女性 / Female")),
                  DropdownMenuItem(value: "Other", child: Text("その他 / Other")),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 20),

              Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(10), color: Colors.amber.withOpacity(0.1)), child: SwitchListTile(title: Text(AppStrings.get(context, 'becomePremium'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), subtitle: Text(AppStrings.get(context, 'premiumDesc'), style: const TextStyle(color: Colors.white70, fontSize: 10)), value: _isPremium, activeColor: Colors.amber, secondary: const Icon(Icons.diamond, color: Colors.amber), onChanged: (v) => setState(() => _isPremium = v))),
              const SizedBox(height: 20),

              Text(AppStrings.get(context, 'photos'), style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
              const SizedBox(height: 10),
              SwitchListTile(title: Text(_emoFilter ? AppStrings.get(context, 'filterOn') : AppStrings.get(context, 'filterOff'), style: TextStyle(color: _emoFilter ? Colors.greenAccent : Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(AppStrings.get(context, 'filterDesc'), style: const TextStyle(color: Colors.grey, fontSize: 10)), value: _emoFilter, activeColor: Colors.greenAccent, onChanged: (v) => setState(() => _emoFilter = v)),
              GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: _serverImages.length + _newImages.length + 1, itemBuilder: (context, index) {
                  if (index == _serverImages.length + _newImages.length) { return GestureDetector(onTap: _pick, child: Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.white))); }
                  Widget img;
                  if (index < _serverImages.length) { img = Image.network(_serverImages[index], fit: BoxFit.cover); } else { img = Image.file(_newImages[index - _serverImages.length], fit: BoxFit.cover); }
                  return Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: _applyMosaic(img)), Positioned(top: 2, right: 2, child: GestureDetector(onTap: (){ setState(() { if(index < _serverImages.length) _serverImages.removeAt(index); else _newImages.removeAt(index - _serverImages.length); }); }, child: const Icon(Icons.cancel, size: 16)))]);
              }),
              const SizedBox(height: 30),
              TextField(controller: _nameCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'nickname'))),
              const SizedBox(height: 20),
              
              Text(AppStrings.get(context, 'maritalStatus'), style: GoogleFonts.zenMaruGothic(color: Colors.white70, fontWeight: FontWeight.bold)),
              RadioListTile<bool>(title: Text(AppStrings.get(context, 'single'), style: const TextStyle(color: Colors.white)), value: false, groupValue: _isMarried, activeColor: Colors.cyan, onChanged: (val) => setState(() => _isMarried = val!)),
              RadioListTile<bool>(title: Text(AppStrings.get(context, 'married'), style: const TextStyle(color: Colors.white)), value: true, groupValue: _isMarried, activeColor: Colors.orange, onChanged: (val) => setState(() => _isMarried = val!)),
              if (_isMarried) Padding(padding: const EdgeInsets.only(left: 16), child: Text(AppStrings.get(context, 'marriedInfo'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
              const SizedBox(height: 20),

              Text(AppStrings.get(context, 'intuitionSetting'), style: GoogleFonts.zenMaruGothic(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(contentPadding: EdgeInsets.zero, title: Text(_birthDate == null ? "${AppStrings.get(context, 'birthDate')} (Required)" : "${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}", style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.calendar_today, color: Colors.white54), onTap: _pickDate),
              const SizedBox(height: 10),
              DropdownButtonFormField<SoulType>(dropdownColor: const Color(0xFF1A1A2E), value: _soulType, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'soulType')), items: const [DropdownMenuItem(value: SoulType.analyst, child: Text("Analyst (論理・分析)")), DropdownMenuItem(value: SoulType.diplomat, child: Text("Diplomat (直感・共感)")), DropdownMenuItem(value: SoulType.sentinel, child: Text("Sentinel (秩序・現実)")), DropdownMenuItem(value: SoulType.explorer, child: Text("Explorer (自由・探索)"))], onChanged: (v) => setState(() => _soulType = v!)),
              const SizedBox(height: 20),
              TextField(controller: _bioCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'bio'))),
              const SizedBox(height: 30),
              Text(AppStrings.get(context, 'basicInfo'), style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: TextField(controller: _ageCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'age')))), const SizedBox(width: 10), Expanded(child: TextField(controller: _heightCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'height'))))]),
              const SizedBox(height: 10),
              TextField(controller: _jobCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'job'))),
              const SizedBox(height: 10),
              TextField(controller: _hobbyCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: AppStrings.get(context, 'hobbies'))),
              const SizedBox(height: 20),
              SwitchListTile(title: Text(AppStrings.get(context, 'privacyZone'), style: const TextStyle(color: Colors.white, fontSize: 12)), value: _privateZone, onChanged: (v) => setState(() => _privateZone = v)),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _loading ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBB86FC)), child: Text(AppStrings.get(context, 'save'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 50),
            ])),
          ),
        );
      }
    );
  }
}

class ChatHistoryPage extends StatelessWidget {
  final User user;
  const ChatHistoryPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: textSizeManager,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: textSizeManager.scale),
          child: Scaffold(
            backgroundColor: const Color(0xFF0e1626),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: Text("Stardust Memory", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('chatHistory').orderBy('updatedAt', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(child: Text("まだ誰とも話していません。\n星を灯してみましょう。", style: GoogleFonts.zenMaruGothic(color: Colors.white54), textAlign: TextAlign.center));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final kotodamaId = docs[i].id;
                    final lastMsg = d['lastMessage'] ?? '...';
                    final date = (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final category = d['category'] ?? 'Mystery';
                    final colValue = d['colorValue'] ?? 0xFFFFFFFF;
                    
                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Color(colValue).withOpacity(0.3), child: Icon(Icons.star, color: Color(colValue))),
                        title: Text(lastMsg, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1),
                        subtitle: Text("${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2,'0')} • $category", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                            id: kotodamaId, 
                            uid: user.uid, 
                            targetUid: d['targetUid'] ?? 'unknown',
                            col: Color(colValue)
                          )));
                        },
                      ),
                    );
                  }
                );
              }
            ),
          ),
        );
      }
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String id; final String uid; final String targetUid; final Color col;
  const ChatScreen({super.key, required this.id, required this.uid, required this.targetUid, required this.col});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctl = TextEditingController();
  final _stamps = ["🌙", "✨", "🌊", "🙏", "🌸", "🔥"];
  final _ngWords = ["LINE", "ライン", "ID", "ホテル", "会お", "sex", "投資", "儲か", "@", "http"];

  String _category = "Mystery";
  int _colorValue = 0xFFFFFFFF;

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    final doc = await FirebaseFirestore.instance.collection('kotodamas').doc(widget.id).get();
    if(doc.exists) {
      setState(() {
        _category = doc.data()?['category'] ?? "Mystery";
        _colorValue = doc.data()?['colorValue'] ?? 0xFFFFFFFF;
      });
    }
  }

  void _send(String txt, bool isStamp) async {
    if(txt.isEmpty) return;
    if (!isStamp) {
      for (String ng in _ngWords) {
        if (txt.contains(ng)) {
          bool proceed = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("⚠️ 確認 / Warning"), content: const Text("相手が不快に感じる、または規約違反の可能性のある言葉が含まれています。\n本当に送信しますか？\n(送信すると信頼スコアが下がる可能性があります)"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("修正する")), TextButton(onPressed: ()=>Navigator.pop(ctx, true), child: const Text("送信する", style: TextStyle(color: Colors.red)))])) ?? false;
          if (!proceed) return;
          break;
        }
      }
    }
    
    FirebaseFirestore.instance.collection('kotodamas').doc(widget.id).collection('msgs').add({'text': txt, 'uid': widget.uid, 'stamp': isStamp, 'ts': FieldValue.serverTimestamp()});
    _ctl.clear();

    final now = FieldValue.serverTimestamp();
    final historyDataMe = { 'lastMessage': isStamp ? 'スタンプ' : txt, 'updatedAt': now, 'targetUid': widget.targetUid, 'category': _category, 'colorValue': _colorValue };
    final historyDataOther = { 'lastMessage': isStamp ? 'スタンプ' : txt, 'updatedAt': now, 'targetUid': widget.uid, 'category': _category, 'colorValue': _colorValue };

    FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('chatHistory').doc(widget.id).set(historyDataMe, SetOptions(merge: true));
    if (widget.targetUid != 'ai_system') {
      FirebaseFirestore.instance.collection('users').doc(widget.targetUid).collection('chatHistory').doc(widget.id).set(historyDataOther, SetOptions(merge: true));
    }
    EtherEngine.addEther(widget.uid, 5);
  }

  void _revealVeil(BuildContext context, int msgCount) {
    if (msgCount < 5) { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("🔒 まだ早すぎます"), content: Text("お互いにあと${5 - msgCount}回メッセージを送り合って、\n波長を合わせてからベールを脱ぎましょう。"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))])); return; }
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(AppStrings.get(ctx, 'revealVeil')), content: Text(AppStrings.get(ctx, 'revealConfirm')), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("NO")), ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'allowedViewers': FieldValue.arrayUnion([widget.targetUid])}); if(ctx.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppStrings.get(ctx, 'revealed')))); } }, child: const Text("YES"))]));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: textSizeManager,
      builder: (context, _) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: textSizeManager.scale),
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: widget.col.withOpacity(0.3), title: Text("Resonance", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, letterSpacing: 2)), actions: [
                StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('kotodamas').doc(widget.id).collection('msgs').snapshots(), builder: (ctx, snap) { int count = snap.hasData ? snap.data!.docs.length : 0; return IconButton(icon: Icon(Icons.visibility, color: count < 5 ? Colors.white30 : Colors.white), tooltip: AppStrings.get(context, 'revealVeil'), onPressed: () => _revealVeil(context, count)); })
            ]),
            body: Column(children: [
              Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('kotodamas').doc(widget.id).collection('msgs').orderBy('ts', descending: true).snapshots(), builder: (ctx, snap) {
                  if(!snap.hasData) return const SizedBox();
                  final docs = snap.data!.docs;
                  final count = docs.length;
                  return ListView.builder(reverse: true, itemCount: count + 1, itemBuilder: (ctx, i) {
                      if(i == count) { return Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text(AppStrings.get(ctx, 'chatWait'), style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center), const SizedBox(height: 10), const Text("⚠️ 最初の数通は個人情報の交換を控え、\n直感的な会話を楽しみましょう。", style: TextStyle(color: Colors.redAccent, fontSize: 10))])); }
                      final d = docs[i].data() as Map<String, dynamic>;
                      final me = d['uid'] == widget.uid;
                      return Align(alignment: me ? Alignment.centerRight : Alignment.centerLeft, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 500), curve: Curves.easeOut, builder: (context, value, child) { return Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child)); }, child: Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: me ? widget.col : Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text(d['text'], style: TextStyle(fontSize: d['stamp']==true ? 30 : 14, color: me ? Colors.black : Colors.white)))));
                  });
              })),
              Container(padding: const EdgeInsets.all(10), color: Colors.white10, child: Column(children: [SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: _stamps.map((s) => TextButton(onPressed: ()=>_send(s, true), child: Text(s, style: const TextStyle(fontSize: 24)))).toList())), Row(children: [Expanded(child: TextField(controller: _ctl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: AppStrings.get(context, 'chatInput')))), IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: ()=>_send(_ctl.text, false))])]))
            ])
          ),
        );
      }
    );
  }
}

class MyStarDetailScreen extends StatelessWidget {
  final Map<String, dynamic> starData;
  final int ether;
  final bool isPremium;

  const MyStarDetailScreen({
    super.key,
    required this.starData,
    required this.ether,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final int level = EtherEngine.getLevel(ether);
    final String category = starData['category'] ?? 'Mystery';
    final Color starColor = Color(starData['colorValue'] ?? 0xFFFFFFFF);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: getCategoryBg(category),
                ),
              ),
            ),
          ),
          Center(
            child: Hero(
              tag: 'my_star_hero',
              child: SizedBox(
                width: 300,
                height: 300,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: 10),
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: UniversePainter(
                        stars: [{...starData, 'sx': 150.0, 'sy': 150.0, 'ether': ether, 'isPremium': isPremium}],
                        scale: 2.0, 
                        centerX: 150,
                        centerY: 150,
                        animValue: value,
                        currentCategory: category,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                border: Border.all(color: Colors.white10),
                boxShadow: [BoxShadow(color: starColor.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
              child: Column(
                children: [
                  Text("L V . $level", 
                    style: GoogleFonts.cinzel(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 8)
                  ),
                  Text("Radiant Soul", 
                    style: GoogleFonts.cinzel(fontSize: 14, color: Colors.amberAccent, letterSpacing: 4)
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("RESONANCE", "1.2K", Icons.favorite_border),
                      _buildStatItem("LOG", "42km", Icons.auto_awesome_motion),
                      _buildStatItem("ENCOUNTER", "450", Icons.people_outline),
                    ],
                  ),
                  const Spacer(),
                  if (!isPremium)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, color: Colors.amber, size: 16),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text("Premium限定：次回の進化（サテライト衛星）がまもなく解放されます。", 
                              style: TextStyle(color: Colors.white70, fontSize: 11)
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.oswald(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w300)),
        Text(label, style: GoogleFonts.cinzel(fontSize: 10, color: Colors.white30, letterSpacing: 1)),
      ],
    );
  }
}