import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart'; 
import 'package:permission_handler/permission_handler.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:flutter_compass/flutter_compass.dart'; 
import 'package:sensors_plus/sensors_plus.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:signature/signature.dart'; 
import 'package:record/record.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'logic.dart';
import 'sub_screens.dart';

class UniversePainter extends CustomPainter {
  final List<Map<String, dynamic>> stars;
  final double scale; final double centerX; final double centerY; final double animValue; final String currentCategory; 
  UniversePainter({required this.stars, required this.scale, required this.centerX, required this.centerY, required this.animValue, required this.currentCategory});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(centerX, centerY);
    final isBrightMode = (currentCategory == 'Chill');
    final gridColor = isBrightMode ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.05);
    final gridPaint = Paint()..color = gridColor..style = PaintingStyle.stroke..strokeWidth = 1.0;
    canvas.drawCircle(center, 100 * scale, gridPaint); canvas.drawCircle(center, 300 * scale, gridPaint); canvas.drawCircle(center, 500 * scale, gridPaint);
    
    for (var i = 0; i < stars.length; i++) {
      final s1 = stars[i]; final p1 = Offset(s1['sx'], s1['sy']);
      final isPremiumStar = s1['isPremium'] == true;
      final type = s1['type'] ?? 'text'; 
      
      bool isSystem = s1['isSystem'] == true;
      if (isSystem) {
        canvas.drawCircle(p1, 8 + (sin(animValue * 3) * 2), Paint()..color = (isBrightMode ? Colors.teal : Colors.cyanAccent).withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        continue; 
      }

      final starColor = Color(s1['colorValue']);
      if (isPremiumStar) {
        final glowRect = Rect.fromCircle(center: p1, radius: 25 + (sin(animValue * 4) * 5));
        final gradient = SweepGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red], transform: GradientRotation(animValue * 2 * pi));
        canvas.drawCircle(p1, 20 + (sin(animValue * 4) * 3), Paint()..shader = gradient.createShader(glowRect)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }

      Paint corePaint = Paint()..color = starColor;
      if (type == 'image') {
        canvas.drawRect(Rect.fromCenter(center: p1, width: 10, height: 10), corePaint); 
      } else if (type == 'audio') {
        canvas.drawCircle(p1, 5 + (sin(animValue * 10) * 3).abs(), Paint()..color = starColor.withOpacity(0.5)..style = PaintingStyle.stroke);
        canvas.drawCircle(p1, 3, corePaint);
      } else {
        canvas.drawCircle(p1, 4, corePaint); 
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LueurUniversePage extends StatefulWidget {
  final User user;
  const LueurUniversePage({super.key, required this.user});
  @override
  State<LueurUniversePage> createState() => _LueurUniversePageState();
}

class _LueurUniversePageState extends State<LueurUniversePage> with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  String _filter = 'All'; 
  List<String> _blocks = [];
  double _radarRadius = 1000; 
  bool _isListMode = false;
  bool _currentUserIsMarried = false;
  bool _isPremiumUser = false;
  SoulType _currentUserSoulType = SoulType.explorer;
  String _currentUserGender = 'Female'; 
  bool _includeSameSex = true; 
  
  int _todayEncounterCount = 0; 

  late AnimationController _animCtrl;
  CameraController? _cameraController;
  bool _isArMode = false;
  StreamSubscription? _compassSub;
  double _deviceHeading = 0.0; 
  StreamSubscription? _sensorSub; 
  double _gyroX = 0; double _gyroY = 0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  double _baseRadius = 1000; 
  bool _isZooming = false;

  final SignatureController _sigCtrl = SignatureController(penStrokeWidth: 5, penColor: Colors.white);
  final Record _audioRecorder = Record();
  bool _isRecording = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _determinePosition(); _loadUserData(); _checkReach(); _checkDailyOracle(); _loadDailyLog(); 
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _initSound();
  }

  Future<void> _initSound() async { await _audioPlayer.setReleaseMode(ReleaseMode.loop); }

  @override
  void dispose() { 
    _animCtrl.dispose(); _cameraController?.dispose(); _compassSub?.cancel(); _sensorSub?.cancel(); _audioPlayer.dispose(); _sigCtrl.dispose(); _audioRecorder.dispose();
    super.dispose(); 
  }

  Future<void> _loadDailyLog() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (prefs.getString('log_date') != today) { await prefs.setInt('log_count', 0); await prefs.setString('log_date', today); setState(() => _todayEncounterCount = 0); } 
    else { setState(() => _todayEncounterCount = prefs.getInt('log_count') ?? 0); }
  }
  Future<void> _updateDailyLog(int nearbyCount) async {
    if (nearbyCount > _todayEncounterCount) {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _todayEncounterCount = nearbyCount);
      await prefs.setInt('log_count', nearbyCount);
      int gain = nearbyCount - _todayEncounterCount;
      if (gain > 0) EtherEngine.addEther(widget.user.uid, gain);
    }
  }
  Future<void> _checkDailyOracle() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (prefs.getString('last_oracle_date') != today) {
      await Future.delayed(const Duration(seconds: 2)); if (!mounted) return;
      EtherEngine.addEther(widget.user.uid, 10);
      showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: Colors.black87, title: Text("Oracle", style: GoogleFonts.cinzel(color: Colors.cyan, fontWeight: FontWeight.bold)), content: Text(OracleEngine.generateDailyMessage(_currentUserSoulType), style: GoogleFonts.zenMaruGothic(color: Colors.white)), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Receive +10 Ether"))]));
      await prefs.setString('last_oracle_date', today);
    }
  }
  Future<void> _determinePosition() async {
    if(!await Geolocator.isLocationServiceEnabled()) return;
    if(await Geolocator.checkPermission() == LocationPermission.denied) await Geolocator.requestPermission();
    Geolocator.getPositionStream().listen((pos) { if (mounted) setState(() => _currentPosition = pos); });
  }
  Future<void> _loadUserData() async {
    final d = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
    if(d.exists) { final data = d.data()!; setState(() { 
      _blocks = List<String>.from(data['blockedUids'] ?? []); 
      _currentUserIsMarried = data['isMarried'] ?? false; 
      _isPremiumUser = data['isPremium'] ?? false; 
      _currentUserGender = data['gender'] ?? 'Female'; 
      if(data['soulType']!=null) _currentUserSoulType = SoulType.values.firstWhere((e) => e.toString() == data['soulType'].toString(), orElse: () => SoulType.explorer); 
    }); }
  }
  Future<void> _checkReach() async { }
  Future<void> _toggleArMode() async {
    if (_isArMode) {
      setState(() => _isArMode = false);
      _cameraController?.dispose(); _compassSub?.cancel(); _sensorSub?.cancel(); _audioPlayer.stop(); 
    } else {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          _cameraController = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
          await _cameraController!.initialize();
          _compassSub = FlutterCompass.events?.listen((event) { if (mounted && event.heading != null) setState(() => _deviceHeading = event.heading!); });
          _sensorSub = gyroscopeEvents.listen((event) { if(mounted) setState(() { _gyroX += event.y * 2; _gyroY += event.x * 2; _gyroX = _gyroX.clamp(-50.0, 50.0); _gyroY = _gyroY.clamp(-100.0, 100.0); }); });
          setState(() => _isArMode = true);
        }
      } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("カメラ権限が必要です"))); }
    }
  }
  void _updateSoundStereo(double h, double b, double d) { 
    if (!_isArMode) return; 
    double diff = b - h; if (diff < -180) diff += 360; if (diff > 180) diff -= 360;
    double balance = (diff / 90.0).clamp(-1.0, 1.0);
    double volume = (1.0 - (d / _radarRadius)).clamp(0.1, 1.0);
    _audioPlayer.setBalance(balance); _audioPlayer.setVolume(volume);
  }

  Future<String?> _uploadFile(String path, String ext) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('kotodamas/${widget.user.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putFile(File(path));
      return await ref.getDownloadURL();
    } catch (e) { return null; }
  }
  Future<String?> _uploadBytes(List<int> bytes) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('kotodamas/${widget.user.uid}/${DateTime.now().millisecondsSinceEpoch}.png');
      await ref.putData(bytes as dynamic);
      return await ref.getDownloadURL();
    } catch (e) { return null; }
  }

  void _showAdd() {
    String txt = '';
    int mode = 0; 
    _sigCtrl.clear();
    _recordedPath = null;
    bool useRainbow = false; 
    bool privacyBlur = false;
    bool isEphemeral = false; 

    List<CategoryData> availableCats = getAvailableCategories(_currentUserIsMarried);
    CategoryData currentCat = availableCats[0];
    Color col = currentCat.color;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.95),
      title: Text(AppStrings.get(ctx, currentCat.actionKey), style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      content: SingleChildScrollView(
        physics: mode == 1 ? const NeverScrollableScrollPhysics() : const ScrollPhysics(),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: Icon(Icons.text_fields, color: mode==0?Colors.cyan:Colors.grey), onPressed: ()=>setS(()=>mode=0)),
            IconButton(icon: Icon(Icons.draw, color: mode==1?Colors.cyan:Colors.grey), onPressed: ()=>setS(()=>mode=1)),
            IconButton(icon: Icon(Icons.mic, color: mode==2?Colors.cyan:Colors.grey), onPressed: ()=>setS(()=>mode=2)),
          ]),
          const SizedBox(height: 10),
          if (mode == 0) TextField(style: const TextStyle(color: Colors.white), onChanged: (v)=>txt=v, decoration: InputDecoration(hintText: AppStrings.get(ctx, 'inputHint'))),
          if (mode == 1) Column(children: [
              Container(
                height: 200, 
                width: double.maxFinite,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white54)),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Signature(controller: _sigCtrl, backgroundColor: Colors.transparent))
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: ()=>_sigCtrl.clear())])
            ]),
          if (mode == 2) Column(children: [
              const Icon(Icons.graphic_eq, size: 50, color: Colors.white54),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _isRecording ? Colors.red : Colors.cyan),
                onPressed: () async {
                  if (_isRecording) {
                    final path = await _audioRecorder.stop();
                    setS(() { _isRecording = false; _recordedPath = path; });
                  } else {
                    if (await Permission.microphone.request().isGranted) {
                      final dir = await getTemporaryDirectory();
                      final path = '${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.m4a';
                      await _audioRecorder.start(path: path, encoder: AudioEncoder.aacLc);
                      setS(() => _isRecording = true);
                    }
                  }
                },
                child: Text(_isRecording ? "STOP" : "REC"),
              ),
              if (_recordedPath != null) const Text("Recorded!", style: TextStyle(color: Colors.green))
            ]),
          const SizedBox(height: 10),
          Wrap(spacing: 5, children: availableCats.map((c) => Padding(padding: const EdgeInsets.all(2.0), child: ChoiceChip(
            avatar: Icon(c.icon, size: 16, color: c.id == currentCat.id ? Colors.white : c.color), 
            label: Text(c.label, style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.bold)), 
            selected: currentCat.id == c.id, selectedColor: c.color, onSelected: (v) => setS((){ currentCat=c; col=c.color; })))).toList()),
          CheckboxListTile(title: Text(AppStrings.get(ctx, 'ephemeral'), style: const TextStyle(color: Colors.pinkAccent)), subtitle: Text(AppStrings.get(ctx, 'ephemeralDesc'), style: const TextStyle(color: Colors.grey, fontSize: 10)), value: isEphemeral, onChanged: (v) => setS(() => isEphemeral = v!), activeColor: Colors.pinkAccent),
          CheckboxListTile(title: Text(AppStrings.get(ctx, 'privacyBlur'), style: const TextStyle(color: Colors.white)), subtitle: Text(AppStrings.get(ctx, 'privacyBlurDesc'), style: const TextStyle(color: Colors.grey, fontSize: 10)), value: privacyBlur, onChanged: (v) => setS(() => privacyBlur = v!), activeColor: Colors.teal),
          SwitchListTile(title: Text(AppStrings.get(ctx, 'premium'), style: const TextStyle(color: Colors.amber)), value: useRainbow, onChanged: (v)=>setS(()=>useRainbow=v)),
        ]),
      ),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: Text(AppStrings.get(ctx, 'cancel'))),
        ElevatedButton(onPressed: () async {
          if (_currentPosition == null) return;
          String type = 'text';
          String? contentUrl;
          String message = txt;
          if (mode == 1) { 
            final bytes = await _sigCtrl.toPngBytes();
            if (bytes != null) { contentUrl = await _uploadBytes(bytes); type = 'image'; message = 'Handwriting'; }
          } else if (mode == 2) { 
            if (_recordedPath != null) { contentUrl = await _uploadFile(_recordedPath!, 'm4a'); type = 'audio'; message = 'Voice Star'; }
          }
          if ((mode == 0 && txt.isNotEmpty) || contentUrl != null) {
            double lat = _currentPosition!.latitude;
            double lng = _currentPosition!.longitude;
            if (privacyBlur) { final r = Random(); lat += (r.nextDouble()-0.5)*0.01; lng += (r.nextDouble()-0.5)*0.01; }
            bool finalRainbow = _isPremiumUser ? true : useRainbow; 
            EtherEngine.addEther(widget.user.uid, 50);
            await FirebaseFirestore.instance.collection('kotodamas').add({
              'message': message, 'contentUrl': contentUrl, 'type': type,
              'category': currentCat.id, 'colorValue': col.value, 'latitude': lat, 'longitude': lng, 
              'uid': widget.user.uid, 'createdAt': FieldValue.serverTimestamp(), 
              'likes': 0, 'reports': 0, 'views': 0, 
              'isPremium': finalRainbow, 'isEphemeral': isEphemeral,
              'gender': _currentUserGender, 
            });
            if (mounted && ctx.mounted) Navigator.pop(ctx);
          }
        }, child: Text(AppStrings.get(ctx, 'post')))
      ]
    )));
  }

  void _detail(String id, Map<String, dynamic> d) {
    if (d['isSystem'] == true) { showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF0e1626), title: Text(AppStrings.get(ctx, 'aiMessage'), style: const TextStyle(color: Colors.cyanAccent)), content: Text(d['message'], style: GoogleFonts.zenMaruGothic(color: Colors.white, fontSize: 18)), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))])); return; }
    bool isEphemeral = d['isEphemeral'] == true;
    final uid = d['uid'];
    if (uid != widget.user.uid) { FirebaseFirestore.instance.collection('kotodamas').doc(id).update({'views': FieldValue.increment(1)}); }
    final col = Color(d['colorValue'] ?? 0xFFFFFFFF);
    final likes = d['likes'] ?? 0;
    final views = d['views'] ?? 0;
    String catId = d['category'] ?? 'Mystery';
    var matchedCat = appCategories.firstWhere((c) => c.id == catId || c.label == catId, orElse: () => appCategories[3]);
    bool isTargetPremium = d['isPremium'] == true;
    String type = d['type'] ?? 'text';
    String? contentUrl = d['contentUrl'];

    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7, builder: (_, sc) => Container(
        decoration: BoxDecoration(color: const Color(0xFF0e1626).withOpacity(0.95), border: Border.all(color: col.withOpacity(0.5)), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          if (isTargetPremium) Center(child: Icon(Icons.verified, color: Colors.amber, size: 20)),
          if (type == 'text') Text(d['message'], textAlign: TextAlign.center, style: GoogleFonts.zenMaruGothic(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: col, blurRadius: 10)]))
          else if (type == 'image' && contentUrl != null) Image.network(contentUrl, height: 200, fit: BoxFit.contain)
          else if (type == 'audio' && contentUrl != null) ElevatedButton.icon(icon: const Icon(Icons.play_arrow), label: Text(AppStrings.get(context, 'playVoice')), onPressed: () { _audioPlayer.play(UrlSource(contentUrl)); }),
          const SizedBox(height: 10), 
          Center(child: Chip(avatar: Icon(matchedCat.icon, size: 16, color: Colors.white), label: Text(matchedCat.label, style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)), backgroundColor: col.withOpacity(0.3))), 
          if (isEphemeral) const Padding(padding: EdgeInsets.all(8.0), child: Text("⚠️ This star will vanish.", style: TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 20),
          Center(child: Text("${AppStrings.get(context, 'views')}: $views", style: GoogleFonts.cinzel(color: Colors.grey, fontSize: 12))), const SizedBox(height: 10),
          FutureBuilder<List<dynamic>>(
            future: Future.wait([FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get(), FirebaseFirestore.instance.collection('users').doc(uid).get(), FirebaseFirestore.instance.collection('kotodamas').doc(id).collection('msgs').get()]),
            builder: (ctx, snaps) {
              if(!snaps.hasData) return const Center(child: CircularProgressIndicator());
              final u = snaps.data![1].data() as Map<String, dynamic>?;
              final imgs = u?['photoUrls'] ?? [];
              final emo = u?['emoFilter'] ?? true;
              bool isAllowed = (u?['allowedViewers'] ?? []).contains(widget.user.uid);
              bool showMosaic = emo && !isAllowed && (uid != widget.user.uid);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_isPremiumUser && u != null && uid != widget.user.uid) ...[Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppStrings.get(context, 'aiAnalysisTitle'), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(AiInsightEngine.analyzePersonality(SoulType.values.firstWhere((e)=>e.toString()==u['soulType'], orElse: ()=>SoulType.explorer), catId), style: const TextStyle(color: Colors.white70, fontSize: 12))]))],
                Text(AppStrings.get(ctx, 'postedBy'), style: GoogleFonts.cinzel(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)), 
                Text(u?['nickname'] ?? 'No Name', style: const TextStyle(color: Colors.white, fontSize: 20)), const SizedBox(height: 10),
                if(imgs.isNotEmpty) SizedBox(height: 150, child: ListView(scrollDirection: Axis.horizontal, children: [for(var url in imgs) Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: showMosaic ? ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Image.network(url)) : Image.network(url)))])),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  ElevatedButton.icon(icon: const Icon(Icons.favorite), label: Text("$likes"), onPressed: (){ FirebaseFirestore.instance.collection('kotodamas').doc(id).update({'likes': likes+1}); if (ctx.mounted) Navigator.pop(ctx); }),
                  if(uid != widget.user.uid) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBB86FC)), child: Text(AppStrings.get(ctx, 'talk')), onPressed: (){ Navigator.push(ctx, MaterialPageRoute(builder: (_) => ChatScreen(id: id, uid: widget.user.uid, targetUid: uid, col: col))); }),
                ]),
                if(uid != widget.user.uid) Row(mainAxisAlignment: MainAxisAlignment.center, children: [TextButton(child: Text(AppStrings.get(ctx, 'block'), style: const TextStyle(color: Colors.red)), onPressed: () { FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'blockedUids': FieldValue.arrayUnion([uid])}); setState(() => _blocks.add(uid)); if (ctx.mounted) Navigator.pop(ctx); }), TextButton(child: Text(AppStrings.get(ctx, 'report'), style: const TextStyle(color: Colors.grey)), onPressed: () { FirebaseFirestore.instance.collection('kotodamas').doc(id).update({'reports': (d['reports']??0)+1}); if (ctx.mounted) Navigator.pop(ctx); })])
              ]);
            }
          )
        ]))
    )).whenComplete(() {
      if (isEphemeral && uid != widget.user.uid) {
        FirebaseFirestore.instance.collection('kotodamas').doc(id).delete();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get(context, 'vanished'))));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final isBrightMode = (_filter == 'Chill');
    final textColor = isBrightMode ? const Color(0xFF4E342E) : Colors.white;
    final iconColor = isBrightMode ? const Color(0xFF6D4C41) : const Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isListMode ? AppBar(
        title: Text("L U E U R", style: GoogleFonts.cinzel(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 18)), 
        backgroundColor: Colors.transparent, actions: [IconButton(icon: const Icon(Icons.radar, color: Color(0xFFBB86FC)), onPressed: () => setState(() => _isListMode = false))]
      ) : null,
      body: GestureDetector(
        onScaleStart: (details) { _baseRadius = _radarRadius; setState(() => _isZooming = true); },
        onScaleUpdate: (details) { if (_isListMode) return; setState(() { double newRadius = _baseRadius / details.scale; _radarRadius = newRadius.clamp(100.0, 5000.0); }); },
        onScaleEnd: (details) { setState(() => _isZooming = false); },
        child: Stack(children: [
            AnimatedContainer(duration: const Duration(seconds: 1), decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.5, colors: getCategoryBg(_filter)))),
            if (_isArMode && _cameraController != null && _cameraController!.value.isInitialized) Stack(fit: StackFit.expand, children: [CameraPreview(_cameraController!), Container(color: Colors.black.withOpacity(0.4))]),
            StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('kotodamas').snapshots(), builder: (ctx, snap) {
                if(!snap.hasData || _currentPosition == null) return const Center(child: CircularProgressIndicator());
                final List<Map<String, dynamic>> stars = [];
                final docs = snap.data!.docs;
                int nearbyCount = 0;
                for (var doc in docs) {
                  final val = doc.data() as Map<String, dynamic>;
                  if(_blocks.contains(val['uid'])) continue;
                  if((val['reports']??0) >= 5) continue;
                  if(val['createdAt'] != null) { if(DateTime.now().difference((val['createdAt'] as Timestamp).toDate()).inHours >= 24) continue; }
                  if (_currentUserIsMarried && val['category'] == 'Love') continue;
                  bool isMeMale = _currentUserGender == 'Male';
                  String targetGender = val['gender'] ?? (isMeMale ? 'Female' : 'Male'); 
                  bool isSameSex = _currentUserGender == targetGender;
                  if (_filter == 'Love') {
                    if (isSameSex) continue;
                  } else if (_filter != 'All') {
                    if (!_includeSameSex && isSameSex) continue;
                  }
                  if(_filter != 'All') { String cat = val['category'] ?? ''; var targetCat = appCategories.firstWhere((c) => c.id == _filter); if (cat != _filter && cat != targetCat.label) continue; }
                  double dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, val['latitude'], val['longitude']);
                  if (!_isListMode && dist > _radarRadius * 1.2) continue;
                  if (dist < 500) nearbyCount++;
                  double bearing = Geolocator.bearingBetween(_currentPosition!.latitude, _currentPosition!.longitude, val['latitude'], val['longitude']);
                  double offsetX = 0; double offsetY = 0;
                  if (_isArMode) { double diff = bearing - _deviceHeading; if (diff < -180) diff += 360; if (diff > 180) diff -= 360; double pxPerDegree = size.width / 60.0; offsetX = diff * pxPerDegree; offsetY = _gyroX * 5 + ((dist / _radarRadius) * 100) - 50; }
                  double sx, sy;
                  if (_isArMode) { sx = centerX + offsetX; sy = centerY + offsetY; } else { double r = (dist / _radarRadius) * (min(size.width, size.height)/2.0); double rad = (bearing * pi) / 180.0; sx = centerX + (r * sin(rad)); sy = centerY - (r * cos(rad)); }
                  val['id'] = doc.id; val['sx'] = sx; val['sy'] = sy; val['dist'] = dist; val['isSystem'] = false; val['ether'] = val['ether'] ?? 0;
                  val['type'] = val['type'] ?? 'text';
                  val['contentUrl'] = val['contentUrl'];
                  if (_isArMode) { if (sx < -100 || sx > size.width + 100) continue; }
                  stars.add(val);
                  if (_isArMode && dist < 500) { _updateSoundStereo(_deviceHeading, bearing, dist); }
                }
                if (!_isListMode && stars.length < 5 && _filter == 'All') {
                  int need = 5 - stars.length;
                  for (int k=0; k<need; k++) {
                    final aiStar = AiContextEngine.generateLocalBot(_currentPosition!.latitude, _currentPosition!.longitude, k);
                    double dist = 200.0 + (k*50); double bearing = k * (360/need); double r = (dist / _radarRadius) * (min(size.width, size.height)/2.0); double rad = (bearing * pi) / 180.0;
                    aiStar['sx'] = centerX + (r * sin(rad)); aiStar['sy'] = centerY - (r * cos(rad)); aiStar['dist'] = dist;
                    stars.add(aiStar); nearbyCount++;
                  }
                }
                WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) _updateDailyLog(nearbyCount); });
                if (!_isListMode && !_isArMode) { for (int i = 0; i < stars.length; i++) { for (int j = 0; j < i; j++) { double dx = stars[i]['sx'] - stars[j]['sx']; double dy = stars[i]['sy'] - stars[j]['sy']; if (sqrt(dx*dx + dy*dy) < 40.0) { stars[i]['sx'] += 30.0; stars[i]['sy'] += 30.0; } } } }
                stars.sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
                if (_isListMode) { return ListView.builder(itemCount: stars.length, itemBuilder: (context, index) { final s = stars[index]; final dist = (s['dist'] as double); return Card(color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: ListTile(leading: CircleAvatar(backgroundColor: Color(s['colorValue']).withOpacity(0.3), child: Icon(Icons.star, color: Color(s['colorValue']), size: 20)), title: Text(s['message'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), subtitle: Text("${s['category']} • ${dist.toStringAsFixed(0)}m", style: const TextStyle(color: Colors.grey, fontSize: 12)), onTap: () => _detail(s['id'], s))); }); }
                List<CategoryData> visibleCats = getAvailableCategories(_currentUserIsMarried);
                return Stack(children: [
                    AnimatedBuilder(animation: _animCtrl, builder: (context, child) { return CustomPaint(size: size, painter: UniversePainter(stars: stars, scale: min(size.width, size.height) / (2.0 * _radarRadius), centerX: centerX, centerY: centerY, animValue: _animCtrl.value, currentCategory: _filter)); }),
                    ...stars.map((s) {
                        final color = Color(s['colorValue']); 
                        final msg = s['message'] as String; 
                        final type = s['type'] ?? 'text'; 
                        final contentUrl = s['contentUrl'] as String?;
                        final dist = s['dist'] as double; 
                        final isSystem = s['isSystem'] == true; 
                        double opacity = (1.0 - (dist / (_radarRadius * 0.8))).clamp(0.0, 1.0); if(isSystem) opacity = 0.7;
                        return Positioned(
                          left: s['sx'] - 30, 
                          top: s['sy'] - 30, 
                          child: GestureDetector(
                            onTap: () => _detail(s['id'], s), 
                            child: AnimatedBuilder(
                              animation: _animCtrl, 
                              builder: (context, child) { 
                                double pulse = 1.0 + (_animCtrl.value * 0.2); 
                                return Container(
                                  width: 60 * pulse, 
                                  height: 60 * pulse, 
                                  alignment: Alignment.center, 
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(opacity * 0.3), boxShadow: [BoxShadow(color: color, blurRadius: 10 * pulse, spreadRadius: 1)]), 
                                  child: (type == 'image' && contentUrl != null)
                                    ? Padding(padding: const EdgeInsets.all(8.0), child: Image.network(contentUrl, color: isBrightMode ? Colors.black : Colors.white, fit: BoxFit.contain))
                                    : (type == 'audio')
                                        ? Icon(Icons.graphic_eq, color: (isBrightMode ? Colors.black87 : Colors.white).withOpacity(opacity), size: 24)
                                        : Text(msg.length > 4 ? "${msg.substring(0,4)}.." : msg, style: GoogleFonts.zenMaruGothic(color: (isBrightMode ? Colors.black87 : Colors.white).withOpacity(opacity), fontSize: 10, fontWeight: FontWeight.bold, shadows: isBrightMode ? [] : [Shadow(color: Colors.black, blurRadius: 4)]), textAlign: TextAlign.center)
                                ); 
                              }
                            )
                          )
                        );
                    }).toList(),
                    if (!_isArMode) Positioned(left: centerX - 10, top: centerY - 10, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: isBrightMode ? Colors.brown : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (isBrightMode ? Colors.brown : Colors.white).withOpacity(0.8), blurRadius: 15, spreadRadius: 2)]))),
                    Positioned(top: 50, left: 20, right: 20, child: Column(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(" L U E U R", style: GoogleFonts.cinzel(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 18)), 
                        Row(children: [IconButton(icon: Icon(Icons.mail, color: iconColor), onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>ChatHistoryPage(user: widget.user)))), IconButton(icon: Icon(Icons.person, color: iconColor), onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>ProfileEditPage(user: widget.user))))])
                      ])), 
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                        Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(AppStrings.get(context, 'all'), style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.bold)), selected: _filter == 'All', onSelected: (v) => setState(() => _filter = 'All'))), 
                        ...visibleCats.map((c) => Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(avatar: Icon(c.icon, size: 16, color: c.id == _filter ? Colors.white : c.color), label: Text(c.label, style: GoogleFonts.cinzel(fontSize: 11, fontWeight: FontWeight.bold)), selected: _filter == c.id, selectedColor: c.color, onSelected: (v) => setState(() => _filter = c.id))))
                      ])),
                      if (_filter != 'All' && _filter != 'Love') 
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_includeSameSex ? "Everyone" : "Opposite Only", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              Transform.scale(scale: 0.7, child: Switch(value: _includeSameSex, activeColor: Colors.tealAccent, onChanged: (v) => setState(() => _includeSameSex = v))),
                          ]),
                        )
                    ])),
                    Positioned(bottom: 120, left: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Row(children: [const Icon(Icons.history, color: Colors.cyanAccent, size: 16), const SizedBox(width: 5), Text(AppStrings.get(context, 'logCount').replaceAll('@n', "$_todayEncounterCount"), style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12))]))),
                    Positioned(bottom: 100, right: 20, child: Column(children: [FloatingActionButton.small(heroTag: "ar", backgroundColor: _isArMode ? Colors.pinkAccent : Colors.white10, child: const Icon(Icons.view_in_ar, color: Colors.white), onPressed: _toggleArMode), const SizedBox(height: 10), FloatingActionButton.small(heroTag: "sound", backgroundColor: Colors.white10, child: const Icon(Icons.headphones, color: Colors.white), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get(context, 'soundMode')))))])),
                    if (_isZooming || _radarRadius != 1000.0) Positioned(bottom: 40, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)), child: Text("Radius: ${(_radarRadius < 1000) ? "${_radarRadius.toStringAsFixed(0)}m" : "${(_radarRadius/1000).toStringAsFixed(1)}km"}", style: GoogleFonts.oswald(color: Colors.white, fontSize: 16, letterSpacing: 1.2))))),
                    Positioned(bottom: 30, right: 20, child: FloatingActionButton(onPressed: _showAdd, backgroundColor: const Color(0xFFBB86FC), child: const Icon(Icons.add)))
                ]);
            }),
        ]),
      ),
    );
  }
}