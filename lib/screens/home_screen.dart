import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'dart:convert';
import 'reminders_screen.dart';
import '../theme/app_theme.dart';
import '../models/dhikr.dart';
import '../data/dhikr_data.dart';
import '../widgets/ring_progress.dart';
import 'package:audioplayers/audioplayers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  late List<Dhikr> _dhikrList;
  int _selectedIndex = 0;
  int _count = 0;
  bool _hapticEnabled = true;
  bool _soundEnabled = true;
  bool _menuOpen = false;
  SharedPreferences? _prefs;
  List<Map<String, dynamic>> _history = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _tapController;
  late Animation<double> _tapScale;
  late AnimationController _completeController;
  late Animation<double> _completeFade;
  late AnimationController _menuController;
  late Animation<double> _menuAnimation;
  // ── Getters ────────────────────────────────────────────────────────────────
  Dhikr get _current => _dhikrList[_selectedIndex];

  Color get _currentColor =>
      AppColors.dhikrColors[_current.colorIndex % AppColors.dhikrColors.length];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _dhikrList = List.from(defaultDhikrList);

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    _completeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
    );
    _completeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _completeController, curve: Curves.easeOut),
    );

    _loadData();
  }

  @override
  void dispose() {
    _tapController.dispose();
    _completeController.dispose();
    _menuController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    setState(() {
      _count         = prefs.getInt('count_$_selectedIndex') ?? 0;
      _hapticEnabled = prefs.getBool('haptic') ?? true;
      _soundEnabled  = prefs.getBool('sound') ?? true;
      final raw = prefs.getString('history');
      if (raw != null) {
        _history = List<Map<String, dynamic>>.from(jsonDecode(raw));
      }
      final customRaw = prefs.getString('custom_dhikr');
      if (customRaw != null) {
        final List decoded = jsonDecode(customRaw);
        final custom = decoded.map((e) => Dhikr.fromJson(e)).toList();
        _dhikrList = [...defaultDhikrList, ...custom];
      }
    });
  }

  Future<void> _saveCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('count_$_selectedIndex', _count);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', jsonEncode(_history));
  }

  Future<void> _saveCustomDhikr() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = _dhikrList.where((d) => d.isCustom).toList();
    await prefs.setString(
        'custom_dhikr', jsonEncode(custom.map((d) => d.toJson()).toList()));
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _onTap() async {
    _tapController.forward().then((_) => _tapController.reverse());

    if (_hapticEnabled) {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) Vibration.vibrate(duration: 30, amplitude: 80);
    }

    if (_soundEnabled) {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/tap.mp3'));
    }

    setState(() => _count++);
    await _saveCount();

    if (_count % _current.target == 0) {
      _onTargetReached();
    }
  }

  void _onTargetReached() async {
    if (_hapticEnabled) {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 80, 60, 80, 60, 120]);
      }
    }

    _completeController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _completeController.reset();
      });
    });

    _history.add({
      'dhikr': _current.transliteration,
      'arabic': _current.arabic,
      'count': _current.target,
      'color': _current.colorIndex,
      'time': DateTime.now().toIso8601String(),
    });

    if (_history.length > 10) {
      _history = _history.sublist(_history.length - 10);
    }

    await _saveHistory();
  }

  void _onReset() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('Reset Counter?',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            content: Text('This will reset the count to 0.',
                style: TextStyle(color: AppColors.textSecond)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'Cancel', style: TextStyle(color: AppColors.textSecond)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _count = 0);
                  _completeController.reset();
                  await _saveCount();
                },
                child: const Text(
                    'Reset', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
    );
  }

  void _selectDhikr(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedIndex = index;
      _count = prefs.getInt('count_$index') ?? 0;
    });
    _completeController.reset();
  }

  // ── Add custom dhikr ───────────────────────────────────────────────────────
  void _showAddDhikrSheet() {
    final arabicController = TextEditingController();
    final translitController = TextEditingController();
    final translationController = TextEditingController();
    final targetController = TextEditingController(text: '33');
    int selectedColorIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) =>
          StatefulBuilder(
            builder: (ctx, setModalState) =>
                Padding(
                  padding: EdgeInsets.only(
                    left: 24, right: 24, top: 24,
                    bottom: MediaQuery
                        .of(ctx)
                        .viewInsets
                        .bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textHint,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Add Custom Dhikr',
                          style: TextStyle(color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 20),
                      _buildInput(arabicController, 'Arabic / Text',
                          textAlign: TextAlign.right),
                      const SizedBox(height: 12),
                      _buildInput(translitController, 'Transliteration'),
                      const SizedBox(height: 12),
                      _buildInput(
                          translationController, 'Translation (optional)'),
                      const SizedBox(height: 12),
                      _buildInput(targetController, 'Target Count',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      Text('Color', style: TextStyle(
                          color: AppColors.textSecond,
                          fontSize: 12,
                          letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(
                            AppColors.dhikrColors.length, (i) {
                          final selected = selectedColorIndex == i;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => selectedColorIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              width: selected ? 36 : 30,
                              height: selected ? 36 : 30,
                              decoration: BoxDecoration(
                                color: AppColors.dhikrColors[i],
                                shape: BoxShape.circle,
                                border: selected ? Border.all(
                                    color: Colors.white, width: 2.5) : null,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            if (arabicController.text
                                .trim()
                                .isEmpty &&
                                translitController.text
                                    .trim()
                                    .isEmpty) return;
                            final newDhikr = Dhikr(
                              id: DateTime
                                  .now()
                                  .millisecondsSinceEpoch,
                              arabic: arabicController.text.trim(),
                              transliteration: translitController.text.trim(),
                              translation: translationController.text.trim(),
                              target: int.tryParse(targetController.text) ?? 33,
                              colorIndex: selectedColorIndex,
                              isCustom: true,
                            );
                            Navigator.pop(ctx);
                            setState(() {
                              _dhikrList = List.from(_dhikrList)
                                ..add(newDhikr);
                            });
                            await _saveCustomDhikr();
                          },
                          child: const Text('Save Dhikr',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {
    TextAlign textAlign = TextAlign.left,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── History sheet ──────────────────────────────────────────────────────────
  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Session History',
                    style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No sessions yet. Start counting!',
                          style: TextStyle(color: AppColors.textSecond)),
                    ),
                  )
                else
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = _history[_history.length - 1 - i];
                        final color = AppColors
                            .dhikrColors[(s['color'] as int) %
                            AppColors.dhikrColors.length];
                        final time = DateTime.tryParse(s['time'] ?? '');
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border(left: BorderSide(
                                color: color, width: 3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['arabic'] ?? '',
                                      style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 18),
                                      textDirection: TextDirection.rtl,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(s['dhikr'] ?? '',
                                        style: TextStyle(
                                            color: AppColors.textSecond,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${s['count']}×',
                                      style: TextStyle(color: color,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  if (time != null)
                                    Text(
                                      '${time.hour.toString().padLeft(
                                          2, '0')}:${time.minute
                                          .toString()
                                          .padLeft(2, '0')}',
                                      style: TextStyle(
                                          color: AppColors.textHint,
                                          fontSize: 11),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  // ── Chip long press options ────────────────────────────────────────────────
  void _showChipOptions(int index) {
    final dhikr = _dhikrList[index];
    final color = AppColors.dhikrColors[dhikr.colorIndex %
        AppColors.dhikrColors.length];

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dhikr.arabic.isNotEmpty ? dhikr.arabic : dhikr
                            .transliteration,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 22),
                      ),
                      if (dhikr.transliteration.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(dhikr.transliteration,
                            style: TextStyle(
                                color: AppColors.textSecond, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (dhikr.isCustom)
                  _optionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Dhikr',
                    color: Colors.redAccent,
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) =>
                            AlertDialog(
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: Text('Delete Dhikr?',
                                  style: TextStyle(color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              content: Text(
                                  'This will permanently remove this dhikr.',
                                  style: TextStyle(
                                      color: AppColors.textSecond)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Cancel', style: TextStyle(
                                      color: AppColors.textSecond)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(
                                      color: Colors.redAccent)),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true) {
                        setState(() {
                          if (_selectedIndex == index) {
                            _selectedIndex = 0;
                            _count = 0;
                          } else if (_selectedIndex > index) {
                            _selectedIndex--;
                          }
                          _dhikrList = List.from(_dhikrList)
                            ..removeAt(index);
                        });
                        await _saveCustomDhikr();
                      }
                    },
                  ),

                if (!dhikr.isCustom)
                  _optionTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Default dhikr cannot be deleted',
                    color: AppColors.textHint,
                    onTap: () => Navigator.pop(context),
                  ),

                const SizedBox(height: 8),

                _optionTile(
                  icon: Icons.refresh_rounded,
                  label: 'Reset count for this Dhikr',
                  color: AppColors.textSecond,
                  onTap: () async {
                    Navigator.pop(context);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('count_$index', 0);
                    if (_selectedIndex == index) {
                      setState(() => _count = 0);
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // ── Hamburger button ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _menuOpen = !_menuOpen);
                  if (_menuOpen) {
                    _menuController.forward();
                  } else {
                    _menuController.reverse();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48, height: 36,
                  decoration: BoxDecoration(
                    color: _menuOpen
                        ? AppColors.gold.withOpacity(0.15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _menuOpen
                          ? AppColors.gold.withOpacity(0.5)
                          : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      width: 18,
                      height: 2,
                      decoration: BoxDecoration(
                        color: _menuOpen ? AppColors.gold : AppColors.textSecond,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )),
                  ),
                ),
              ),
            ],
          ),

          // ── Floating island ──────────────────────────────
          ScaleTransition(
            scale: _menuAnimation,
            child: FadeTransition(
              opacity: _menuAnimation,
              child: _menuOpen
                  ? Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.gold.withOpacity(0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // History
                    _islandOption(
                      icon: Icons.history_rounded,
                      label: 'History',
                      color: AppColors.textSecond,
                      onTap: () {
                        setState(() => _menuOpen = false);
                        _menuController.reverse();
                        _showHistory();
                      },
                    ),

                    _islandDivider(),

                    // Reminders
                    _islandOption(
                      icon: Icons.notifications_rounded,
                      label: 'Reminders',
                      color: AppColors.textSecond,
                      onTap: () {
                        setState(() => _menuOpen = false);
                        _menuController.reverse();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RemindersScreen(),
                          ),
                        );
                      },
                    ),

                    _islandDivider(),

                    // Sound
                    _islandOption(
                      icon: _soundEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      label: 'Sound',
                      color: _soundEnabled
                          ? const Color(0xFF4ade80)
                          : AppColors.textHint,
                      //dot: true,
                      //dotOn: _soundEnabled,
                      onTap: () {
                        setState(() => _soundEnabled = !_soundEnabled);
                        _prefs?.setBool('sound', _soundEnabled);
                      },
                    ),

                    _islandDivider(),

                    // Haptics
                    _islandOption(
                      icon: Icons.vibration_rounded,
                      label: 'Haptics',
                      color: _hapticEnabled
                          ? const Color(0xFF4ade80)
                          : AppColors.textHint,
                      //dot: true,
                      //dotOn: _hapticEnabled,
                      onTap: () {
                        setState(() => _hapticEnabled = !_hapticEnabled);
                        _prefs?.setBool('haptic', _hapticEnabled);
                      },
                    ),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _islandOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool dot = false,
    bool dotOn = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (dot)
                  Positioned(
                    top: -2, right: -4,
                    child: Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotOn
                            ? const Color(0xFF4ade80)
                            : AppColors.textHint,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _islandDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withOpacity(0.05),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Icon(icon, color: AppColors.textSecond, size: 20),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Arabic text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _current.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: Theme
                .of(context)
                .textTheme
                .displayLarge
                ?.copyWith(
              color: AppColors.textPrimary,
              fontFamily: 'serif',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(_current.transliteration,
            style: Theme
                .of(context)
                .textTheme
                .titleLarge),
        const SizedBox(height: 4),
        Text(_current.translation,
            style: Theme
                .of(context)
                .textTheme
                .bodyMedium),
        const SizedBox(height: 40),

        // Ring + tap button
        GestureDetector(
          onTap: _onTap,
          child: ScaleTransition(
            scale: _tapScale,
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RingProgress(
                    count: _count,
                    target: _current.target,
                    color: _currentColor,
                  ),

                  // Completion flash
                  FadeTransition(
                    opacity: _completeFade,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentColor.withOpacity(0.15),
                      ),
                      child: Icon(Icons.check_rounded,
                          color: _currentColor, size: 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Reset button
        GestureDetector(
          onTap: _onReset,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text('Reset',
              style: TextStyle(
                color: AppColors.textSecond,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dhikrList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final selected = i == _selectedIndex;
                      final color = AppColors.dhikrColors[_dhikrList[i]
                          .colorIndex % AppColors.dhikrColors.length];
                      return GestureDetector(
                        onTap: () => _selectDhikr(i),
                        onLongPress: () => _showChipOptions(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.15)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected ? color.withOpacity(0.6) : Colors
                                  .transparent,
                            ),
                          ),
                          child: Text(
                            _dhikrList[i].transliteration.isNotEmpty
                                ? _dhikrList[i].transliteration
                                : _dhikrList[i].arabic,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? color : AppColors.textSecond,
                              fontSize: 12,
                              height: 2.0,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showAddDhikrSheet,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: Icon(
                      Icons.add_rounded, color: AppColors.gold, size: 22),
                ),
              ),
            ],
          ),

          // Credit line
          const SizedBox(height: 6),
          Text(
            'built by Abdur Rahman',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 10,
              letterSpacing: 1.2,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}