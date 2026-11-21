import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundEffects.initSoundSetting();
  runApp(const AvatarLudoApp());
}

// ==================== CONSTANTS & DATA MODELS ====================

enum GameMode { ludo, snakeLadder, partyRace }

class AvatarCharacter {
  final String name;
  final String emoji;
  const AvatarCharacter(this.name, this.emoji);
}

const List<AvatarCharacter> kAllAvatars = [
  AvatarCharacter('Hero', '🦸'),
  AvatarCharacter('Wizard', '🧙'),
  AvatarCharacter('Ninja', '🥷'),
  AvatarCharacter('Queen', '👸'),
  AvatarCharacter('Robo', '🤖'),
  AvatarCharacter('Vampire', '🧛'),
  AvatarCharacter('Fox', '🦊'),
  AvatarCharacter('Panda', '🐼'),
  AvatarCharacter('Alien', '👽'),
  AvatarCharacter('Genie', '🧞'),
  AvatarCharacter('Cowboy', '🤠'),
  AvatarCharacter('Lion', '🦁'),
];

const List<Color> kPlayerColors = [
  Color(0xFFE53935), // Red
  Color(0xFF43A047), // Green
  Color(0xFFFDD835), // Yellow
  Color(0xFF1E88E5), // Blue
];

const Map<int, int> kSnakesMap = {
  98: 79,
  95: 75,
  87: 36,
  62: 19,
  54: 34,
  17: 7,
};

const Map<int, int> kLaddersMap = {
  4: 14,
  9: 31,
  21: 42,
  28: 84,
  51: 67,
  72: 91,
  80: 99,
};

class Token {
  final int id;
  final int playerIndex;
  int step; // Ludo: 0=Yard, 1..52=Track, 53..57=Home, 58=Finish. SnakeLadder: 1..100.

  Token({
    required this.id,
    required this.playerIndex,
    this.step = 0,
  });

  bool get isInYard => step == 0;
  bool get isHome => step == 58;
}

class Player {
  final int id;
  final int arm; // 0..3
  final Color color;
  final AvatarCharacter avatar;
  final bool isBot;
  final String? customName;
  final List<Token> tokens;
  bool isFinished;

  Player({
    required this.id,
    required this.arm,
    required this.color,
    required this.avatar,
    required this.isBot,
    this.customName,
    required this.tokens,
    this.isFinished = false,
  });

  String get name {
    final base = (customName != null && customName!.trim().isNotEmpty)
        ? customName!.trim()
        : avatar.name;
    return isBot ? '$base (Bot)' : base;
  }

  int get finishedCount => tokens.where((t) => t.isHome).length;
}

// ==================== SOUND SERVICE ====================

class SoundEffects {
  static const MethodChannel _audioChannel = MethodChannel('com.ludomania.game/audio');
  static bool soundEnabled = true;

  static void toggleSound() {
    soundEnabled = !soundEnabled;
    LocalGameStorage.saveSoundEnabled(soundEnabled);
  }

  static Future<void> initSoundSetting() async {
    soundEnabled = await LocalGameStorage.loadSoundEnabled();
  }

  static void playHop() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playHop');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  static void playDiceRoll() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playDiceRoll');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  static void playDiceLand() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playDiceLand');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static void playCapture() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playCapture');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static void playSnakeBite() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playSnakeBite');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
      Future.delayed(const Duration(milliseconds: 100), () {
        try { SystemSound.play(SystemSoundType.alert); } catch (_) {}
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        try { SystemSound.play(SystemSoundType.alert); } catch (_) {}
      });
    } catch (_) {}
  }

  static void playRocket() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playRocket');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static void playSlip() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playSlip');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static void playSlap() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playSlap');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static void playHomeReach() {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playHome');
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  static void playVictory() async {
    if (!soundEnabled) return;
    try {
      _audioChannel.invokeMethod('playVictory');
    } catch (_) {}
    for (int i = 0; i < 5; i++) {
      if (!soundEnabled) return;
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }
}

// ==================== PERSISTENT STORAGE SERVICE ====================

class LocalGameStorage {
  static const String _keySettings = 'avatar_ludo_settings';
  static const String _keySavedGame = 'avatar_ludo_saved_game';
  static const String _keyStats = 'avatar_ludo_stats';
  static const String _keySound = 'avatar_ludo_sound';

  static final Map<String, String> _memCache = {};

  static Future<void> saveSoundEnabled(bool enabled) async {
    await saveString(_keySound, enabled ? 'true' : 'false');
  }

  static Future<bool> loadSoundEnabled() async {
    final raw = await getString(_keySound);
    if (raw == null) return true;
    return raw == 'true';
  }

  static Future<File?> _getLocalFile(String key) async {
    try {
      final dir = Directory.systemTemp;
      return File('${dir.path}/$key.json');
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveString(String key, String value) async {
    _memCache[key] = value;
    try {
      final file = await _getLocalFile(key);
      if (file != null) {
        await file.writeAsString(value);
      }
    } catch (_) {}
  }

  static Future<String?> getString(String key) async {
    if (_memCache.containsKey(key)) {
      return _memCache[key];
    }
    try {
      final file = await _getLocalFile(key);
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        _memCache[key] = content;
        return content;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> removeKey(String key) async {
    _memCache.remove(key);
    try {
      final file = await _getLocalFile(key);
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> saveSettings({
    required int playerCount,
    required int avatarsPerPlayer,
    required List<bool> isBotList,
    required List<int> selectedAvatarIndices,
    required List<String> playerNames,
  }) async {
    final data = {
      'playerCount': playerCount,
      'avatarsPerPlayer': avatarsPerPlayer,
      'isBotList': isBotList,
      'selectedAvatarIndices': selectedAvatarIndices,
      'playerNames': playerNames,
    };
    await saveString(_keySettings, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadSettings() async {
    final raw = await getString(_keySettings);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveGameState({
    required List<Player> players,
    required int currentPlayerIndex,
    required int avatarsCount,
    required List<Player> rankings,
  }) async {
    final data = {
      'currentPlayerIndex': currentPlayerIndex,
      'avatarsCount': avatarsCount,
      'rankings': rankings.map((p) => p.id).toList(),
      'players': players.map((p) {
        return {
          'id': p.id,
          'arm': p.arm,
          'colorIndex': kPlayerColors.indexOf(p.color),
          'avatarName': p.avatar.name,
          'customName': p.customName,
          'isBot': p.isBot,
          'isFinished': p.isFinished,
          'tokens': p.tokens.map((t) => {'id': t.id, 'step': t.step}).toList(),
        };
      }).toList(),
    };
    await saveString(_keySavedGame, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadGameState() async {
    final raw = await getString(_keySavedGame);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSavedGame() async {
    await removeKey(_keySavedGame);
  }

  static Future<void> recordWin(String avatarName) async {
    final raw = await getString(_keyStats);
    Map<String, int> stats = {};
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        stats = map.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    stats[avatarName] = (stats[avatarName] ?? 0) + 1;
    await saveString(_keyStats, jsonEncode(stats));
  }

  static Future<Map<String, int>> loadStats() async {
    final raw = await getString(_keyStats);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static List<Player> deserializePlayers(List<dynamic> listData) {
    List<Player> result = [];
    for (var item in listData) {
      final map = item as Map<String, dynamic>;
      final id = (map['id'] as num).toInt();
      final arm = (map['arm'] as num).toInt();
      final colorIdx = (map['colorIndex'] as num).toInt();
      final avatarName = map['avatarName'] as String;
      final customName = map['customName'] as String?;
      final isBot = map['isBot'] as bool;
      final isFinished = map['isFinished'] as bool? ?? false;

      final color = (colorIdx >= 0 && colorIdx < kPlayerColors.length)
          ? kPlayerColors[colorIdx]
          : kPlayerColors[id % kPlayerColors.length];

      final avatar = kAllAvatars.firstWhere(
        (a) => a.name == avatarName,
        orElse: () => kAllAvatars.first,
      );

      final tokenList = (map['tokens'] as List<dynamic>).map((tData) {
        final tMap = tData as Map<String, dynamic>;
        return Token(
          id: (tMap['id'] as num).toInt(),
          playerIndex: id,
          step: (tMap['step'] as num).toInt(),
        );
      }).toList();

      result.add(Player(
        id: id,
        arm: arm,
        color: color,
        avatar: avatar,
        isBot: isBot,
        customName: customName,
        tokens: tokenList,
        isFinished: isFinished,
      ));
    }
    return result;
  }
}

// ==================== BOARD GEOMETRY HELPERS (4-PLAYER LUDO) ====================

class BoardGeometry {
  final double size;
  final Offset center;

  BoardGeometry(this.size) : center = Offset(size / 2, size / 2);

  double get centerRadius => size * 0.095;
  double get cellSize => size * 0.065;
  double get yardRadius => size * 0.38;

  double armAngle(int arm) => -math.pi / 2 + arm * (math.pi / 2);

  Offset cellPos(int arm, int lane, int row) {
    final theta = armAngle(arm);
    final u = centerRadius + (row - 0.5) * cellSize;
    final v = lane * cellSize;
    final dx = u * math.cos(theta) - v * math.sin(theta);
    final dy = u * math.sin(theta) + v * math.cos(theta);
    return Offset(center.dx + dx, center.dy + dy);
  }

  Offset ringCellPos(int ringIndex) {
    final arm = (ringIndex ~/ 13) % 4;
    final sub = ringIndex % 13;
    if (sub < 6) {
      return cellPos(arm, -1, sub + 1);
    } else if (sub == 6) {
      return cellPos(arm, 0, 6);
    } else {
      final row = 13 - sub;
      return cellPos(arm, 1, row);
    }
  }

  Offset homeCellPos(int arm, int step) {
    return cellPos(arm, 0, step);
  }

  Offset finishCellPos(int arm) {
    final theta = armAngle(arm);
    final u = centerRadius * 0.5;
    final dx = u * math.cos(theta);
    final dy = u * math.sin(theta);
    return Offset(center.dx + dx, center.dy + dy);
  }

  Offset yardCenterPos(int arm) {
    final theta = armAngle(arm) - math.pi / 4;
    return Offset(
      center.dx + yardRadius * math.cos(theta),
      center.dy + yardRadius * math.sin(theta),
    );
  }

  Offset yardSlotPos(int arm, int slot) {
    final yc = yardCenterPos(arm);
    final d = cellSize * 0.7;
    final dx = (slot % 2 == 0 ? -d : d);
    final dy = (slot < 2 ? -d : d);
    return Offset(yc.dx + dx, yc.dy + dy);
  }

  Offset getTokenPosition(int playerArm, int tokenStep, int tokenIndexOnCell, int totalOnCell) {
    Offset basePos;
    if (tokenStep == 0) {
      basePos = yardSlotPos(playerArm, tokenIndexOnCell);
    } else if (tokenStep >= 1 && tokenStep <= 52) {
      final startRing = playerArm * 13 + 5;
      final ringIndex = (startRing + tokenStep - 1) % 52;
      basePos = ringCellPos(ringIndex);
    } else if (tokenStep >= 53 && tokenStep <= 57) {
      final homeStep = tokenStep - 52;
      basePos = homeCellPos(playerArm, homeStep);
    } else {
      basePos = finishCellPos(playerArm);
    }

    if (tokenStep > 0 && totalOnCell > 1) {
      final angle = (tokenIndexOnCell / totalOnCell) * 2 * math.pi;
      final offsetDist = size * 0.015;
      return Offset(
        basePos.dx + offsetDist * math.cos(angle),
        basePos.dy + offsetDist * math.sin(angle),
      );
    }
    return basePos;
  }
}

List<int> getPlayerArms(int playerCount) {
  switch (playerCount) {
    case 2:
      return [0, 2];
    case 3:
      return [0, 1, 2];
    case 4:
    default:
      return [0, 1, 2, 3];
  }
}

bool isRingIndexSafe(int ringIndex) {
  final sub = ringIndex % 13;
  return sub == 5 || sub == 8 || sub == 2;
}

Offset getSnakeSquarePos(int square, double boardSize) {
  if (square < 1) square = 1;
  if (square > 100) square = 100;

  final cellSize = boardSize / 10;
  final index = square - 1;
  final rowFromBottom = index ~/ 10;
  final colInRow = index % 10;

  int col;
  if (rowFromBottom % 2 == 0) {
    col = colInRow;
  } else {
    col = 9 - colInRow;
  }

  final x = (col + 0.5) * cellSize;
  final y = (9 - rowFromBottom + 0.5) * cellSize;
  return Offset(x, y);
}

// ==================== APP ROOT ====================

class AvatarLudoApp extends StatelessWidget {
  const AvatarLudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Mania',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1B1238),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const GameModeSelectionScreen(),
    );
  }
}

// ==================== MAIN MENU / GAME MODE SELECTION SCREEN ====================

class GameModeSelectionScreen extends StatefulWidget {
  const GameModeSelectionScreen({super.key});

  @override
  State<GameModeSelectionScreen> createState() => _GameModeSelectionScreenState();
}

class _GameModeSelectionScreenState extends State<GameModeSelectionScreen> {
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xFF26194D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.amber, width: 2.5),
        ),
        title: const Column(
          children: [
            LudoManiaLogoWidget(size: 72),
            SizedBox(height: 8),
            Text(
              'LUDO MANIA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.amber,
                fontSize: 22,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'v1.0.0 • 3-in-1 Party Game',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(color: Colors.white24),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.person_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text('Developer:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 28, top: 2),
              child: Text(
                'Shubham Kr Tiwari',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.tealAccent, size: 20),
                SizedBox(width: 8),
                Text('About Game:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 28, top: 4),
              child: Text(
                'Ludo Mania is a modern 3-in-1 Avatar Board Game designed for endless fun with friends and family!',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎲 Mode 1: Classic Avatar Ludo', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('🐍 Mode 2: 100-Square Snake & Ladders', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('🤪 Mode 3: Funny Party Race', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF4A3580), Color(0xFF1B1238)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 28),
                      tooltip: 'About Game',
                      onPressed: () => _showAboutDialog(context),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                      ).createShader(bounds),
                      child: const Text(
                        'LUDO MANIA',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Sound Toggle Button
                    IconButton(
                      icon: Icon(
                        SoundEffects.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: SoundEffects.soundEnabled ? Colors.amber : Colors.white38,
                        size: 28,
                      ),
                      tooltip: SoundEffects.soundEnabled ? 'Mute Sound' : 'Unmute Sound',
                      onPressed: () {
                        setState(() {
                          SoundEffects.toggleSound();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Text(
                'Select Game Mode to Play',
                style: TextStyle(color: Color(0xFFD1C4E9), fontSize: 13, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              const LudoManiaLogoWidget(size: 95),
              const SizedBox(height: 16),

              // Game Mode Cards
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mode 1: Avatar Ludo
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CharacterSelectionScreen(gameMode: GameMode.ludo),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.amber, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Row(
                            children: [
                              Text('🎲', style: TextStyle(fontSize: 48)),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AVATAR LUDO',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.amber,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Classic 4-Player Square Board with Avatars, Dice & Captures!',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mode 2: Snake & Ladders
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CharacterSelectionScreen(gameMode: GameMode.snakeLadder),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00695C), Color(0xFF004D40)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.tealAccent, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.tealAccent.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Row(
                            children: [
                              Text('🐍🪜', style: TextStyle(fontSize: 38)),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SNAKE & LADDERS',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.tealAccent,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      '100-Square Board with Snakes 🐍, Ladders 🪜 & Avatars!',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.tealAccent),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mode 3: Avatar Party Race
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CharacterSelectionScreen(gameMode: GameMode.partyRace),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE65100), Color(0xFFBF360C)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.orangeAccent, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orangeAccent.withOpacity(0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: const Row(
                            children: [
                              Text('🤪🎉', style: TextStyle(fontSize: 38)),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FUNNY PARTY RACE',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.orangeAccent,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Funny Party Race with Bananas 🍌, Rockets 🚀, Traps 🕳️ & Slaps 🥊!',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.orangeAccent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Developer Footer Credit
              GestureDetector(
                onTap: () => _showAboutDialog(context),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Developed with ❤️ by ',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        'Shubham Kr Tiwari',
                        style: TextStyle(
                          color: Colors.amber[400],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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

// ==================== CHARACTER SELECTION / SETUP SCREEN ====================

class CharacterSelectionScreen extends StatefulWidget {
  final GameMode gameMode;

  const CharacterSelectionScreen({
    super.key,
    required this.gameMode,
  });

  @override
  State<CharacterSelectionScreen> createState() => _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  int _playerCount = 4;
  int _avatarsPerPlayer = 2;
  List<bool> _isBotList = [false, true, true, true];
  List<int> _selectedAvatarIndices = [0, 1, 2, 3];
  List<String> _playerNames = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
  Map<String, dynamic>? _savedGameData;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() async {
    final settings = await LocalGameStorage.loadSettings();
    final savedGame = (widget.gameMode == GameMode.ludo) ? await LocalGameStorage.loadGameState() : null;

    if (!mounted) return;
    setState(() {
      if (settings != null) {
        final pVal = (settings['playerCount'] as num).toInt();
        _playerCount = pVal > 4 ? 4 : (pVal < 2 ? 2 : pVal);
        _avatarsPerPlayer = (settings['avatarsPerPlayer'] as num).toInt();
        final rawBots = (settings['isBotList'] as List<dynamic>).map((e) => e as bool).toList();
        _isBotList = rawBots.length >= 4 ? rawBots.sublist(0, 4) : [false, true, true, true];
        final rawAvatars =
            (settings['selectedAvatarIndices'] as List<dynamic>).map((e) => (e as num).toInt()).toList();
        _selectedAvatarIndices = rawAvatars.length >= 4 ? rawAvatars.sublist(0, 4) : [0, 1, 2, 3];
        if (settings['playerNames'] != null) {
          final rawNames = (settings['playerNames'] as List<dynamic>).map((e) => e as String).toList();
          if (rawNames.length >= 4) {
            _playerNames = rawNames.sublist(0, 4);
          }
        }
      }
      _savedGameData = savedGame;
    });
  }

  void _persistCurrentSettings() {
    LocalGameStorage.saveSettings(
      playerCount: _playerCount,
      avatarsPerPlayer: _avatarsPerPlayer,
      isBotList: _isBotList,
      selectedAvatarIndices: _selectedAvatarIndices,
      playerNames: _playerNames,
    );
  }

  void _editPlayerName(int index) {
    final controller = TextEditingController(text: _playerNames[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xFF26194D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kPlayerColors[index], width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.edit_rounded, color: kPlayerColors[index]),
            const SizedBox(width: 8),
            Text(
              'Edit Player ${index + 1} Name',
              style: TextStyle(color: kPlayerColors[index], fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Enter name (e.g. Rahul, Priya)',
            hintStyle: const TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: kPlayerColors[index], width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _playerNames[index] = newName;
                });
                _persistCurrentSettings();
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPlayerColors[index],
              foregroundColor: Colors.white,
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    _persistCurrentSettings();
    final arms = getPlayerArms(_playerCount);
    final List<Player> players = [];

    for (int i = 0; i < _playerCount; i++) {
      final tokenCount = (widget.gameMode == GameMode.ludo) ? _avatarsPerPlayer : 1;
      final tokens = List.generate(
        tokenCount,
        (tIndex) => Token(id: tIndex, playerIndex: i, step: (widget.gameMode == GameMode.snakeLadder ? 1 : 0)),
      );
      players.add(
        Player(
          id: i,
          arm: arms[i],
          color: kPlayerColors[i],
          avatar: kAllAvatars[_selectedAvatarIndices[i]],
          isBot: _isBotList[i],
          customName: _playerNames[i],
          tokens: tokens,
        ),
      );
    }

    if (widget.gameMode == GameMode.ludo) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(players: players, avatarsCount: _avatarsPerPlayer),
        ),
      );
    } else if (widget.gameMode == GameMode.snakeLadder) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SnakeLadderGameScreen(players: players),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PartyRaceGameScreen(players: players),
        ),
      );
    }
  }

  void _resumeSavedGame() {
    if (_savedGameData == null) return;
    final playersData = _savedGameData!['players'] as List<dynamic>;
    final avatarsCount = (_savedGameData!['avatarsCount'] as num).toInt();
    final currentTurn = (_savedGameData!['currentPlayerIndex'] as num).toInt();
    final rankingIds = (_savedGameData!['rankings'] as List<dynamic>).map((e) => (e as num).toInt()).toList();

    final restoredPlayers = LocalGameStorage.deserializePlayers(playersData);
    final restoredRankings = rankingIds
        .map((id) => restoredPlayers.firstWhere((p) => p.id == id, orElse: () => restoredPlayers.first))
        .toList();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          players: restoredPlayers,
          avatarsCount: avatarsCount,
          initialCurrentPlayerIndex: currentTurn,
          initialRankings: restoredRankings,
        ),
      ),
    );
  }

  void _showLeaderboard() async {
    final stats = await LocalGameStorage.loadStats();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xFF26194D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text(
              'Leaderboard Stats',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: stats.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Abhi tak koi wins record nahi hue hain!\nGame khelein aur jeetein 🏆',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  children: kAllAvatars.map((av) {
                    final wins = stats[av.name] ?? 0;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: wins > 0 ? Colors.amber.withOpacity(0.5) : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(av.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Text(
                            av.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$wins Wins 🏆',
                            style: TextStyle(
                              color: wins > 0 ? Colors.amber : Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLudo = (widget.gameMode == GameMode.ludo);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF4A3580), Color(0xFF1B1238)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.amber),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
                        );
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                            ).createShader(bounds),
                            child: Text(
                              isLudo ? 'AVATAR LUDO' : 'SNAKE & LADDERS',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            isLudo ? 'Classic 4-Player Square Edition' : '100-Square Board Edition',
                            style: const TextStyle(color: Color(0xFFD1C4E9), fontSize: 11, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        SoundEffects.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: SoundEffects.soundEnabled ? Colors.amber : Colors.white38,
                        size: 26,
                      ),
                      tooltip: SoundEffects.soundEnabled ? 'Mute Sound' : 'Unmute Sound',
                      onPressed: () {
                        setState(() {
                          SoundEffects.toggleSound();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 26),
                      tooltip: 'Leaderboard Stats',
                      onPressed: _showLeaderboard,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    // Control Sliders Card
                    Card(
                      color: Colors.white.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text('Players: $_playerCount',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Expanded(
                                  child: Slider(
                                    value: _playerCount.toDouble(),
                                    min: 2,
                                    max: 4,
                                    divisions: 2,
                                    activeColor: Colors.amber,
                                    label: '$_playerCount Players',
                                    onChanged: (val) {
                                      setState(() {
                                        _playerCount = val.toInt();
                                      });
                                      _persistCurrentSettings();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (isLudo)
                              Row(
                                children: [
                                  Text('Avatars/Player: $_avatarsPerPlayer',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Expanded(
                                    child: Slider(
                                      value: _avatarsPerPlayer.toDouble(),
                                      min: 1,
                                      max: 4,
                                      divisions: 3,
                                      activeColor: Colors.amber,
                                      label: '$_avatarsPerPlayer Avatars',
                                      onChanged: (val) {
                                        setState(() {
                                          _avatarsPerPlayer = val.toInt();
                                        });
                                        _persistCurrentSettings();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Player Cards
                    ...List.generate(_playerCount, (index) {
                      final color = kPlayerColors[index];
                      final isBot = _isBotList[index];
                      final selectedAvatarIdx = _selectedAvatarIndices[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: color.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: color, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: color,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: GestureDetector(
                                      onTap: () => _editPlayerName(index),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _playerNames[index],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.edit_rounded, size: 14, color: color.withOpacity(0.8)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text('Bot', style: TextStyle(fontSize: 12)),
                                  Switch(
                                    value: isBot,
                                    activeTrackColor: color,
                                    onChanged: (val) {
                                      setState(() {
                                        _isBotList[index] = val;
                                      });
                                      _persistCurrentSettings();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 56,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: kAllAvatars.length,
                                  itemBuilder: (ctx, avIdx) {
                                    final av = kAllAvatars[avIdx];
                                    final isSelected = (selectedAvatarIdx == avIdx);
                                    final isTakenByOther = _selectedAvatarIndices
                                        .sublist(0, _playerCount)
                                        .asMap()
                                        .entries
                                        .any((e) => e.key != index && e.value == avIdx);

                                    return GestureDetector(
                                      onTap: isTakenByOther
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedAvatarIndices[index] = avIdx;
                                              });
                                              _persistCurrentSettings();
                                            },
                                      child: Opacity(
                                        opacity: isTakenByOther ? 0.35 : 1.0,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.amber.withOpacity(0.3)
                                                : Colors.black26,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected ? Colors.amber : Colors.transparent,
                                              width: isSelected ? 2.0 : 1.0,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(av.emoji, style: const TextStyle(fontSize: 20)),
                                              Text(
                                                av.name,
                                                style: const TextStyle(
                                                    fontSize: 9, color: Colors.white70),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    if (isLudo && _savedGameData != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _resumeSavedGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent[700],
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23),
                            ),
                            elevation: 6,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restore_rounded, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'RESUME SAVED GAME 🎮',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 6,
                          shadowColor: Colors.amber.withOpacity(0.5),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'START GAME',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.play_arrow_rounded, size: 26),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== LUDO GAME SCREEN WITH CORNER DICES ====================

class GameScreen extends StatefulWidget {
  final List<Player> players;
  final int avatarsCount;
  final int initialCurrentPlayerIndex;
  final List<Player> initialRankings;

  const GameScreen({
    super.key,
    required this.players,
    required this.avatarsCount,
    this.initialCurrentPlayerIndex = 0,
    this.initialRankings = const [],
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<Player> _players;
  late int _currentPlayerIndex;
  int _diceValue = 1;
  bool _isRolling = false;
  bool _hasRolled = false;
  bool _isMoving = false;
  int _consecutiveSixes = 0;
  String _statusMessage = '';
  late List<Player> _rankings;
  Token? _hoppingToken;
  Offset? _captureExplosionPos;
  Offset? _homeCelebrationPos;
  double _lastBoardSize = 360.0;

  late AnimationController _pulseController;
  late AnimationController _diceRollController;
  late AnimationController _walkHopController;

  final math.Random _random = math.Random();

  Player get _currentPlayer => _players[_currentPlayerIndex];

  @override
  void initState() {
    super.initState();
    _players = widget.players;
    _currentPlayerIndex = widget.initialCurrentPlayerIndex;
    _rankings = List.from(widget.initialRankings);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _diceRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _walkHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _statusMessage = '${_currentPlayer.name}: Dice roll karo 🎲';

    if (_currentPlayer.isBot) {
      _scheduleBotRoll();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _diceRollController.dispose();
    _walkHopController.dispose();
    super.dispose();
  }

  void _saveCurrentGame() async {
    await LocalGameStorage.saveGameState(
      players: _players,
      currentPlayerIndex: _currentPlayerIndex,
      avatarsCount: widget.avatarsCount,
      rankings: _rankings,
    );
  }

  List<Token> _getMovableTokens(Player player, int dice) {
    List<Token> valid = [];
    for (var t in player.tokens) {
      if (t.isHome) continue;
      if (t.isInYard) {
        if (dice == 6) valid.add(t);
      } else {
        if (t.step + dice <= 58) valid.add(t);
      }
    }
    return valid;
  }

  void _rollDice() async {
    if (_isRolling || _hasRolled || _isMoving) return;

    setState(() {
      _isRolling = true;
    });

    _diceRollController.forward(from: 0.0);

    final intervals = [30, 35, 35, 40, 45, 50, 60, 75, 90, 110];
    for (int i = 0; i < intervals.length; i++) {
      if (!mounted) return;
      SoundEffects.playDiceRoll();
      setState(() {
        _diceValue = _random.nextInt(6) + 1;
      });
      await Future.delayed(Duration(milliseconds: intervals[i]));
    }

    final finalDice = _random.nextInt(6) + 1;

    if (!mounted) return;
    SoundEffects.playDiceLand();

    setState(() {
      _diceValue = finalDice;
      _isRolling = false;
      _hasRolled = true;
    });

    if (finalDice == 6) {
      _consecutiveSixes++;
      if (_consecutiveSixes == 3) {
        setState(() {
          _statusMessage = '3 lagatar 6 aane par turn cancel! ❌';
          _consecutiveSixes = 0;
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) _nextTurn();
        return;
      }
    } else {
      _consecutiveSixes = 0;
    }

    final movable = _getMovableTokens(_currentPlayer, finalDice);

    if (movable.isEmpty) {
      setState(() {
        _statusMessage = 'Koi valid move nahi hai 😕';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) _nextTurn();
    } else if (movable.length == 1 || _allTokensSamePosition(movable)) {
      setState(() {
        _statusMessage = '${_currentPlayer.name}: Auto move! ⚡';
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _moveToken(movable.first);
    } else {
      setState(() {
        _statusMessage = '${_currentPlayer.name}: Apna avatar chuno 👆';
      });
      if (_currentPlayer.isBot) {
        _scheduleBotMove(movable);
      }
    }
  }

  bool _allTokensSamePosition(List<Token> tokens) {
    if (tokens.isEmpty) return true;
    final firstStep = tokens.first.step;
    return tokens.every((t) => t.step == firstStep);
  }

  void _scheduleBotRoll() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_hasRolled && !_isRolling && _currentPlayer.isBot) {
        _rollDice();
      }
    });
  }

  void _scheduleBotMove(List<Token> movable) {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      Token bestToken = movable.first;
      double maxScore = -99999;

      for (var t in movable) {
        double score = 0;
        final targetStep = (t.isInYard) ? 1 : t.step + _diceValue;

        if (targetStep == 58) {
          score += 10000;
        }

        if (targetStep >= 1 && targetStep <= 52) {
          final landRing = (_currentPlayer.arm * 13 + 5 + targetStep - 1) % 52;
          if (!isRingIndexSafe(landRing)) {
            for (var otherP in _players) {
              if (otherP.id == _currentPlayer.id) continue;
              for (var otherT in otherP.tokens) {
                if (otherT.step >= 1 && otherT.step <= 52) {
                  final enemyRing = (otherP.arm * 13 + 5 + otherT.step - 1) % 52;
                  if (enemyRing == landRing) {
                    score += 5000;
                  }
                }
              }
            }
          }
        }

        if (t.isInYard) score += 2000;
        score += targetStep * 10;

        if (score > maxScore) {
          maxScore = score;
          bestToken = t;
        }
      }

      _moveToken(bestToken);
    });
  }

  void _moveToken(Token token) async {
    if (_isMoving) return;

    setState(() {
      _isMoving = true;
    });

    final startS = token.step;
    final targetS = (startS == 0) ? 1 : startS + _diceValue;

    if (startS == 0) {
      SoundEffects.playHop();
      _walkHopController.forward(from: 0.0);
      setState(() {
        token.step = 1;
        _hoppingToken = token;
      });
      await Future.delayed(const Duration(milliseconds: 240));
    } else {
      for (int s = startS + 1; s <= targetS; s++) {
        if (!mounted) return;
        SoundEffects.playHop();
        _walkHopController.forward(from: 0.0);
        setState(() {
          token.step = s;
          _hoppingToken = token;
        });
        await Future.delayed(const Duration(milliseconds: 210));
      }
    }

    if (!mounted) return;
    setState(() {
      _hoppingToken = null;
      _isMoving = false;
    });

    bool extraTurn = false;

    // Check Home Reach
    if (token.isHome) {
      if (!mounted) return;
      SoundEffects.playHomeReach();
      final finishPos = BoardGeometry(_lastBoardSize).finishCellPos(_currentPlayer.arm);
      setState(() {
        _homeCelebrationPos = finishPos;
        _statusMessage = '${_currentPlayer.name} ki goti ghar pahunch gayi! 🏠🎉';
      });

      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _homeCelebrationPos = null;
          });
        }
      });

      if (_currentPlayer.finishedCount == widget.avatarsCount) {
        _currentPlayer.isFinished = true;
        if (!_rankings.contains(_currentPlayer)) {
          _rankings.add(_currentPlayer);
        }

        final activeCount = _players.where((p) => !p.isFinished).length;
        if (activeCount <= 1 || _rankings.length == _players.length) {
          for (var p in _players) {
            if (!p.isFinished && !_rankings.contains(p)) {
              _rankings.add(p);
            }
          }
          if (_rankings.isNotEmpty) {
            LocalGameStorage.recordWin(_rankings.first.avatar.name);
          }
          LocalGameStorage.clearSavedGame();
          SoundEffects.playVictory();
          _showGameOverDialog();
          return;
        }
      }
      extraTurn = true;
    }

    // Check Capture
    if (token.step >= 1 && token.step <= 52) {
      final landRing = (_currentPlayer.arm * 13 + 5 + token.step - 1) % 52;
      if (!isRingIndexSafe(landRing)) {
        List<Token> capturedTokens = [];
        String capturedAvatarName = '';

        for (var enemyP in _players) {
          if (enemyP.id == _currentPlayer.id) continue;
          for (var enemyT in enemyP.tokens) {
            if (enemyT.step >= 1 && enemyT.step <= 52) {
              final enemyRing = (enemyP.arm * 13 + 5 + enemyT.step - 1) % 52;
              if (enemyRing == landRing) {
                capturedTokens.add(enemyT);
                capturedAvatarName = enemyP.name;
              }
            }
          }
        }

        if (capturedTokens.isNotEmpty) {
          SoundEffects.playCapture();
          final landPos = BoardGeometry(_lastBoardSize).ringCellPos(landRing);
          setState(() {
            _captureExplosionPos = landPos;
            for (var ct in capturedTokens) {
              ct.step = 0;
            }
            _statusMessage =
                '${_currentPlayer.name} ne $capturedAvatarName ko kaat diya! 💥';
          });
          extraTurn = true;
          await Future.delayed(const Duration(milliseconds: 850));
          if (mounted) {
            setState(() {
              _captureExplosionPos = null;
            });
          }
        }
      }
    }

    if (_diceValue == 6) {
      extraTurn = true;
    }

    if (extraTurn) {
      setState(() {
        _hasRolled = false;
        _statusMessage = 'Ek aur chance! 🎉 Dice roll karo!';
      });
      if (_currentPlayer.isBot) {
        _scheduleBotRoll();
      }
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (!mounted) return;
    setState(() {
      _consecutiveSixes = 0;
      _hasRolled = false;
      _isMoving = false;

      int nextIdx = (_currentPlayerIndex + 1) % _players.length;
      int loops = 0;
      while (_players[nextIdx].isFinished && loops < _players.length) {
        nextIdx = (nextIdx + 1) % _players.length;
        loops++;
      }

      _currentPlayerIndex = nextIdx;
      _statusMessage = '${_currentPlayer.name}: Dice roll karo 🎲';
    });

    if (_currentPlayer.isBot) {
      _scheduleBotRoll();
    }
  }

  Future<bool> _confirmExit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xFF26194D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.save_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Exit Game Options',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Kya aap game progress save karke bahar aana chahte hain ya bina save kiye?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent[700],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Save & Exit 💾', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('quit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Bina Save Kiye Exit'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text('Cancel (Nahi)', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ],
      ),
    );

    if (choice == 'save') {
      _saveCurrentGame();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game progress save ho gayi! 💾'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
      );
      return true;
    } else if (choice == 'quit') {
      await LocalGameStorage.clearSavedGame();
      if (!mounted) return true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
      );
      return true;
    }
    return false;
  }

  void _showGameOverDialog() {
    SoundEffects.playVictory();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFF26194D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.amber, width: 2.5),
          ),
          title: const Column(
            children: [
              Text('🎉 🏆 🎉', style: TextStyle(fontSize: 28)),
              SizedBox(height: 4),
              Text(
                'VICTORY LEADERBOARD',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Final Player Rankings:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ..._rankings.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final p = entry.value;
                final medal = rank == 1
                    ? '🥇 1st'
                    : rank == 2
                        ? '🥈 2nd'
                        : rank == 3
                            ? '🥉 3rd'
                            : '  $rank.';
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.color.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.color, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                      const SizedBox(width: 8),
                      Text(p.avatar.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(
                              color: p.color, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('New Game', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOuterPlayerSeatWidget(Player player) {
    final isCurrent = (player.id == _currentPlayer.id);
    final canRoll = isCurrent && !_hasRolled && !player.isBot && !_isMoving;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: player.color.withOpacity(isCurrent ? 0.35 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? Colors.amber : player.color.withOpacity(0.5),
          width: isCurrent ? 2.5 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: player.color.withOpacity(0.5),
                  blurRadius: 10,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(player.avatar.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: player.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                player.isFinished ? '🏆 Done' : '${player.finishedCount}/${widget.avatarsCount} 🏠',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Player Dice Box OUTSIDE board
          GestureDetector(
            onTap: canRoll ? _rollDice : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_diceRollController, _pulseController]),
              builder: (context, child) {
                final p = _diceRollController.value;
                final rollAngle = (isCurrent && _isRolling) ? p * math.pi * 4 : 0.0;
                final bounceHeight = (isCurrent && _isRolling) ? math.sin(p * math.pi * 3).abs() * 10.0 : 0.0;
                final rollScale = (isCurrent && _isRolling)
                    ? 1.0 + math.sin(p * math.pi * 3) * 0.15
                    : (canRoll ? 1.0 + _pulseController.value * 0.12 : 1.0);

                return Transform.translate(
                  offset: Offset(0, -bounceHeight),
                  child: Transform.rotate(
                    angle: rollAngle,
                    child: Transform.scale(
                      scale: rollScale,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1B54),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canRoll ? Colors.amber : player.color,
                            width: canRoll ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (canRoll ? Colors.amber : player.color).withOpacity(canRoll ? 0.8 : 0.3),
                              blurRadius: canRoll ? 10 : 4,
                            )
                          ],
                        ),
                        child: CustomPaint(
                          painter: DicePipsPainter(_diceValue, player.color),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movableTokens = _hasRolled ? _getMovableTokens(_currentPlayer, _diceValue) : <Token>[];

    // Find active players for corner dices
    Map<int, Player> playerByArm = {for (var p in _players) p.arm: p};

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0),
              radius: 1.2,
              colors: [Color(0xFF4A3580), Color(0xFF1B1238)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top Header: Back Button + Player Chips Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.amber, size: 20),
                          tooltip: 'Back to Setup',
                          onPressed: _confirmExit,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
                        ),
                        child: IconButton(
                          icon: Icon(
                            SoundEffects.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            color: SoundEffects.soundEnabled ? Colors.amber : Colors.white38,
                            size: 20,
                          ),
                          tooltip: SoundEffects.soundEnabled ? 'Mute Sound' : 'Unmute Sound',
                          onPressed: () {
                            setState(() {
                              SoundEffects.toggleSound();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _players.length,
                            itemBuilder: (ctx, idx) {
                              final p = _players[idx];
                              final isCurrent = (idx == _currentPlayerIndex);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.color.withOpacity(isCurrent ? 0.35 : 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isCurrent ? Colors.amber : p.color,
                                    width: isCurrent ? 2.5 : 1.2,
                                  ),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: p.color.withOpacity(0.6),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  children: [
                                    Text(p.avatar.emoji, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: p.color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            p.isFinished
                                                ? '🏆 Done'
                                                : '${p.finishedCount}/${widget.avatarsCount} 🏠',
                                            maxLines: 1,
                                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Middle Section: Player Seats & Board (Dices OUTSIDE board)
                Expanded(
                  child: Column(
                    children: [
                      // TOP SEATS & DICES OUTSIDE BOARD
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (playerByArm[0] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[0]!)
                            else
                              const SizedBox.shrink(),
                            if (playerByArm[1] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[1]!)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ),

                      // CENTER BOARD CANVAS AREA (100% CLEAN INSIDE!)
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final availableHeight = constraints.maxHeight;
                              final available = math.min(availableWidth, availableHeight);
                              final boardSize = math.max(100.0, available * 0.95);
                              _lastBoardSize = boardSize;
                              final geometry = BoardGeometry(boardSize);

                              Map<String, List<Token>> positionMap = {};
                              for (var p in _players) {
                                for (var t in p.tokens) {
                                  String key = '${p.arm}_${t.step}';
                                  positionMap.putIfAbsent(key, () => []).add(t);
                                }
                              }

                              return InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 2.5,
                                clipBehavior: Clip.none,
                                child: Container(
                                  width: boardSize,
                                  height: boardSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.35),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Drawn Square 4-Arm Classic Ludo Board (Cached on GPU)
                                      RepaintBoundary(
                                        child: CustomPaint(
                                          size: Size(boardSize, boardSize),
                                          painter: FourArmBoardPainter(
                                            players: _players,
                                            geometry: geometry,
                                          ),
                                        ),
                                      ),

                                      // Render Tokens
                                      ..._players.expand((p) {
                                        return p.tokens.map((t) {
                                          String key = '${p.arm}_${t.step}';
                                          List<Token> onSameCell = positionMap[key] ?? [t];
                                          int tokenIdx = onSameCell.indexOf(t);

                                          Offset pos = geometry.getTokenPosition(
                                              p.arm, t.step, tokenIdx, onSameCell.length);

                                          bool isMovable = movableTokens.contains(t);
                                          bool isHopping = (_hoppingToken == t);

                                          final tokenDiameter = geometry.cellSize * 1.15;

                                          return AnimatedPositioned(
                                            key: ValueKey('token_${p.id}_${t.id}'),
                                            duration: const Duration(milliseconds: 210),
                                            curve: Curves.easeInOut,
                                            left: pos.dx - tokenDiameter / 2,
                                            top: pos.dy - tokenDiameter / 2,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (isMovable &&
                                                    !_isMoving &&
                                                    _hasRolled &&
                                                    _currentPlayer.id == p.id &&
                                                    !_currentPlayer.isBot) {
                                                  _moveToken(t);
                                                }
                                              },
                                              child: AnimatedBuilder(
                                                animation: Listenable.merge([_pulseController, _walkHopController]),
                                                builder: (context, child) {
                                                  double jumpArc = 0.0;
                                                  double tiltAngle = 0.0;
                                                  double scaleX = 1.0;
                                                  double scaleY = 1.0;

                                                  if (isHopping) {
                                                    final progress = _walkHopController.value;
                                                    final sineWave = math.sin(progress * math.pi);
                                                    jumpArc = sineWave * 16.0;
                                                    tiltAngle = sineWave * 0.14 * (t.step % 2 == 0 ? 1 : -1);
                                                    scaleX = 1.0 - sineWave * 0.08;
                                                    scaleY = 1.0 + sineWave * 0.14;
                                                  } else if (isMovable) {
                                                    final pulseScale = 1.0 + _pulseController.value * 0.2;
                                                    scaleX = pulseScale;
                                                    scaleY = pulseScale;
                                                  }

                                                  return Transform.translate(
                                                    offset: Offset(0, -jumpArc),
                                                    child: Transform.rotate(
                                                      angle: tiltAngle,
                                                      child: Transform.scale(
                                                        scaleX: scaleX,
                                                        scaleY: scaleY,
                                                        child: Container(
                                                          width: tokenDiameter,
                                                          height: tokenDiameter,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            gradient: RadialGradient(
                                                              colors: [Colors.white, p.color],
                                                              stops: const [0.3, 1.0],
                                                            ),
                                                            border: Border.all(
                                                              color: isMovable ? Colors.amber : p.color,
                                                              width: isMovable ? 2.5 : 1.5,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: (isMovable ? Colors.amber : p.color)
                                                                    .withOpacity(0.7),
                                                                blurRadius: isMovable ? 10 : (isHopping ? 10 : 4),
                                                                spreadRadius: isMovable ? 2 : 0,
                                                              )
                                                            ],
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              p.avatar.emoji,
                                                              style: TextStyle(
                                                                fontSize: tokenDiameter * 0.55,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        });
                                      }),

                                      // Capture Explosion Overlay
                                      if (_captureExplosionPos != null)
                                        Positioned(
                                          left: _captureExplosionPos!.dx - geometry.cellSize * 1.2,
                                          top: _captureExplosionPos!.dy - geometry.cellSize * 1.2,
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.3, end: 1.4),
                                            duration: const Duration(milliseconds: 350),
                                            curve: Curves.elasticOut,
                                            builder: (context, scale, child) {
                                              return Transform.scale(
                                                scale: scale,
                                                child: SizedBox(
                                                  width: geometry.cellSize * 2.4,
                                                  height: geometry.cellSize * 2.4,
                                                  child: const Center(
                                                    child: Text('💥', style: TextStyle(fontSize: 30)),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                      // Home Celebration Overlay
                                      if (_homeCelebrationPos != null)
                                        Positioned(
                                          left: _homeCelebrationPos!.dx - geometry.cellSize * 1.5,
                                          top: _homeCelebrationPos!.dy - geometry.cellSize * 1.5,
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.3, end: 1.5),
                                            duration: const Duration(milliseconds: 450),
                                            curve: Curves.elasticOut,
                                            builder: (context, scale, child) {
                                              return Transform.scale(
                                                scale: scale,
                                                child: SizedBox(
                                                  width: geometry.cellSize * 3.0,
                                                  height: geometry.cellSize * 3.0,
                                                  child: const Center(
                                                    child: Text('🏠🎉', style: TextStyle(fontSize: 32)),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // BOTTOM SEATS & DICES OUTSIDE BOARD
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (playerByArm[3] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[3]!)
                            else
                              const SizedBox.shrink(),
                            if (playerByArm[2] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[2]!)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Panel (Status Bar)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(
                      top: BorderSide(color: Colors.amber.withOpacity(0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPlayer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _currentPlayer.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _statusMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== SNAKE & LADDERS GAME SCREEN ====================

class SnakeLadderGameScreen extends StatefulWidget {
  final List<Player> players;

  const SnakeLadderGameScreen({
    super.key,
    required this.players,
  });

  @override
  State<SnakeLadderGameScreen> createState() => _SnakeLadderGameScreenState();
}

class _SnakeLadderGameScreenState extends State<SnakeLadderGameScreen> with TickerProviderStateMixin {
  late List<Player> _players;
  int _currentPlayerIndex = 0;
  int _diceValue = 1;
  bool _isRolling = false;
  bool _hasRolled = false;
  bool _isMoving = false;
  String _statusMessage = '';
  final List<Player> _rankings = [];
  Token? _hoppingToken;

  late AnimationController _pulseController;
  late AnimationController _diceRollController;
  late AnimationController _walkHopController;

  final math.Random _random = math.Random();

  Player get _currentPlayer => _players[_currentPlayerIndex];

  @override
  void initState() {
    super.initState();
    _players = widget.players;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _diceRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _walkHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _statusMessage = '${_currentPlayer.name}: Dice roll karo 🎲';

    if (_currentPlayer.isBot) {
      _scheduleBotRoll();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _diceRollController.dispose();
    _walkHopController.dispose();
    super.dispose();
  }

  void _scheduleBotRoll() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_hasRolled && !_isRolling && _currentPlayer.isBot) {
        _rollDice();
      }
    });
  }

  void _rollDice() async {
    if (_isRolling || _hasRolled || _isMoving) return;

    setState(() {
      _isRolling = true;
    });

    _diceRollController.forward(from: 0.0);

    final intervals = [30, 35, 35, 40, 45, 50, 60, 75, 90, 110];
    for (int i = 0; i < intervals.length; i++) {
      if (!mounted) return;
      SoundEffects.playDiceRoll();
      setState(() {
        _diceValue = _random.nextInt(6) + 1;
      });
      await Future.delayed(Duration(milliseconds: intervals[i]));
    }

    final finalDice = _random.nextInt(6) + 1;

    if (!mounted) return;
    SoundEffects.playDiceLand();

    setState(() {
      _diceValue = finalDice;
      _isRolling = false;
      _hasRolled = true;
    });

    _movePlayerToken();
  }

  void _movePlayerToken() async {
    setState(() {
      _isMoving = true;
    });

    final token = _currentPlayer.tokens.first;
    final currentS = token.step;
    final targetS = currentS + _diceValue;

    if (targetS > 100) {
      setState(() {
        _statusMessage = 'Exact number chahiye 100 tak pahunche ke liye! 😕';
        _isMoving = false;
      });
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _nextTurn();
      return;
    }

    for (int s = currentS + 1; s <= targetS; s++) {
      if (!mounted) return;
      SoundEffects.playHop();
      _walkHopController.forward(from: 0.0);
      setState(() {
        token.step = s;
        _hoppingToken = token;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    setState(() {
      _hoppingToken = null;
    });

    // Check Ladder
    if (kLaddersMap.containsKey(token.step)) {
      final ladderTop = kLaddersMap[token.step]!;
      SoundEffects.playHomeReach();
      setState(() {
        _statusMessage = '${_currentPlayer.name} climbed ladder to $ladderTop! 🪜🎉';
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        token.step = ladderTop;
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }
    // Check Snake
    else if (kSnakesMap.containsKey(token.step)) {
      final snakeTail = kSnakesMap[token.step]!;
      SoundEffects.playSnakeBite();
      setState(() {
        _statusMessage = '${_currentPlayer.name} ko saamp ne kaat liya! Down to $snakeTail 🐍💥';
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        token.step = snakeTail;
      });
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;
    setState(() {
      _isMoving = false;
    });

    // Check Win
    if (token.step == 100) {
      _currentPlayer.isFinished = true;
      if (!_rankings.contains(_currentPlayer)) {
        _rankings.add(_currentPlayer);
      }
      LocalGameStorage.recordWin(_currentPlayer.avatar.name);
      SoundEffects.playVictory();
      _showGameOverDialog();
      return;
    }

    if (_diceValue == 6) {
      setState(() {
        _hasRolled = false;
        _statusMessage = '6 aaya! 🎉 Ek aur chance!';
      });
      if (_currentPlayer.isBot) {
        _scheduleBotRoll();
      }
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (!mounted) return;
    setState(() {
      _hasRolled = false;
      _isMoving = false;

      int nextIdx = (_currentPlayerIndex + 1) % _players.length;
      int loops = 0;
      while (_players[nextIdx].isFinished && loops < _players.length) {
        nextIdx = (nextIdx + 1) % _players.length;
        loops++;
      }

      _currentPlayerIndex = nextIdx;
      _statusMessage = '${_currentPlayer.name}: Dice roll karo 🎲';
    });

    if (_currentPlayer.isBot) {
      _scheduleBotRoll();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFF26194D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.tealAccent, width: 2.5),
          ),
          title: const Column(
            children: [
              Text('🐍 🏆 🪜', style: TextStyle(fontSize: 28)),
              SizedBox(height: 4),
              Text(
                'SNAKE & LADDERS WINNER!',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.tealAccent,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🥇 ${_currentPlayer.name} Won the Game! 🏆',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent[700],
                foregroundColor: Colors.black,
              ),
              child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOuterPlayerSeatWidget(Player player) {
    final isCurrent = (player.id == _currentPlayer.id);
    final canRoll = isCurrent && !_hasRolled && !player.isBot && !_isMoving;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: player.color.withOpacity(isCurrent ? 0.35 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? Colors.tealAccent : player.color.withOpacity(0.5),
          width: isCurrent ? 2.5 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: player.color.withOpacity(0.5),
                  blurRadius: 10,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(player.avatar.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: player.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Square ${player.tokens.first.step}',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Player Dice Box OUTSIDE board
          GestureDetector(
            onTap: canRoll ? _rollDice : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_diceRollController, _pulseController]),
              builder: (context, child) {
                final p = _diceRollController.value;
                final rollAngle = (isCurrent && _isRolling) ? p * math.pi * 4 : 0.0;
                final bounceHeight = (isCurrent && _isRolling) ? math.sin(p * math.pi * 3).abs() * 10.0 : 0.0;
                final rollScale = (isCurrent && _isRolling)
                    ? 1.0 + math.sin(p * math.pi * 3) * 0.15
                    : (canRoll ? 1.0 + _pulseController.value * 0.12 : 1.0);

                return Transform.translate(
                  offset: Offset(0, -bounceHeight),
                  child: Transform.rotate(
                    angle: rollAngle,
                    child: Transform.scale(
                      scale: rollScale,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B382B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canRoll ? Colors.tealAccent : player.color,
                            width: canRoll ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (canRoll ? Colors.tealAccent : player.color).withOpacity(canRoll ? 0.8 : 0.3),
                              blurRadius: canRoll ? 10 : 4,
                            )
                          ],
                        ),
                        child: CustomPaint(
                          painter: DicePipsPainter(_diceValue, player.color),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<int, Player> playerByArm = {for (var p in _players) p.arm: p};

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0),
            radius: 1.2,
            colors: [Color(0xFF004D40), Color(0xFF1B1238)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.tealAccent),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
                        );
                      },
                    ),
                    Expanded(
                      child: Text(
                        'SNAKE & LADDERS 🐍🪜',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        SoundEffects.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: SoundEffects.soundEnabled ? Colors.tealAccent : Colors.white38,
                        size: 26,
                      ),
                      tooltip: SoundEffects.soundEnabled ? 'Mute Sound' : 'Unmute Sound',
                      onPressed: () {
                        setState(() {
                          SoundEffects.toggleSound();
                        });
                      },
                    ),
                  ],
                ),
              ),

                // Middle Section: Player Seats & Board (Dices OUTSIDE board)
                Expanded(
                  child: Column(
                    children: [
                      // TOP SEATS & DICES OUTSIDE BOARD
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (playerByArm[0] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[0]!)
                            else
                              const SizedBox.shrink(),
                            if (playerByArm[1] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[1]!)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ),

                      // CENTER BOARD CANVAS AREA (100% CLEAN INSIDE!)
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              final availableHeight = constraints.maxHeight;
                              final available = math.min(availableWidth, availableHeight);
                              final boardSize = math.max(100.0, available * 0.95);

                              return InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 2.5,
                                clipBehavior: Clip.none,
                                child: Container(
                                  width: boardSize,
                                  height: boardSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.tealAccent, width: 3.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.tealAccent.withOpacity(0.3),
                                        blurRadius: 16,
                                      )
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Drawn Snake & Ladder Board (Cached on GPU)
                                      RepaintBoundary(
                                        child: CustomPaint(
                                          size: Size(boardSize, boardSize),
                                          painter: SnakeBoardPainter(boardSize: boardSize),
                                        ),
                                      ),

                                      // Render Player Tokens
                                      ..._players.map((p) {
                                        final t = p.tokens.first;
                                        final pos = getSnakeSquarePos(t.step, boardSize);
                                        final tokenDiameter = boardSize / 10 * 0.75;
                                        final isHopping = (_hoppingToken == t);

                                        return AnimatedPositioned(
                                          key: ValueKey('snake_token_${p.id}'),
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeInOut,
                                          left: pos.dx - tokenDiameter / 2,
                                          top: pos.dy - tokenDiameter / 2,
                                          child: AnimatedBuilder(
                                            animation: _walkHopController,
                                            builder: (context, child) {
                                              final progress = _walkHopController.value;
                                              final sineWave = math.sin(progress * math.pi);
                                              final jumpArc = isHopping ? sineWave * 12.0 : 0.0;

                                              return Transform.translate(
                                                offset: Offset(0, -jumpArc),
                                                child: Container(
                                                  width: tokenDiameter,
                                                  height: tokenDiameter,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: RadialGradient(
                                                      colors: [Colors.white, p.color],
                                                      stops: const [0.3, 1.0],
                                                    ),
                                                    border: Border.all(color: Colors.white, width: 2.0),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: p.color.withOpacity(0.8),
                                                        blurRadius: 8,
                                                      )
                                                    ],
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      p.avatar.emoji,
                                                      style: TextStyle(fontSize: tokenDiameter * 0.55),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // BOTTOM SEATS & DICES OUTSIDE BOARD
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (playerByArm[3] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[3]!)
                            else
                              const SizedBox.shrink(),
                            if (playerByArm[2] != null)
                              _buildOuterPlayerSeatWidget(playerByArm[2]!)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom Panel (Status)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Colors.tealAccent.withOpacity(0.4))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPlayer.name,
                            style: TextStyle(color: _currentPlayer.color, fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== FUNNY PARTY RACE GAME SCREEN ====================

Offset getPartySquarePos(int square, double boardSize) {
  if (square < 1) square = 1;
  if (square > 40) square = 40;

  final center = Offset(boardSize / 2, boardSize / 2);
  if (square == 40) return center;

  final index = square - 1;
  final radius = (boardSize * 0.42) - (index / 39.0) * (boardSize * 0.28);
  final angle = index * (math.pi * 0.32);

  return Offset(
    center.dx + radius * math.cos(angle),
    center.dy + radius * math.sin(angle),
  );
}

class PartyRaceGameScreen extends StatefulWidget {
  final List<Player> players;

  const PartyRaceGameScreen({
    super.key,
    required this.players,
  });

  @override
  State<PartyRaceGameScreen> createState() => _PartyRaceGameScreenState();
}

class _PartyRaceGameScreenState extends State<PartyRaceGameScreen> with TickerProviderStateMixin {
  late List<Player> _players;
  int _currentPlayerIndex = 0;
  int _diceValue = 1;
  bool _isRolling = false;
  bool _hasRolled = false;
  bool _isMoving = false;
  String _statusMessage = '';
  final List<Player> _rankings = [];
  Token? _hoppingToken;

  late AnimationController _pulseController;
  late AnimationController _diceRollController;
  late AnimationController _walkHopController;

  final math.Random _random = math.Random();

  Player get _currentPlayer => _players[_currentPlayerIndex];

  @override
  void initState() {
    super.initState();
    _players = widget.players;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _diceRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _walkHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _statusMessage = '${_currentPlayer.name}: Funny Dice roll karo 🎲';

    if (_currentPlayer.isBot) {
      _scheduleBotRoll();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _diceRollController.dispose();
    _walkHopController.dispose();
    super.dispose();
  }

  void _scheduleBotRoll() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_hasRolled && !_isRolling && _currentPlayer.isBot) {
        _rollDice();
      }
    });
  }

  void _rollDice() async {
    if (_isRolling || _hasRolled || _isMoving) return;

    setState(() {
      _isRolling = true;
    });

    _diceRollController.forward(from: 0.0);

    final intervals = [30, 35, 35, 40, 45, 50, 60, 75, 90, 110];
    for (int i = 0; i < intervals.length; i++) {
      if (!mounted) return;
      SoundEffects.playDiceRoll();
      setState(() {
        _diceValue = _random.nextInt(6) + 1;
      });
      await Future.delayed(Duration(milliseconds: intervals[i]));
    }

    final finalDice = _random.nextInt(6) + 1;

    if (!mounted) return;
    SoundEffects.playDiceLand();

    setState(() {
      _diceValue = finalDice;
      _isRolling = false;
      _hasRolled = true;
    });

    _movePlayerToken();
  }

  void _movePlayerToken() async {
    setState(() {
      _isMoving = true;
    });

    final token = _currentPlayer.tokens.first;
    final currentS = token.step;
    final targetS = currentS + _diceValue;

    if (targetS > 40) {
      setState(() {
        _statusMessage = 'Exact number chahiye Party Castle 🏰 pahunche ke liye!';
        _isMoving = false;
      });
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) _nextTurn();
      return;
    }

    for (int s = currentS + 1; s <= targetS; s++) {
      if (!mounted) return;
      SoundEffects.playHop();
      _walkHopController.forward(from: 0.0);
      setState(() {
        token.step = s;
        _hoppingToken = token;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    setState(() {
      _hoppingToken = null;
    });

    // Check Funny Action Cells
    bool extraTurn = false;
    final step = token.step;

    if (step == 5 || step == 18 || step == 31) {
      // Banana Peel Slip (-3)
      SoundEffects.playSlip();
      setState(() {
        _statusMessage = '${_currentPlayer.name}kele ke chilke par phisal gaya! Slid back 3 steps! 🍌😂';
      });
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        token.step = (token.step - 3).clamp(1, 40);
      });
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (step == 8 || step == 22 || step == 34) {
      // Rocket Boost (+5)
      SoundEffects.playRocket();
      setState(() {
        _statusMessage = '${_currentPlayer.name} rocket launch ho gaya! +5 steps forward! 🚀🔥';
      });
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        token.step = (token.step + 5).clamp(1, 40);
      });
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (step == 15 || step == 29) {
      // Mystery Gift (Free Extra Roll)
      SoundEffects.playHomeReach();
      setState(() {
        _statusMessage = '${_currentPlayer.name} ko jaadui gift mila! Free extra roll! 🎁✨';
      });
      extraTurn = true;
      await Future.delayed(const Duration(milliseconds: 600));
    } else if (step == 24 || step == 37) {
      // Slap Knockout (Slaps enemy back)
      SoundEffects.playSlap();
      for (var enemyP in _players) {
        if (enemyP.id == _currentPlayer.id) continue;
        enemyP.tokens.first.step = 1;
      }
      setState(() {
        _statusMessage = '${_currentPlayer.name} ne sabko thappad maar kar start par bhej diya! 🥊💥';
      });
      await Future.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted) return;
    setState(() {
      _isMoving = false;
    });

    // Check Win
    if (token.step == 40) {
      _currentPlayer.isFinished = true;
      if (!_rankings.contains(_currentPlayer)) {
        _rankings.add(_currentPlayer);
      }
      LocalGameStorage.recordWin(_currentPlayer.avatar.name);
      SoundEffects.playVictory();
      _showGameOverDialog();
      return;
    }

    if (_diceValue == 6 || extraTurn) {
      setState(() {
        _hasRolled = false;
        _statusMessage = 'Awesome! 🎉 Ek aur chance! Dice roll karo!';
      });
      if (_currentPlayer.isBot) {
        _scheduleBotRoll();
      }
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (!mounted) return;
    setState(() {
      _hasRolled = false;
      _isMoving = false;

      int nextIdx = (_currentPlayerIndex + 1) % _players.length;
      int loops = 0;
      while (_players[nextIdx].isFinished && loops < _players.length) {
        nextIdx = (nextIdx + 1) % _players.length;
        loops++;
      }

      _currentPlayerIndex = nextIdx;
      _statusMessage = '${_currentPlayer.name}: Funny Dice roll karo 🎲';
    });

    if (_currentPlayer.isBot) {
      _scheduleBotRoll();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFF26194D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.orangeAccent, width: 2.5),
          ),
          title: const Column(
            children: [
              Text('🏰 🏆 🤪', style: TextStyle(fontSize: 28)),
              SizedBox(height: 4),
              Text(
                'PARTY KINGDOM WINNER!',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.orangeAccent,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🥇 ${_currentPlayer.name} Conquered the Party Castle! 🏰👑',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOuterPlayerSeatWidget(Player player) {
    final isCurrent = (player.id == _currentPlayer.id);
    final canRoll = isCurrent && !_hasRolled && !player.isBot && !_isMoving;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: player.color.withOpacity(isCurrent ? 0.35 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? Colors.orangeAccent : player.color.withOpacity(0.5),
          width: isCurrent ? 2.5 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: player.color.withOpacity(0.5),
                  blurRadius: 10,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(player.avatar.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: player.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Tile ${player.tokens.first.step}/40',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canRoll ? _rollDice : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_diceRollController, _pulseController]),
              builder: (context, child) {
                final p = _diceRollController.value;
                final rollAngle = (isCurrent && _isRolling) ? p * math.pi * 4 : 0.0;
                final bounceHeight = (isCurrent && _isRolling) ? math.sin(p * math.pi * 3).abs() * 10.0 : 0.0;
                final rollScale = (isCurrent && _isRolling)
                    ? 1.0 + math.sin(p * math.pi * 3) * 0.15
                    : (canRoll ? 1.0 + _pulseController.value * 0.12 : 1.0);

                return Transform.translate(
                  offset: Offset(0, -bounceHeight),
                  child: Transform.rotate(
                    angle: rollAngle,
                    child: Transform.scale(
                      scale: rollScale,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E1B00),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canRoll ? Colors.orangeAccent : player.color,
                            width: canRoll ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (canRoll ? Colors.orangeAccent : player.color).withOpacity(canRoll ? 0.8 : 0.3),
                              blurRadius: canRoll ? 10 : 4,
                            )
                          ],
                        ),
                        child: CustomPaint(
                          painter: DicePipsPainter(_diceValue, player.color),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<int, Player> playerByArm = {for (var p in _players) p.arm: p};

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 0),
            radius: 1.2,
            colors: [Color(0xFFBF360C), Color(0xFF1B1238)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.orangeAccent),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const GameModeSelectionScreen()),
                        );
                      },
                    ),
                    Expanded(
                      child: Text(
                        'FUNNY PARTY RACE 🤪🎉',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        SoundEffects.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: SoundEffects.soundEnabled ? Colors.orangeAccent : Colors.white38,
                        size: 26,
                      ),
                      tooltip: SoundEffects.soundEnabled ? 'Mute Sound' : 'Unmute Sound',
                      onPressed: () {
                        setState(() {
                          SoundEffects.toggleSound();
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Middle Section: Player Seats & Board
              Expanded(
                child: Column(
                  children: [
                    // TOP SEATS & DICES OUTSIDE BOARD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (playerByArm[0] != null)
                            _buildOuterPlayerSeatWidget(playerByArm[0]!)
                          else
                            const SizedBox.shrink(),
                          if (playerByArm[1] != null)
                            _buildOuterPlayerSeatWidget(playerByArm[1]!)
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),

                    // CENTER PARTY RACE SPIRAL BOARD CANVAS
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableWidth = constraints.maxWidth;
                            final availableHeight = constraints.maxHeight;
                            final available = math.min(availableWidth, availableHeight);
                            final boardSize = math.max(100.0, available * 0.95);

                            return InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 2.5,
                              clipBehavior: Clip.none,
                              child: Container(
                                width: boardSize,
                                height: boardSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orangeAccent, width: 3.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orangeAccent.withOpacity(0.35),
                                      blurRadius: 18,
                                    )
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Drawn Party Spiral Track Board (Cached on GPU)
                                    RepaintBoundary(
                                      child: CustomPaint(
                                        size: Size(boardSize, boardSize),
                                        painter: PartyBoardPainter(boardSize: boardSize),
                                      ),
                                    ),

                                    // Render Player Tokens
                                    ..._players.map((p) {
                                      final t = p.tokens.first;
                                      final pos = getPartySquarePos(t.step, boardSize);
                                      final tokenDiameter = boardSize * 0.085;
                                      final isHopping = (_hoppingToken == t);

                                      return AnimatedPositioned(
                                        key: ValueKey('party_token_${p.id}'),
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        left: pos.dx - tokenDiameter / 2,
                                        top: pos.dy - tokenDiameter / 2,
                                        child: AnimatedBuilder(
                                          animation: _walkHopController,
                                          builder: (context, child) {
                                            final progress = _walkHopController.value;
                                            final sineWave = math.sin(progress * math.pi);
                                            final jumpArc = isHopping ? sineWave * 14.0 : 0.0;

                                            return Transform.translate(
                                              offset: Offset(0, -jumpArc),
                                              child: Container(
                                                width: tokenDiameter,
                                                height: tokenDiameter,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: RadialGradient(
                                                    colors: [Colors.white, p.color],
                                                    stops: const [0.3, 1.0],
                                                  ),
                                                  border: Border.all(color: Colors.white, width: 2.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: p.color.withOpacity(0.8),
                                                      blurRadius: 8,
                                                    )
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    p.avatar.emoji,
                                                    style: TextStyle(fontSize: tokenDiameter * 0.55),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // BOTTOM SEATS & DICES OUTSIDE BOARD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (playerByArm[3] != null)
                            _buildOuterPlayerSeatWidget(playerByArm[3]!)
                          else
                            const SizedBox.shrink(),
                          if (playerByArm[2] != null)
                            _buildOuterPlayerSeatWidget(playerByArm[2]!)
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Panel (Status)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Colors.orangeAccent.withOpacity(0.4))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPlayer.name,
                            style: TextStyle(color: _currentPlayer.color, fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PARTY BOARD PAINTER ====================

class PartyBoardPainter extends CustomPainter {
  final double boardSize;

  PartyBoardPainter({required this.boardSize});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF2A0800));

    // 2. Draw Spiral Track Line
    final path = Path();
    for (int square = 1; square <= 40; square++) {
      final pos = getPartySquarePos(square, size.width);
      if (square == 1) {
        path.moveTo(pos.dx, pos.dy);
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.orangeAccent.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // 3. Draw 40 Spiral Tiles
    for (int square = 1; square <= 40; square++) {
      final pos = getPartySquarePos(square, size.width);
      final tileR = size.width * 0.038;

      Color bg = const Color(0xFFD84315);
      String emoji = '$square';

      if (square == 5 || square == 18 || square == 31) {
        bg = Colors.amber[800]!;
        emoji = '🍌';
      } else if (square == 8 || square == 22 || square == 34) {
        bg = Colors.deepOrangeAccent;
        emoji = '🚀';
      } else if (square == 12 || square == 27) {
        bg = Colors.purpleAccent[700]!;
        emoji = '💃';
      } else if (square == 15 || square == 29) {
        bg = Colors.teal;
        emoji = '🎁';
      } else if (square == 24 || square == 37) {
        bg = Colors.redAccent[700]!;
        emoji = '🥊';
      } else if (square == 40) {
        bg = Colors.amber;
        emoji = '🏰';
      }

      canvas.drawCircle(pos, tileR + 1.2, Paint()..color = Colors.white);
      canvas.drawCircle(pos, tileR, Paint()..color = bg);

      TextPainter tp = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(
            color: Colors.white,
            fontSize: (emoji.length > 2 || square == 40) ? 14 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant PartyBoardPainter oldDelegate) => false;
}

// ==================== SNAKE & LADDERS BOARD PAINTER ====================

class SnakeBoardPainter extends CustomPainter {
  final double boardSize;

  SnakeBoardPainter({required this.boardSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 10;

    // 1. Draw 10x10 Grid Squares
    for (int square = 1; square <= 100; square++) {
      final pos = getSnakeSquarePos(square, size.width);
      final rect = Rect.fromCenter(center: pos, width: cellSize, height: cellSize);

      final isEvenSquare = (square % 2 == 0);
      final bg = isEvenSquare ? const Color(0xFF004D40) : const Color(0xFF00695C);

      canvas.drawRect(rect, Paint()..color = bg);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.tealAccent.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Square Number
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '$square',
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, rect.topLeft + const Offset(3, 3));
    }

    // 2. Draw Real Golden Wooden Ladders 🪜
    kLaddersMap.forEach((bottom, top) {
      final p1 = getSnakeSquarePos(bottom, size.width);
      final p2 = getSnakeSquarePos(top, size.width);

      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len <= 0) return;

      final nx = -dy / len;
      final ny = dx / len;
      final railWidth = cellSize * 0.22;
      final offset = Offset(nx * railWidth, ny * railWidth);

      final rail1Start = p1 + offset;
      final rail1End = p2 + offset;
      final rail2Start = p1 - offset;
      final rail2End = p2 - offset;

      final railPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      // Draw Rail 1 and Rail 2
      canvas.drawLine(rail1Start, rail1End, railPaint);
      canvas.drawLine(rail2Start, rail2End, railPaint);

      // Draw Rungs along the length
      final numRungs = (len / (cellSize * 0.35)).clamp(4, 10).toInt();
      final rungPaint = Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 1; i <= numRungs; i++) {
        final t = i / (numRungs + 1);
        final r1 = Offset(rail1Start.dx + (rail1End.dx - rail1Start.dx) * t,
            rail1Start.dy + (rail1End.dy - rail1Start.dy) * t);
        final r2 = Offset(rail2Start.dx + (rail2End.dx - rail2Start.dx) * t,
            rail2Start.dy + (rail2End.dy - rail2Start.dy) * t);
        canvas.drawLine(r1, r2, rungPaint);
      }
    });

    // 3. Draw Full Serpentine Snake Bodies 🐍 (Head, Curvy Body, Skin Pattern, Eyes, Tongue, Tail)
    final snakeColors = [
      const Color(0xFFE53935), // Crimson Red
      const Color(0xFFFB8C00), // Orange
      const Color(0xFF8E24AA), // Purple
      const Color(0xFFD81B60), // Magenta
      const Color(0xFF43A047), // Green
      const Color(0xFF00ACC1), // Cyan
    ];

    int snakeIndex = 0;
    kSnakesMap.forEach((head, tail) {
      final p1 = getSnakeSquarePos(head, size.width); // Head position
      final p2 = getSnakeSquarePos(tail, size.width); // Tail position

      final color = snakeColors[snakeIndex % snakeColors.length];
      snakeIndex++;

      // Build Wiggling S-Curve Snake Body Path
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      final perpX = -dy / (len > 0 ? len : 1);
      final perpY = dx / (len > 0 ? len : 1);

      final curveAmp = cellSize * 0.55;
      final cp1 = Offset((p1.dx * 2 + p2.dx) / 3 + perpX * curveAmp,
          (p1.dy * 2 + p2.dy) / 3 + perpY * curveAmp);
      final cp2 = Offset((p1.dx + p2.dx * 2) / 3 - perpX * curveAmp,
          (p1.dy + p2.dy * 2) / 3 - perpY * curveAmp);

      final snakePath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

      // 3a. Dark Outer Shadow / Outline
      canvas.drawPath(
        snakePath,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9.5
          ..strokeCap = StrokeCap.round,
      );

      // 3b. Thick Snake Body Skin
      canvas.drawPath(
        snakePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7.0
          ..strokeCap = StrokeCap.round,
      );

      // 3c. Yellow Scale Spots along body
      final spotPaint = Paint()..color = Colors.yellowAccent;
      for (double t = 0.2; t <= 0.8; t += 0.2) {
        final spotX = math.pow(1 - t, 3) * p1.dx +
            3 * math.pow(1 - t, 2) * t * cp1.dx +
            3 * (1 - t) * math.pow(t, 2) * cp2.dx +
            math.pow(t, 3) * p2.dx;
        final spotY = math.pow(1 - t, 3) * p1.dy +
            3 * math.pow(1 - t, 2) * t * cp1.dy +
            3 * (1 - t) * math.pow(t, 2) * cp2.dy +
            math.pow(t, 3) * p2.dy;
        canvas.drawCircle(Offset(spotX, spotY), 2.2, spotPaint);
      }

      // 3d. Draw Snake Head at p1
      final headRadius = cellSize * 0.28;
      canvas.drawCircle(p1, headRadius + 1.2, Paint()..color = Colors.black);
      canvas.drawCircle(p1, headRadius, Paint()..color = color);

      // Snake Eyes (White + Black Pupil)
      final eyeOffset = Offset(headRadius * 0.35, -headRadius * 0.35);
      final leftEye = p1 - eyeOffset;
      final rightEye = p1 + Offset(eyeOffset.dx, -eyeOffset.dy);

      canvas.drawCircle(leftEye, 3.2, Paint()..color = Colors.white);
      canvas.drawCircle(rightEye, 3.2, Paint()..color = Colors.white);
      canvas.drawCircle(leftEye, 1.5, Paint()..color = Colors.black);
      canvas.drawCircle(rightEye, 1.5, Paint()..color = Colors.black);

      // Snake Tongue (Red)
      final tongueAngle = math.atan2(cp1.dy - p1.dy, cp1.dx - p1.dx);
      final tongueStart = Offset(
        p1.dx + headRadius * math.cos(tongueAngle),
        p1.dy + headRadius * math.sin(tongueAngle),
      );
      final tongueEnd = Offset(
        tongueStart.dx + 8 * math.cos(tongueAngle),
        tongueStart.dy + 8 * math.sin(tongueAngle),
      );
      canvas.drawLine(
        tongueStart,
        tongueEnd,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2.0,
      );
    });
  }

  @override
  bool shouldRepaint(covariant SnakeBoardPainter oldDelegate) => false;
}

// ==================== 4-PLAYER SQUARE CLASSIC BOARD PAINTER ====================

class FourArmBoardPainter extends CustomPainter {
  final List<Player> players;
  final BoardGeometry geometry;

  FourArmBoardPainter({
    required this.players,
    required this.geometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = geometry.center;
    final centerR = geometry.centerRadius;
    final cellS = geometry.cellSize;

    // 1. Square Board Container Outer Border & Background
    final boardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    final bgPaint = Paint()
      ..color = const Color(0xFF231647)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(boardRRect, bgPaint);

    final outerBorderPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(boardRRect, outerBorderPaint);

    Map<int, Player> playerByArm = {for (var p in players) p.arm: p};

    // 2. Draw 4 Arms
    for (int arm = 0; arm < 4; arm++) {
      final player = playerByArm[arm];
      final armColor = player?.color ?? kPlayerColors[arm % kPlayerColors.length];

      // Draw Cells for this arm (3 lanes x 6 rows)
      for (int row = 1; row <= 6; row++) {
        for (int lane = -1; lane <= 1; lane++) {
          final pos = geometry.cellPos(arm, lane, row);

          Color cellBg = const Color(0xFFEDE7FF);
          bool isStartCell = false;
          bool isStarCell = false;

          if (lane == 0) {
            // Home Column (Rows 1..5) or Tip (Row 6)
            if (row <= 5) {
              cellBg = armColor.withOpacity(0.85);
            } else {
              cellBg = const Color(0xFFEDE7FF);
            }
          } else if (lane == -1 && row == 6) {
            // Outermost Arrow Start Cell
            cellBg = armColor;
            isStartCell = true;
          } else if ((lane == 1 && row == 4) || (lane == -1 && row == 3)) {
            // Safe Discs Stamps
            cellBg = const Color(0xFFEDE7FF);
            isStarCell = true;
          }

          final cellRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: cellS * 0.94, height: cellS * 0.94),
            const Radius.circular(4),
          );

          canvas.drawRRect(cellRect, Paint()..color = cellBg);
          canvas.drawRRect(
            cellRect,
            Paint()
              ..color = Colors.black45
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );

          if (lane == 0 && row <= 5) {
            // Home Column Accent
            canvas.drawRRect(
              cellRect.deflate(1.5),
              Paint()
                ..color = Colors.white30
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
            if (row == 5) {
              TextPainter tp = TextPainter(
                text: const TextSpan(
                  text: '▲',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textDirection: TextDirection.ltr,
              );
              tp.layout();
              tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
            }
          }

          if (isStartCell) {
            canvas.drawRRect(
              cellRect.deflate(2.0),
              Paint()
                ..color = Colors.white
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8,
            );
            canvas.drawCircle(pos, cellS * 0.36, Paint()..color = Colors.white);
            TextPainter tp = TextPainter(
              text: TextSpan(
                text: '➔',
                style: TextStyle(
                  color: armColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            tp.layout();
            tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
          } else if (isStarCell) {
            canvas.drawCircle(
              pos,
              cellS * 0.38,
              Paint()..color = const Color(0xFF1B1238),
            );
            canvas.drawCircle(
              pos,
              cellS * 0.38,
              Paint()
                ..color = Colors.white70
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
            TextPainter tp = TextPainter(
              text: const TextSpan(
                text: '●',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            tp.layout();
            tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
          }
        }
      }

      // 3. Draw Corner Yard Container for Arm a
      final yardCenter = geometry.yardCenterPos(arm);

      final startPos = geometry.cellPos(arm, -1, 6);
      final pathLinePaint = Paint()
        ..color = armColor.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(yardCenter, startPos, pathLinePaint);

      final yardRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: yardCenter, width: cellS * 3.2, height: cellS * 3.2),
        const Radius.circular(16),
      );

      canvas.drawRRect(yardRRect, Paint()..color = armColor.withOpacity(0.25));
      canvas.drawRRect(
        yardRRect,
        Paint()
          ..color = armColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Draw Avatar Badge on Yard if player active
      if (player != null) {
        final badgePos = Offset(yardCenter.dx, yardCenter.dy - cellS * 1.75);
        canvas.drawCircle(badgePos, cellS * 0.5, Paint()..color = armColor);
        canvas.drawCircle(
          badgePos,
          cellS * 0.5,
          Paint()
            ..color = Colors.white70
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: player.avatar.emoji,
            style: TextStyle(fontSize: cellS * 0.55),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, badgePos - Offset(tp.width / 2, tp.height / 2));
      }

      // Draw 4 Dark Slots in Yard
      for (int slot = 0; slot < 4; slot++) {
        final slotPos = geometry.yardSlotPos(arm, slot);
        canvas.drawCircle(slotPos, cellS * 0.45, Paint()..color = Colors.black45);
        canvas.drawCircle(
          slotPos,
          cellS * 0.45,
          Paint()
            ..color = Colors.white24
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    // 4. Center Square Home Area
    final Rect centerSquare = Rect.fromCenter(center: center, width: centerR * 2, height: centerR * 2);
    canvas.drawRect(centerSquare, Paint()..color = const Color(0xFF1B1238));

    // 4 Colored Triangles in Center
    for (int i = 0; i < 4; i++) {
      final player = playerByArm[i];
      final armColor = player?.color ?? kPlayerColors[i % kPlayerColors.length];

      final angle1 = geometry.armAngle(i) - math.pi / 4;
      final angle2 = geometry.armAngle(i) + math.pi / 4;

      final pt1 = Offset(center.dx + centerR * math.cos(angle1), center.dy + centerR * math.sin(angle1));
      final pt2 = Offset(center.dx + centerR * math.cos(angle2), center.dy + centerR * math.sin(angle2));

      final triPath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pt1.dx, pt1.dy)
        ..lineTo(pt2.dx, pt2.dy)
        ..close();

      canvas.drawPath(triPath, Paint()..color = armColor.withOpacity(0.85));
      canvas.drawPath(
        triPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // "Home" Text Badge inside Center Triangle
      final finishPos = geometry.finishCellPos(i);
      final homePillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: finishPos, width: cellS * 1.05, height: cellS * 0.55),
        const Radius.circular(5),
      );
      canvas.drawRRect(homePillRect, Paint()..color = Colors.white.withOpacity(0.9));
      canvas.drawRRect(
        homePillRect,
        Paint()
          ..color = armColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      TextPainter tpFinish = TextPainter(
        text: TextSpan(
          text: 'Home',
          style: TextStyle(
            color: armColor,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tpFinish.layout();
      tpFinish.paint(canvas, finishPos - Offset(tpFinish.width / 2, tpFinish.height / 2));
    }

    canvas.drawRect(
      centerSquare,
      Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant FourArmBoardPainter oldDelegate) =>
      oldDelegate.geometry.size != geometry.size || oldDelegate.players != players;
}

// ==================== DICE PIPS PAINTER ====================

class DicePipsPainter extends CustomPainter {
  final int value;
  final Color dotColor;

  DicePipsPainter(this.value, this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    final r = size.width * 0.085;
    final w = size.width;
    final h = size.height;

    final c = Offset(w / 2, h / 2);
    final tl = Offset(w * 0.28, h * 0.28);
    final tr = Offset(w * 0.72, h * 0.28);
    final bl = Offset(w * 0.28, h * 0.72);
    final br = Offset(w * 0.72, h * 0.72);
    final ml = Offset(w * 0.28, h * 0.5);
    final mr = Offset(w * 0.72, h * 0.5);

    List<Offset> dots = [];
    switch (value) {
      case 1:
        dots = [c];
        break;
      case 2:
        dots = [tl, br];
        break;
      case 3:
        dots = [tl, c, br];
        break;
      case 4:
        dots = [tl, tr, bl, br];
        break;
      case 5:
        dots = [tl, tr, c, bl, br];
        break;
      case 6:
        dots = [tl, tr, ml, mr, bl, br];
        break;
    }

    for (final dot in dots) {
      canvas.drawCircle(dot, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DicePipsPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.dotColor != dotColor;
}

// ==================== LUDO MANIA LOGO WIDGET ====================

class LudoManiaLogoWidget extends StatelessWidget {
  final double size;

  const LudoManiaLogoWidget({super.key, this.size = 100.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 18,
            spreadRadius: 2,
          )
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: LudoManiaLogoPainter(),
      ),
    );
  }
}

class LudoManiaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.46;

    // 1. Dark purple circular background
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1B1238));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035,
    );

    // Inner gold ring
    canvas.drawCircle(
      center,
      radius * 0.94,
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.015,
    );

    // 2. 6 Colorful Ludo Arms
    final colors = [
      const Color(0xFFE53935), // Red
      const Color(0xFFFB8C00), // Orange
      const Color(0xFFFDD835), // Yellow
      const Color(0xFF43A047), // Green
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF8E24AA), // Purple
    ];

    final armLen = size.width * 0.36;
    final armW = size.width * 0.11;

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 3);
      final cCol = colors[i];

      final dx = math.cos(angle);
      final dy = math.sin(angle);
      final nx = -dy;
      final ny = dx;

      final pEnd = Offset(center.dx + dx * armLen, center.dy + dy * armLen);
      final pStart = Offset(center.dx + dx * (size.width * 0.12), center.dy + dy * (size.width * 0.12));

      final w2 = armW / 2.0;
      final v1 = Offset(pStart.dx + nx * w2, pStart.dy + ny * w2);
      final v2 = Offset(pEnd.dx + nx * w2, pEnd.dy + ny * w2);
      final v3 = Offset(pEnd.dx - nx * w2, pEnd.dy - ny * w2);
      final v4 = Offset(pStart.dx - nx * w2, pStart.dy - ny * w2);

      final pathBorder = Path()..moveTo(v1.dx, v1.dy)..lineTo(v2.dx, v2.dy)..lineTo(v3.dx, v3.dy)..lineTo(v4.dx, v4.dy)..close();
      canvas.drawPath(pathBorder, Paint()..color = Colors.white);

      final borderW = size.width * 0.01;
      final v1i = Offset(pStart.dx + nx * (w2 - borderW), pStart.dy + ny * (w2 - borderW));
      final v2i = Offset(pEnd.dx + nx * (w2 - borderW), pEnd.dy + ny * (w2 - borderW));
      final v3i = Offset(pEnd.dx - nx * (w2 - borderW), pEnd.dy - ny * (w2 - borderW));
      final v4i = Offset(pStart.dx - nx * (w2 - borderW), pStart.dy - ny * (w2 - borderW));

      final pathFill = Path()..moveTo(v1i.dx, v1i.dy)..lineTo(v2i.dx, v2i.dy)..lineTo(v3i.dx, v3i.dy)..lineTo(v4i.dx, v4i.dy)..close();
      canvas.drawPath(pathFill, Paint()..color = cCol);

      // 3 white dots
      for (double d in [0.45, 0.65, 0.85]) {
        final dotPos = Offset(center.dx + dx * (armLen * d), center.dy + dy * (armLen * d));
        canvas.drawCircle(dotPos, size.width * 0.016, Paint()..color = Colors.white);
      }
    }

    // 3. Center Hexagon
    final hexR = size.width * 0.16;
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * (math.pi / 3);
      final pt = Offset(center.dx + hexR * math.cos(a), center.dy + hexR * math.sin(a));
      if (i == 0) {
        hexPath.moveTo(pt.dx, pt.dy);
      } else {
        hexPath.lineTo(pt.dx, pt.dy);
      }
    }
    hexPath.close();
    canvas.drawPath(hexPath, Paint()..color = Colors.amber);

    final hexInnerPath = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * (math.pi / 3);
      final pt = Offset(center.dx + (hexR - size.width * 0.015) * math.cos(a), center.dy + (hexR - size.width * 0.015) * math.sin(a));
      if (i == 0) {
        hexInnerPath.moveTo(pt.dx, pt.dy);
      } else {
        hexInnerPath.lineTo(pt.dx, pt.dy);
      }
    }
    hexInnerPath.close();
    canvas.drawPath(hexInnerPath, Paint()..color = Colors.white);

    // 4. Avatar Face
    final faceR = size.width * 0.105;
    canvas.drawCircle(center, faceR, Paint()..color = const Color(0xFFFFE0B2));
    canvas.drawCircle(center, faceR, Paint()..color = const Color(0xFFE6A064)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.008);

    // Blush
    final blushR = size.width * 0.02;
    canvas.drawCircle(Offset(center.dx - faceR * 0.6, center.dy + faceR * 0.1), blushR, Paint()..color = const Color(0x99FF8A80));
    canvas.drawCircle(Offset(center.dx + faceR * 0.6, center.dy + faceR * 0.1), blushR, Paint()..color = const Color(0x99FF8A80));

    // Eyes
    final eyeR = size.width * 0.014;
    canvas.drawCircle(Offset(center.dx - faceR * 0.35, center.dy - faceR * 0.15), eyeR, Paint()..color = const Color(0xFF212121));
    canvas.drawCircle(Offset(center.dx + faceR * 0.35, center.dy - faceR * 0.15), eyeR, Paint()..color = const Color(0xFF212121));

    // Smile
    final smileRect = Rect.fromLTRB(center.dx - faceR * 0.4, center.dy - faceR * 0.1, center.dx + faceR * 0.4, center.dy + faceR * 0.45);
    canvas.drawArc(smileRect, 0.35, 2.4, false, Paint()..color = const Color(0xFF212121)..style = PaintingStyle.stroke..strokeWidth = size.width * 0.012);

    // 5. Crown
    final crownTop = center.dy - faceR * 0.8;
    final crownW = faceR * 1.3;
    final crownH = faceR * 0.7;

    final crownPath = Path()
      ..moveTo(center.dx - crownW / 2, crownTop)
      ..lineTo(center.dx - crownW / 2, crownTop - crownH)
      ..lineTo(center.dx - crownW / 4, crownTop - crownH * 0.5)
      ..lineTo(center.dx, crownTop - crownH * 1.1)
      ..lineTo(center.dx + crownW / 4, crownTop - crownH * 0.5)
      ..lineTo(center.dx + crownW / 2, crownTop - crownH)
      ..lineTo(center.dx + crownW / 2, crownTop)
      ..close();

    canvas.drawPath(crownPath, Paint()..color = const Color(0xFFFFC107));
    canvas.drawPath(crownPath, Paint()..color = const Color(0xFFE67800)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Jewels
    final jR = size.width * 0.012;
    canvas.drawCircle(Offset(center.dx - crownW / 2, crownTop - crownH), jR, Paint()..color = const Color(0xFFF44336));
    canvas.drawCircle(Offset(center.dx, crownTop - crownH * 1.1), jR, Paint()..color = const Color(0xFF2196F3));
    canvas.drawCircle(Offset(center.dx + crownW / 2, crownTop - crownH), jR, Paint()..color = const Color(0xFF4CAF50));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
